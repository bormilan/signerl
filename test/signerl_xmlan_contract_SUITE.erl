-module(signerl_xmlan_contract_SUITE).

-include_lib("stdlib/include/assert.hrl").

-compile([export_all, nowarn_export_all]).

all() ->
    [
        baseline_public_contract,
        invalid_canonicalization_mode,
        dependency_application_startup,
        compatibility_file_output
    ].

baseline_public_contract(_Config) ->
    Dir = signerl_utils:file_path("test/examples/xmlan_migration"),
    ok = xmlan_contract_consumer:run(Dir).

invalid_canonicalization_mode(_Config) ->
    ?assertException(
        error, function_clause, signerl_c14n:canonicalize({<<"root">>, [], []}, unsupported)
    ).

dependency_application_startup(_Config) ->
    ?assertMatch({ok, _}, application:ensure_all_started(signerl)),
    {ok, Applications} = application:get_key(signerl, applications),
    ?assert(lists:member(xmlan, Applications)),
    ?assertNot(lists:member(xmerl, Applications)),
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
            filename:dirname(code:which(xmlan_contract_consumer))
        ]
    }),
    try
        {ok, Started} = peer:call(Peer, application, ensure_all_started, [signerl]),
        ?assert(lists:member(xmlan, Started)),
        ?assert(lists:member(xmerl, Started)),
        Dir = signerl_utils:file_path("test/examples/xmlan_migration"),
        ok = peer:call(Peer, xmlan_contract_consumer, run, [Dir], 30000)
    after
        peer:stop(Peer)
    end.

compatibility_file_output(Config) ->
    Dir = signerl_utils:file_path("test/examples/xmlan_migration"),
    {ok, Bytes} = file:read_file(filename:join(Dir, "input.xml")),
    Path = filename:join(proplists:get_value(priv_dir, Config), "compatibility.xml"),
    ok = signerl_xml:to_file(Path, Bytes),
    {ok, [Expected]} = file:consult(filename:join(Dir, "parsed.term")),
    ?assertEqual({ok, Expected}, signerl_xml:parse_binary(Bytes)),
    ?assertEqual(Expected, signerl_xml:parse_file(Path)),
    Missing = filename:join([proplists:get_value(priv_dir, Config), "absent", "output.xml"]),
    ?assertEqual({error, enoent}, signerl_xml:to_file(Missing, Bytes)).
