-module(signerl_c14n_interop_SUITE).

-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").
-compile([export_all, nowarn_export_all]).

all() ->
    [{group, interop_group}].

groups() ->
    [
        {interop_group, [], [
            interop_simple_attrs,
            interop_namespaces,
            interop_nested_ns,
            interop_escaping,
            interop_default_ns,
            interop_mixed_content,
            interop_dsig_like,
            interop_utf8,
            interop_preserved_content
        ]}
    ].

init_per_suite(Config) ->
    Config.

end_per_suite(_Config) ->
    ok.

init_per_group(interop_group, Config) ->
    case os:find_executable("xmllint") of
        false -> {skip, "xmllint not available"};
        _Path -> Config
    end;
init_per_group(_Group, Config) ->
    Config.

end_per_group(_Group, _Config) ->
    ok.

interop_simple_attrs(Config) ->
    assert_matches_xmllint("simple_attrs.xml", Config).

interop_namespaces(Config) ->
    assert_matches_xmllint("namespaces.xml", Config).

interop_nested_ns(Config) ->
    assert_matches_xmllint("nested_ns.xml", Config).

interop_escaping(Config) ->
    assert_matches_xmllint("escaping.xml", Config).

interop_default_ns(Config) ->
    assert_matches_xmllint("default_ns.xml", Config).

interop_mixed_content(Config) ->
    assert_matches_xmllint("mixed_content.xml", Config).

interop_dsig_like(Config) ->
    assert_matches_xmllint("dsig_like.xml", Config).

assert_matches_xmllint(FileName, _Config) ->
    FilePath = filename:join([test_examples_dir(), "c14n", FileName]),
    XmllintOutput = run_xmllint(FilePath, "--c14n11"),
    OurOutput = run_our_c14n(FilePath),
    ?assertEqual(XmllintOutput, OurOutput).

test_examples_dir() ->
    SuiteFile = code:which(?MODULE),
    TestDir = filename:dirname(SuiteFile),
    filename:join(TestDir, "examples").

run_xmllint(FilePath, Mode) ->
    Port = open_port(
        {spawn_executable, os:find_executable("xmllint")},
        [{args, [Mode, FilePath]}, binary, exit_status, stderr_to_stdout]
    ),
    collect_port_output(Port, <<>>).

collect_port_output(Port, Acc) ->
    receive
        {Port, {data, Data}} ->
            collect_port_output(Port, <<Acc/binary, Data/binary>>);
        {Port, {exit_status, 0}} ->
            canonical_stdout(Acc);
        {Port, {exit_status, Code}} ->
            error({xmllint_failed, Code, Acc})
    after 5000 ->
        error(xmllint_timeout)
    end.

run_our_c14n(FilePath) ->
    {ok, RawXml} = file:read_file(FilePath),
    {ok, ParsedXml} = signerl_xml:parse_binary(RawXml),
    signerl_c14n:canonicalize(ParsedXml).

interop_utf8(Config) ->
    assert_matches_xmllint("utf8.xml", Config),
    Path = filename:join([test_examples_dir(), "c14n", "utf8.xml"]),
    {ok, Raw} = file:read_file(Path),
    {ok, Parsed} = signerl_xml:parse_binary(Raw),
    ?assertEqual(run_xmllint(Path, "--exc-c14n"), signerl_c14n:canonicalize(Parsed, exc_c14n)).

interop_preserved_content(Config) ->
    Path = filename:join([test_examples_dir(), "c14n", "preserved_content.xml"]),
    {ok, Raw} = file:read_file(Path),
    {ok, Parsed} = signerl_xml:parse_binary(Raw),
    OutputPath = filename:join(?config(priv_dir, Config), "preserved-export.xml"),
    ok = file:write_file(OutputPath, signerl_xml:export([], Parsed)),
    lists:foreach(
        fun({Mode, Flag}) ->
            Expected = run_xmllint(Path, Flag),
            ?assertEqual(Expected, signerl_c14n:canonicalize(Parsed, Mode)),
            ?assertEqual(Expected, run_xmllint(OutputPath, Flag))
        end,
        [{c14n11, "--c14n11"}, {exc_c14n, "--exc-c14n"}]
    ).

% xmllint's C14N mode writes stdout even with --output. Windows C stdio
% translates LF to CRLF. Undo that transport conversion only; XML CR values
% remain the literal bytes "&#xD;" and fixture/production bytes are untouched.
canonical_stdout(Output) ->
    case os:type() of
        {win32, _} -> binary:replace(Output, <<"\r\n">>, <<"\n">>, [global]);
        _ -> Output
    end.
