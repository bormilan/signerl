-module(signerl_xmlan_equivalence_SUITE).

-include_lib("stdlib/include/assert.hrl").
-compile([export_all, nowarn_export_all]).

suite() -> [{timetrap, {seconds, 60}}].

all() ->
    [
        baseline_contract_ownership,
        xml_bytes,
        rsa_same_key,
        ecdsa_cross_verification,
        independent_signatures,
        public_errors,
        public_file_entities,
        public_http_entities
    ].

init_per_suite(Config) ->
    Baseline = filename:join(code:priv_dir(signerl), "xml-baseline"),
    {ok, [Manifest]} = file:consult(fixture("baseline_sources.term")),
    lists:foreach(
        fun({Path, Hash}) ->
            {ok, Bytes} = file:read_file(filename:join(Baseline, Path)),
            ?assertEqual(Hash, binary:encode_hex(crypto:hash(sha256, Bytes)))
        end,
        Manifest
    ),
    Ebin = filename:join(proplists:get_value(priv_dir, Config), "baseline-ebin"),
    ok = filelib:ensure_dir(filename:join(Ebin, "placeholder")),
    lists:foreach(
        fun(Path) ->
            {ok, _} = compile:file(Path, [
                report_errors,
                report_warnings,
                {i, filename:join(Baseline, "include")},
                {outdir, Ebin}
            ])
        end,
        [
            filename:join(Baseline, Path)
         || {Path, _} <- Manifest,
            filename:dirname(Path) =:= "src",
            filename:extension(Path) =:= ".erl"
        ]
    ),
    Peer = start_peer([Ebin]),
    try
        ?assertEqual(
            filename:join(Ebin, "signerl_xml.beam"),
            peer:call(Peer, code, which, [signerl_xml])
        ),
        ?assertEqual(non_existing, peer:call(Peer, code, which, [xmlan])),
        [{baseline, Peer} | Config]
    catch
        Class:Reason:Stack ->
            peer:stop(Peer),
            erlang:raise(Class, Reason, Stack)
    end.

end_per_suite(Config) ->
    case proplists:get_value(baseline, Config) of
        undefined -> ok;
        Peer -> peer:stop(Peer)
    end.

start_peer(Paths) ->
    {ok, Peer, _} = peer:start(#{
        connection => standard_io,
        args => [
            "+S",
            "2:2",
            "-enable-feature",
            "maybe_expr",
            "-pa",
            filename:dirname(code:which(?MODULE))
            | Paths
        ]
    }),
    Peer.

baseline(Config, Function, Args) ->
    try
        peer:call(proplists:get_value(baseline, Config), ?MODULE, Function, Args, 30000)
    catch
        Class:_ -> error({baseline_call_failed, Function, Class})
    end.

fixture(Name) -> signerl_utils:file_path("test/examples/xmlan_migration/" ++ Name).

signing_time() -> <<"2026-10-13T12:34:56Z">>.

corpus() ->
    [
        read(fixture("input.xml")),
        read(signerl_utils:file_path("test/examples/base/books.xml")),
        read(signerl_utils:file_path("test/examples/c14n/utf8.xml")),
        read(signerl_utils:file_path("test/examples/c14n/preserved_content.xml")),
        <<
            "<?xml version='1.0'?><r xmlns='urn:root' xmlns:p='urn:one' "
            "xmlns:unused='urn:unused' xmlns:ds='urn:application' xmlns:xades='urn:other'>"
            "<p:a xml:lang='hu'><n xmlns=''><p:b xmlns:p='urn:two' p:z='v'/></n></p:a>"
            "<ds:Signature>application data</ds:Signature></r><!--legal suffix-->\n"
        >>
    ].

read(Path) ->
    {ok, Bytes} = file:read_file(Path),
    Bytes.

xml_bytes(Config) ->
    Path = filename:join(proplists:get_value(priv_dir, Config), "comparison.xml"),
    lists:foreach(
        fun(Raw) ->
            Before = baseline(Config, xml_observation, [signerl_xml, signerl_c14n, Raw]),
            ?assertEqual(Before, xml_observation(xmlan, xmlan_c14n, Raw)),
            ok = file:write_file(Path, Raw),
            ?assertEqual(baseline(Config, parse_file, [signerl_xml, Path]), xmlan:parse_file(Path))
        end,
        corpus()
    ).

parse_file(Xml, Path) -> erlang:apply(Xml, parse_file, [Path]).

xml_observation(Xml, C14n, Raw) ->
    Tree = parse(Xml, Raw),
    {ok, Prolog} = erlang:apply(Xml, parse_prolog, [Raw]),
    #{
        parsed => Tree,
        prolog => Prolog,
        export => erlang:apply(Xml, export, [Prolog, Tree]),
        fragment => erlang:apply(Xml, export_fragment, [Tree]),
        projection => erlang:apply(Xml, expanded_names, [Tree]),
        c14n11 => erlang:apply(C14n, canonicalize, [Tree, c14n11]),
        exclusive => erlang:apply(C14n, canonicalize, [Tree, exc_c14n])
    }.

rsa_same_key(Config) ->
    #{key := Key, cert := Cert} = public_key:pkix_test_root_cert(
        "XML migration RSA",
        [{key, public_key:generate_key({rsa, 2048, 65537})}]
    ),
    Public = signerl_cert_helpers:rsa_public_key(Cert),
    Path = filename:join(proplists:get_value(priv_dir, Config), "same-key.xml"),
    lists:foreach(
        fun(Raw) ->
            ok = file:write_file(Path, Raw),
            lists:foreach(
                fun(Certificate) ->
                    {Before, After} = signed_pair(Config, Raw, Key, Certificate),
                    ?assertEqual(Before, After),
                    ?assertEqual({Before, After}, signed_pair(Config, Path, Key, Certificate)),
                    assert_cross_verification(Config, Before, After, Public)
                end,
                [undefined, Cert]
            )
        end,
        corpus()
    ).

parse(Xml, Raw) ->
    {ok, Tree} = erlang:apply(Xml, parse_binary, [Raw]),
    Tree.

signed_pair(Config, Raw, Key, Cert) ->
    {baseline(Config, sign, [Raw, Key, Cert]), sign(Raw, Key, Cert)}.

sign(Raw, Key, Cert) -> signerl:sign(Raw, sha256, Key, Cert, signing_time()).
verify(Signed, Public) -> signerl:verify(Signed, sha256, Public).

signature_observation(Xml, C14n, Signed) ->
    Tree = parse(Xml, Signed),
    {ok, Data} = signerl_verify:extract_signature_data(Tree),
    {ok, Properties} = signerl_xades_xml:find_signed_properties_element(
        maps:get(signature_element, Data)
    ),
    #{
        references => maps:get(references, Data),
        document => erlang:apply(C14n, canonicalize, [maps:get(unsigned_message, Data)]),
        properties => erlang:apply(C14n, canonicalize, [Properties]),
        signed_info => erlang:apply(
            C14n,
            canonicalize,
            [maps:get(signed_info_element, Data), signerl_verify:c14n_mode(Data)]
        )
    }.

ecdsa_cross_verification(Config) ->
    #{key := Key, cert := Cert} = public_key:pkix_test_root_cert(
        "XML migration ECDSA",
        [{key, public_key:generate_key({namedCurve, secp256r1})}]
    ),
    Public = signerl_cert_helpers:ecdsa_public_key(Cert),
    lists:foreach(
        fun(Raw) ->
            {Before, After} = signed_pair(Config, Raw, Key, Cert),
            assert_cross_verification(Config, Before, After, Public)
        end,
        corpus()
    ).

independent_signatures(Config) ->
    Dir = signerl_utils:file_path("test/examples/independent"),
    {ok, Public} = signerl_utils:load_key_from_file(filename:join(Dir, "rsa-public.pem")),
    lists:foreach(
        fun(Name) ->
            Signed = read(filename:join(Dir, Name)),
            assert_cross_verification(Config, Signed, Signed, Public)
        end,
        ["c14n11.xml", "exclusive.xml"]
    ).

assert_cross_verification(Config, Before, After, Public) ->
    ?assert(is_binary(Before)),
    ?assert(is_binary(After)),
    ?assertEqual(true, verify(Before, Public)),
    ?assertEqual(true, baseline(Config, verify, [After, Public])),
    ?assertEqual(
        baseline(Config, signature_observation, [signerl_xml, signerl_c14n, Before]),
        signature_observation(xmlan, xmlan_c14n, After)
    ),
    {ok, Parsed} = xmlan:parse_binary(After),
    ?assertEqual(true, verify(xmlan:export([], Parsed), Public)).

public_errors(Config) ->
    Key = public_key:generate_key({rsa, 2048, 65537}),
    Public = signerl_cert_helpers:rsa_public_key_from_cert(
        signerl_cert_helpers:signer_rsa_cert_path()
    ),
    Priv = proplists:get_value(priv_dir, Config),
    lists:foreach(
        fun(Raw) ->
            Before = baseline(Config, errors, [Raw, Key, Public, Priv]),
            ?assertEqual(Before, errors(Raw, Key, Public, Priv))
        end,
        [
            <<"<root/>">>,
            <<"<?xml versio='1.0'?><root/>">>,
            <<"<?xml version='1.0'?><root/><extra/>">>,
            <<"<?xml version='1.0'?><root/>garbage">>,
            <<"<?xml version='1.0'?><root><?pi value?></root>">>,
            <<"<?xml version='1.0'?><root/><?pi value?>">>,
            <<"<?xml version='1.0' encoding='ISO-8859-1'?><root/>">>,
            <<"<?xml version='1.0'?><root>", 255, "</root>">>,
            <<"<?xml version='1.0'?><p:root/>">>,
            <<"<?xml version='1.0'?><root xmlns='relative'/>">>,
            <<"<?xml version='1.0'?><!DOCTYPE root [<!ENTITY x 'value'>]><root>&x;</root>">>
        ]
    ),
    Raw = hd(corpus()),
    Signed = sign(Raw, Key, undefined),
    lists:foreach(
        fun({Before, After, Expected}) ->
            Changed = test_helpers:replace_once(Signed, Before, After),
            ?assertEqual(Expected, verify(Changed, Public)),
            ?assertEqual(Expected, baseline(Config, verify, [Changed, Public]))
        end,
        [
            {<<"2026-10-13T12:34:56Z">>, <<"2026-02-30T12:34:56Z">>, {error, invalid_signing_time}},
            {<<"<ds:Signature xmlns:ds=\"http://www.w3.org/2000/09/xmldsig#\"">>,
                <<"<ds:Signature xmlns:ds=\"urn:lookalike\"">>, {error, missing_signature}}
        ]
    ).

errors(Raw, Key, Public, Priv) ->
    Missing = filename:join(Priv, "missing.xml"),
    Invalid = filename:join(Priv, "invalid.xml"),
    ok = file:write_file(Invalid, Raw),
    [
        sign(Raw, Key, undefined),
        verify(Raw, Public),
        signerl_xml:parse_binary(Raw),
        signerl_xml:parse_prolog(Raw),
        caught(fun() -> signerl_xml:parse_file(Invalid) end),
        sign(Invalid, Key, undefined),
        verify(Invalid, Public),
        caught(fun() -> signerl_xml:parse_file(Missing) end),
        sign(Missing, Key, undefined),
        verify(Missing, Public),
        signerl:sign(Raw, sha256, Key, undefined, <<"2026-02-30T00:00:00Z">>)
    ].

caught(Fun) ->
    try
        Fun()
    catch
        Class:Reason -> {Class, Reason}
    end.

public_file_entities(Config) ->
    Priv = proplists:get_value(priv_dir, Config),
    Canary = filename:join(Priv, "entity-canary.txt"),
    ok = file:write_file(Canary, <<"private canary">>),
    ?assertEqual(<<"private canary">>, read(Canary)),
    Uri = unicode:characters_to_binary("file://" ++ filename:absname(Canary)),
    Key = public_key:generate_key({rsa, 2048, 65537}),
    Inputs = entity_inputs(Uri),
    Relative =
        <<
            "<?xml version='1.0'?><!DOCTYPE root [<!ENTITY value SYSTEM 'entity-canary.txt'>]>"
            "<root>&value;</root>"
        >>,
    Reads = trace_file_reads(fun() ->
        ?assertEqual(<<"private canary">>, read(Canary)),
        {ok, File} = file:open(Canary, [read, binary]),
        try
            ?assertEqual({ok, <<"private canary">>}, file:read(File, 100))
        after
            file:close(File)
        end,
        lists:foreach(fun(Raw) -> assert_public_rejection(Raw, Key, Priv) end, [Relative | Inputs])
    end),
    % Prove both read detectors work; neither binary nor file APIs may fetch the canary.
    ?assertEqual(
        [{open, Canary}, {read_file, Canary}],
        lists:sort([
            {Function, Path}
         || {Function, Path} <- Reads,
            unicode:characters_to_binary(filename:basename(Path)) =:= <<"entity-canary.txt">>
        ])
    ).

public_http_entities(Config) ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {ip, {127, 0, 0, 1}}]),
    {ok, {_, Port}} = inet:sockname(Listen),
    Owner = self(),
    Ref = make_ref(),
    spawn_link(fun() -> http_canary(Listen, Owner, Ref) end),
    try
        {ok, Control} = gen_tcp:connect({127, 0, 0, 1}, Port, [binary, {active, false}], 5000),
        ok = gen_tcp:send(Control, "GET /control HTTP/1.0\r\n\r\n"),
        {ok, _} = gen_tcp:recv(Control, 0, 5000),
        gen_tcp:close(Control),
        receive
            {Ref, request} -> ok
        after 5000 -> ct:fail(canary_control_failed)
        end,
        Uri = iolist_to_binary(["http://127.0.0.1:", integer_to_list(Port), "/entity"]),
        Key = public_key:generate_key({rsa, 2048, 65537}),
        lists:foreach(
            fun(Raw) ->
                assert_public_rejection(
                    Raw,
                    Key,
                    proplists:get_value(priv_dir, Config)
                )
            end,
            entity_inputs(Uri)
        ),
        receive
            {Ref, request} -> ct:fail(unexpected_http_request)
        after 100 -> ok
        end
    after
        gen_tcp:close(Listen)
    end.

entity_inputs(Uri) ->
    [
        <<"<?xml version='1.0'?><!DOCTYPE root SYSTEM '", Uri/binary, "'><root/>">>,
        <<"<?xml version='1.0'?><!DOCTYPE root PUBLIC 'canary' '", Uri/binary, "'><root/>">>,
        <<"<?xml version='1.0'?><!DOCTYPE root [<!ENTITY value SYSTEM '", Uri/binary,
            "'>]><root>&value;</root>">>,
        <<"<?xml version='1.0'?><!DOCTYPE root [<!ENTITY % value SYSTEM '", Uri/binary,
            "'>%value;]><root/>">>
    ].

assert_public_rejection(Raw, Key, Priv) ->
    Path = filename:join(Priv, "external-entity.xml"),
    ok = file:write_file(Path, Raw),
    lists:foreach(
        fun(Input) ->
            ?assertEqual({error, invalid_xml}, sign(Input, Key, undefined)),
            ?assertEqual({error, invalid_xml}, verify(Input, undefined))
        end,
        [Raw, Path]
    ).

http_canary(Listen, Owner, Ref) ->
    case gen_tcp:accept(Listen) of
        {ok, Socket} ->
            {ok, _} = gen_tcp:recv(Socket, 0, 5000),
            Owner ! {Ref, request},
            ok = gen_tcp:send(
                Socket, "HTTP/1.0 200 OK\r\nContent-Length: 6\r\nConnection: close\r\n\r\ncanary"
            ),
            gen_tcp:close(Socket),
            http_canary(Listen, Owner, Ref);
        {error, closed} ->
            ok
    end.

baseline_contract_ownership(_Config) ->
    Baseline = filename:join(code:priv_dir(signerl), "xml-baseline"),
    {ok, [Map]} = file:consult(fixture("ownership.term")),
    Paths =
        filelib:wildcard(filename:join([Baseline, "test", "*_test.erl"])) ++
            filelib:wildcard(filename:join([Baseline, "test", "*_SUITE.erl"])),
    Before = lists:sort(
        lists:append([
            [{list_to_atom(filename:basename(Path, ".erl")), F} || F <- contracts(Path)]
         || Path <- Paths
        ])
    ),
    ?assertEqual(Before, lists:sort([{M, F} || {M, F, _} <- Map])),
    ?assertEqual(length(Before), length(lists:usort(Before))),
    lists:foreach(
        fun({_, _, Owners}) ->
            ?assertNotEqual([], Owners),
            lists:foreach(
                fun({Owner, Module, Function}) ->
                    Path = filename:join([
                        code:lib_dir(Owner), "test", atom_to_list(Module) ++ ".erl"
                    ]),
                    ?assert(lists:member(Function, contracts(Path)))
                end,
                Owners
            )
        end,
        Map
    ),
    ct:log("All ~p baseline test functions/generators/cases have executable owners", [length(Map)]).

contracts(Path) ->
    Include = filename:join(filename:dirname(filename:dirname(Path)), "include"),
    {ok, Forms} = epp:parse_file(Path, [Include], []),
    ?assertEqual([], [E || {error, E} <- Forms]),
    case lists:suffix("_SUITE.erl", Path) of
        true ->
            All = literal_function(all, Forms),
            Groups = [G || {function, _, groups, 0, _} = G <- Forms],
            GroupValues =
                case Groups of
                    [] -> [];
                    _ -> literal_function(groups, Forms)
                end,
            lists:append([
                case Entry of
                    {group, Name} ->
                        {Name, _, Cases} = lists:keyfind(Name, 1, GroupValues),
                        Cases;
                    Name ->
                        [Name]
                end
             || Entry <- All
            ]);
        false ->
            [
                Name
             || {function, _, Name, 0, _} <- Forms,
                lists:suffix("_test", atom_to_list(Name)) orelse
                    lists:suffix("_test_", atom_to_list(Name))
            ]
    end.

literal_function(Name, Forms) ->
    [{function, _, Name, 0, [{clause, _, [], [], [Value]}]}] =
        [F || {function, _, N, 0, _} = F <- Forms, N =:= Name],
    erl_parse:normalise(Value).

trace_file_reads(Fun) ->
    Tracer = spawn_link(fun() -> collect_reads([]) end),
    erlang:trace_pattern({file, read_file, 1}, true, [local]),
    erlang:trace_pattern({file, open, 2}, true, [local]),
    erlang:trace(self(), true, [call, {tracer, Tracer}]),
    try
        Fun(),
        Ref = erlang:trace_delivered(self()),
        receive
            {trace_delivered, _, Ref} -> ok
        after 5000 -> ct:fail(trace_timeout)
        end,
        Tracer ! {result, self()},
        receive
            {reads, Paths} -> Paths
        after 5000 -> ct:fail(tracer_timeout)
        end
    after
        erlang:trace(self(), false, [call]),
        erlang:trace_pattern({file, read_file, 1}, false, [local]),
        erlang:trace_pattern({file, open, 2}, false, [local]),
        Tracer ! stop
    end.

collect_reads(Paths) ->
    receive
        {trace, _, call, {file, Function, [Path | _]}} ->
            collect_reads([{Function, Path} | Paths]);
        {result, Owner} ->
            Owner ! {reads, lists:reverse(Paths)},
            collect_reads(Paths);
        stop ->
            ok
    after 60000 -> error(tracer_idle_timeout)
    end.
