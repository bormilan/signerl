-module(signerl_xml_SUITE).

-include_lib("eunit/include/eunit.hrl").
-compile([export_all, nowarn_export_all]).

suite() ->
    [{timetrap, {seconds, 30}}].

all() ->
    [fresh_xml_names_do_not_grow_atoms].

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
            filename:join(code:lib_dir(signerl), "ebin"),
            filename:join(code:lib_dir(xmlan), "ebin"),
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
    {ok, Parsed} = xmlan:parse_binary(Xml),
    {ok, Parsed} = xmlan:parse_binary(xmlan:export([], Parsed)),
    _ = xmlan_c14n:canonicalize(Parsed, c14n11),
    _ = xmlan_c14n:canonicalize(Parsed, exc_c14n),
    Signed = signerl:sign(Xml, sha256, Key),
    true = signerl:verify(Signed, sha256, PublicKey),
    {error, invalid_xml} = xmlan:parse_binary(
        <<"<broken_", Suffix/binary, "/>trailing garbage">>
    ),
    ok.
