-module(signerl_xml_SUITE).

-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").
-compile([export_all, nowarn_export_all]).

suite() ->
    [{timetrap, {seconds, 30}}].

all() ->
    [
        to_file_writes_and_reads_back,
        utf8_file_roundtrip,
        reject_non_utf8_file,
        missing_file_raises,
        file_and_binary_preserve_content,
        file_rejects_processing_instruction,
        external_file_entities_are_rejected,
        external_http_entities_are_rejected,
        fresh_xml_names_do_not_grow_atoms
    ].

to_file_writes_and_reads_back(Config) ->
    PrivDir = ?config(priv_dir, Config),
    OutPath = filename:join(PrivDir, "to_file_test.xml"),
    Prolog = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"],
    Root = signerl_xml:parse_file(signerl_utils:file_path("test/examples/base/books.xml")),
    ?assertMatch({<<"library">>, [{<<"id">>, "112233"}], ["\n    ", {<<"book">>, _, _} | _]}, Root),
    Binary = signerl_xml:export(Prolog, Root),
    ok = signerl_xml:to_file(OutPath, Binary),
    ReadBack = signerl_xml:parse_file(OutPath),
    ?assertEqual(Root, ReadBack).

utf8_file_roundtrip(Config) ->
    Root = {<<"root">>, [{<<"value">>, "café ő 東京 😀"}], ["café ő 東京 😀"]},
    Binary = signerl_xml:export(["<?xml version='1.0' encoding='UTF-8'?>"], Root),
    Path = filename:join(?config(priv_dir, Config), "utf8.xml"),
    ok = signerl_xml:to_file(Path, Binary),
    ?assertEqual(Root, signerl_xml:parse_file(Path)).

reject_non_utf8_file(Config) ->
    Path = filename:join(?config(priv_dir, Config), "latin1.xml"),
    ok = file:write_file(Path, <<"<?xml version='1.0' encoding='ISO-8859-1'?><root/>">>),
    ?assertException(error, _, signerl_xml:parse_file(Path)).

missing_file_raises(Config) ->
    Path = filename:join(?config(priv_dir, Config), "missing.xml"),
    ?assertException(error, _, signerl_xml:parse_file(Path)).

file_and_binary_preserve_content(_Config) ->
    Path = signerl_utils:file_path("test/examples/c14n/preserved_content.xml"),
    {ok, Raw} = file:read_file(Path),
    {ok, Xml} = signerl_xml:parse_binary(Raw),
    ?assertEqual(Xml, signerl_xml:parse_file(Path)).

file_rejects_processing_instruction(Config) ->
    Path = filename:join(?config(priv_dir, Config), "instruction.xml"),
    ok = file:write_file(Path, <<"<root><?report preserved?></root>">>),
    ?assertException(error, _, signerl_xml:parse_file(Path)).

external_file_entities_are_rejected(Config) ->
    Dir = ?config(priv_dir, Config),
    CanaryPath = filename:join(Dir, "entity-canary.txt"),
    XmlPath = filename:join(Dir, "external-entity.xml"),
    ok = file:write_file(CanaryPath, <<"private canary">>),
    Uri = unicode:characters_to_binary("file://" ++ filename:absname(CanaryPath)),
    Xml = <<"<!DOCTYPE root [<!ENTITY value SYSTEM '", Uri/binary, "'>]><root>&value;</root>">>,
    ?assertEqual({error, invalid_xml}, signerl_xml:parse_binary(Xml)),
    % Relative paths must also be rejected by the file entry point.
    ok = file:write_file(
        XmlPath,
        <<"<!DOCTYPE root [<!ENTITY value SYSTEM 'entity-canary.txt'>]><root>&value;</root>">>
    ),
    ?assertException(error, _, signerl_xml:parse_file(XmlPath)).

external_http_entities_are_rejected(_Config) ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {ip, {127, 0, 0, 1}}]),
    {ok, {_, Port}} = inet:sockname(Listen),
    Owner = self(),
    Ref = make_ref(),
    _Server = spawn_link(fun() -> http_canary(Listen, Owner, Ref) end),
    try
        % Prove this endpoint is reachable and the request detector works.
        {ok, Control} = gen_tcp:connect({127, 0, 0, 1}, Port, [binary, {active, false}], 5000),
        ok = gen_tcp:send(Control, "GET /control HTTP/1.0\r\n\r\n"),
        {ok, _} = gen_tcp:recv(Control, 0, 5000),
        ok = gen_tcp:close(Control),
        receive
            {Ref, http_request} -> ok
        after 5000 -> ct:fail(canary_control_failed)
        end,
        Url = iolist_to_binary(["http://127.0.0.1:", integer_to_list(Port), "/entity"]),
        Results = [
            signerl_xml:parse_binary(Xml)
         || Xml <- [
                <<"<!DOCTYPE root SYSTEM '", Url/binary, "'><root/>">>,
                <<"<!DOCTYPE root PUBLIC 'canary' '", Url/binary, "'><root/>">>,
                <<"<!DOCTYPE root [<!ENTITY value SYSTEM '", Url/binary,
                    "'>]><root>&value;</root>">>,
                <<"<!DOCTYPE root [<!ENTITY % value SYSTEM '", Url/binary, "'>%value;]><root/>">>
            ]
        ],
        receive
            {Ref, http_request} -> ct:fail(unexpected_external_http_request)
        after 100 -> ok
        end,
        ?assertEqual(lists:duplicate(4, {error, invalid_xml}), Results)
    after
        gen_tcp:close(Listen)
    end.

http_canary(Listen, Owner, Ref) ->
    case gen_tcp:accept(Listen) of
        {ok, Socket} ->
            {ok, _} = gen_tcp:recv(Socket, 0, 5000),
            Owner ! {Ref, http_request},
            ok = gen_tcp:send(
                Socket, "HTTP/1.0 200 OK\r\nContent-Length: 6\r\nConnection: close\r\n\r\ncanary"
            ),
            ok = gen_tcp:close(Socket),
            http_canary(Listen, Owner, Ref);
        {error, closed} ->
            ok
    end.

fresh_xml_names_do_not_grow_atoms(_Config) ->
    Key = signerl_cert_helpers:signer_rsa_key(),
    PublicKey = signerl_cert_helpers:rsa_public_key_from_cert(
        signerl_cert_helpers:signer_rsa_cert_path()
    ),
    % A fresh VM keeps other tests/module loading out of the atom-count measurement.
    {ok, Peer, _} = peer:start_link(#{
        connection => standard_io,
        args => [
            "+S",
            "2:2",
            "-enable-feature",
            "maybe_expr",
            "-pa",
            code:lib_dir(signerl, ebin),
            filename:dirname(code:which(?MODULE))
        ]
    }),
    try
        Growth = peer:call(Peer, ?MODULE, atom_name_probe, [Key, PublicKey], 20000),
        ?assertEqual([0, 0], Growth)
    after
        peer:stop(Peer)
    end.

atom_name_probe(Key, PublicKey) ->
    atom_name_batch(lists:seq(1, 5), Key, PublicKey),
    Before = erlang:system_info(atom_count),
    atom_name_batch(lists:seq(10, 34), Key, PublicKey),
    erlang:garbage_collect(),
    AfterFirst = erlang:system_info(atom_count),
    atom_name_batch(lists:seq(35, 59), Key, PublicKey),
    erlang:garbage_collect(),
    AfterSecond = erlang:system_info(atom_count),
    [AfterFirst - Before, AfterSecond - AfterFirst].

atom_name_batch(Numbers, Key, PublicKey) ->
    lists:foreach(fun(N) -> probe_xml_name(N, Key, PublicKey) end, Numbers).

probe_xml_name(N, Key, PublicKey) ->
    Suffix = integer_to_binary(N),
    Name = <<"node_", Suffix/binary>>,
    Prefix = <<"p_", Suffix/binary>>,
    Attr = <<"attr_", Suffix/binary>>,
    Child = <<Prefix/binary, ":child_", Suffix/binary>>,
    Property = <<Prefix/binary, ":property_", Suffix/binary>>,
    Xml =
        <<"<?xml version='1.0'?><", Name/binary, " xmlns:", Prefix/binary, "='urn:probe' ",
            Attr/binary, "='v'><", Child/binary, " ", Property/binary, "='w'/></", Name/binary,
            ">">>,
    {ok, Parsed} = signerl_xml:parse_binary(Xml),
    {ok, Parsed} = signerl_xml:parse_binary(signerl_xml:export([], Parsed)),
    _ = signerl_c14n:canonicalize(Parsed, c14n11),
    _ = signerl_c14n:canonicalize(Parsed, exc_c14n),
    Signed = signerl:sign(Xml, sha256, Key),
    true = signerl:verify(Signed, sha256, PublicKey),
    {error, invalid_xml} = signerl_xml:parse_binary(
        <<"<broken_", Suffix/binary, "/>trailing garbage">>
    ),
    ok.
