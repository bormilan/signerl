-module(signerl_c14n_SUITE).

-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").
-compile([export_all, nowarn_export_all]).

all() ->
    [
        {group, basic_group},
        {group, namespace_group},
        {group, escaping_group},
        {group, transform_group},
        {group, interop_group}
    ].

groups() ->
    [
        {basic_group, [], [
            empty_element_expansion,
            self_closing_to_start_end,
            preserves_text_content,
            preserves_whitespace_in_text,
            nested_elements,
            multiple_children
        ]},
        {namespace_group, [], [
            sorts_namespace_declarations,
            eliminates_superfluous_ns_decls,
            namespace_inheritance,
            default_namespace,
            attribute_sorting_by_ns_uri,
            mixed_ns_and_regular_attrs,
            unprefixed_attrs_sort_before_prefixed
        ]},
        {escaping_group, [], [
            escapes_text_ampersand,
            escapes_text_lt,
            escapes_text_gt,
            escapes_text_cr,
            escapes_attr_ampersand,
            escapes_attr_lt,
            escapes_attr_quot,
            escapes_attr_whitespace_chars,
            no_xml_declaration,
            binary_text_child,
            attr_value_types
        ]},
        {transform_group, [], [
            remove_signature_from_root,
            remove_signature_preserves_other_children,
            remove_signature_no_signature_present
        ]},
        {interop_group, [], [
            interop_simple_attrs,
            interop_namespaces,
            interop_nested_ns,
            interop_escaping,
            interop_default_ns,
            interop_mixed_content,
            interop_dsig_like
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

%% === Basic Group ===

empty_element_expansion(_Config) ->
    Input = {doc, [], []},
    ?assertEqual(<<"<doc></doc>">>, signerl_c14n:canonicalize(Input)).

self_closing_to_start_end(_Config) ->
    Input = {doc, [], [{e1, [], []}, {e2, [], []}]},
    Expected = <<"<doc><e1></e1><e2></e2></doc>">>,
    ?assertEqual(Expected, signerl_c14n:canonicalize(Input)).

preserves_text_content(_Config) ->
    Input = {doc, [], ["Hello, world!"]},
    ?assertEqual(<<"<doc>Hello, world!</doc>">>, signerl_c14n:canonicalize(Input)).

preserves_whitespace_in_text(_Config) ->
    Input = {doc, [], ["  spaces  and\nnewlines  "]},
    ?assertEqual(<<"<doc>  spaces  and\nnewlines  </doc>">>, signerl_c14n:canonicalize(Input)).

nested_elements(_Config) ->
    Input = {a, [], [{b, [], [{c, [], ["text"]}]}]},
    ?assertEqual(<<"<a><b><c>text</c></b></a>">>, signerl_c14n:canonicalize(Input)).

multiple_children(_Config) ->
    Input = {doc, [], ["text1", {child, [], []}, "text2"]},
    ?assertEqual(<<"<doc>text1<child></child>text2</doc>">>, signerl_c14n:canonicalize(Input)).

%% === Namespace Group ===

%% W3C C14N 1.1 §3.3: namespace declarations sorted lexicographically by prefix
sorts_namespace_declarations(_Config) ->
    Input =
        {'e5',
            [
                {'xmlns:b', "http://www.ietf.org"},
                {'xmlns:a', "http://www.w3.org"},
                {xmlns, "http://example.org"}
            ],
            []},
    Expected = <<
        "<e5 xmlns=\"http://example.org\""
        " xmlns:a=\"http://www.w3.org\""
        " xmlns:b=\"http://www.ietf.org\"></e5>"
    >>,
    ?assertEqual(Expected, signerl_c14n:canonicalize(Input)).

%% Superfluous namespace declarations are removed
eliminates_superfluous_ns_decls(_Config) ->
    Input =
        {root, [{'xmlns:a', "http://a.com"}], [
            {child, [{'xmlns:a', "http://a.com"}], ["text"]}
        ]},
    Expected = <<"<root xmlns:a=\"http://a.com\"><child>text</child></root>">>,
    ?assertEqual(Expected, signerl_c14n:canonicalize(Input)).

%% Child elements inherit parent namespaces
namespace_inheritance(_Config) ->
    Input =
        {root, [{'xmlns:ds', "http://www.w3.org/2000/09/xmldsig#"}], [
            {'ds:Child', [], ["content"]}
        ]},
    Expected = <<
        "<root xmlns:ds=\"http://www.w3.org/2000/09/xmldsig#\">"
        "<ds:Child>content</ds:Child></root>"
    >>,
    ?assertEqual(Expected, signerl_c14n:canonicalize(Input)).

%% Default namespace handling
default_namespace(_Config) ->
    Input =
        {root, [{xmlns, "http://example.org"}], [
            {child, [], ["text"]}
        ]},
    Expected = <<"<root xmlns=\"http://example.org\"><child>text</child></root>">>,
    ?assertEqual(Expected, signerl_c14n:canonicalize(Input)).

%% W3C C14N 1.1 §4.5: attributes sorted by (namespace URI, local name)
attribute_sorting_by_ns_uri(_Config) ->
    Input =
        {'e5',
            [
                {xmlns, "http://example.org"},
                {'xmlns:a', "http://www.w3.org"},
                {'xmlns:b', "http://www.ietf.org"},
                {'a:attr', "out"},
                {'b:attr', "sorted"},
                {attr2, "all"},
                {attr, "I'm"}
            ],
            []},
    %% Sort order: unprefixed attrs by local name (empty NS URI),
    %% then prefixed attrs by (NS URI, local name)
    %% attr (empty,"attr"), attr2 (empty,"attr2"),
    %% b:attr ("http://www.ietf.org","attr"), a:attr ("http://www.w3.org","attr")
    Expected = <<
        "<e5"
        " xmlns=\"http://example.org\""
        " xmlns:a=\"http://www.w3.org\""
        " xmlns:b=\"http://www.ietf.org\""
        " attr=\"I'm\""
        " attr2=\"all\""
        " b:attr=\"sorted\""
        " a:attr=\"out\""
        "></e5>"
    >>,
    ?assertEqual(Expected, signerl_c14n:canonicalize(Input)).

%% Mixed namespace declarations and regular attributes maintain proper order
mixed_ns_and_regular_attrs(_Config) ->
    Input =
        {elem,
            [
                {'xmlns:z', "http://z.com"},
                {id, "1"},
                {name, "test"}
            ],
            []},
    Expected = <<"<elem xmlns:z=\"http://z.com\" id=\"1\" name=\"test\"></elem>">>,
    ?assertEqual(Expected, signerl_c14n:canonicalize(Input)).

%% Unprefixed attributes sort before prefixed ones (empty NS URI is least)
unprefixed_attrs_sort_before_prefixed(_Config) ->
    Input =
        {elem,
            [
                {'xmlns:ns', "http://ns.com"},
                {'ns:b', "2"},
                {a, "1"}
            ],
            []},
    Expected = <<"<elem xmlns:ns=\"http://ns.com\" a=\"1\" ns:b=\"2\"></elem>">>,
    ?assertEqual(Expected, signerl_c14n:canonicalize(Input)).

%% === Escaping Group ===

escapes_text_ampersand(_Config) ->
    Input = {doc, [], ["a&b"]},
    ?assertEqual(<<"<doc>a&amp;b</doc>">>, signerl_c14n:canonicalize(Input)).

escapes_text_lt(_Config) ->
    Input = {doc, [], ["a<b"]},
    ?assertEqual(<<"<doc>a&lt;b</doc>">>, signerl_c14n:canonicalize(Input)).

escapes_text_gt(_Config) ->
    Input = {doc, [], ["a>b"]},
    ?assertEqual(<<"<doc>a&gt;b</doc>">>, signerl_c14n:canonicalize(Input)).

escapes_text_cr(_Config) ->
    Input = {doc, [], ["a\rb"]},
    ?assertEqual(<<"<doc>a&#xD;b</doc>">>, signerl_c14n:canonicalize(Input)).

escapes_attr_ampersand(_Config) ->
    Input = {doc, [{v, "a&b"}], []},
    ?assertEqual(<<"<doc v=\"a&amp;b\"></doc>">>, signerl_c14n:canonicalize(Input)).

escapes_attr_lt(_Config) ->
    Input = {doc, [{v, "a<b"}], []},
    ?assertEqual(<<"<doc v=\"a&lt;b\"></doc>">>, signerl_c14n:canonicalize(Input)).

escapes_attr_quot(_Config) ->
    Input = {doc, [{v, "a\"b"}], []},
    ?assertEqual(<<"<doc v=\"a&quot;b\"></doc>">>, signerl_c14n:canonicalize(Input)).

escapes_attr_whitespace_chars(_Config) ->
    Input = {doc, [{v, "a\tb\nc\rd"}], []},
    ?assertEqual(<<"<doc v=\"a&#x9;b&#xA;c&#xD;d\"></doc>">>, signerl_c14n:canonicalize(Input)).

%% C14N §4.1: No XML declaration in output
no_xml_declaration(_Config) ->
    Input = {doc, [], ["text"]},
    Result = signerl_c14n:canonicalize(Input),
    ?assertNotEqual(match, re:run(Result, "^<\\?xml", [{capture, none}])).

%% Binary text children are handled
binary_text_child(_Config) ->
    Input = {doc, [], [<<"binary text">>]},
    ?assertEqual(<<"<doc>binary text</doc>">>, signerl_c14n:canonicalize(Input)).

%% Attribute values can be binary, integer, or atom
attr_value_types(_Config) ->
    Input = {doc, [{b, <<"bin">>}, {i, 42}, {a, hello}], []},
    ?assertEqual(
        <<"<doc a=\"hello\" b=\"bin\" i=\"42\"></doc>">>,
        signerl_c14n:canonicalize(Input)
    ).

%% === Transform Group ===

remove_signature_from_root(_Config) ->
    Input =
        {root, [], [
            {child, [], ["text"]},
            {'ds:Signature', [{'xmlns:ds', "http://www.w3.org/2000/09/xmldsig#"}], [
                {'ds:SignedInfo', [], []}
            ]},
            {other, [], ["data"]}
        ]},
    Expected =
        {root, [], [
            {child, [], ["text"]},
            {other, [], ["data"]}
        ]},
    ?assertEqual(Expected, signerl_c14n:remove_signature_elements(Input)).

remove_signature_preserves_other_children(_Config) ->
    Input =
        {root, [{id, "1"}], [
            {a, [], []},
            {b, [], []},
            {'ds:Signature', [], [{value, [], ["sig"]}]},
            {c, [], []}
        ]},
    Expected = {root, [{id, "1"}], [{a, [], []}, {b, [], []}, {c, [], []}]},
    ?assertEqual(Expected, signerl_c14n:remove_signature_elements(Input)).

remove_signature_no_signature_present(_Config) ->
    Input = {root, [], [{child, [], ["text"]}]},
    ?assertEqual(Input, signerl_c14n:remove_signature_elements(Input)).

%% === Interop Group ===
%% Compare our C14N 1.1 output against xmllint --c14n11

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

%% --- Helpers ---

assert_matches_xmllint(FileName, _Config) ->
    FilePath = filename:join([test_examples_dir(), "c14n", FileName]),
    XmllintOutput = run_xmllint_c14n11(FilePath),
    OurOutput = run_our_c14n(FilePath),
    ?assertEqual(XmllintOutput, OurOutput).

test_examples_dir() ->
    SuiteFile = code:which(?MODULE),
    TestDir = filename:dirname(SuiteFile),
    filename:join(TestDir, "examples").

run_xmllint_c14n11(FilePath) ->
    Port = open_port(
        {spawn_executable, os:find_executable("xmllint")},
        [{args, ["--c14n11", FilePath]}, binary, exit_status, stderr_to_stdout]
    ),
    collect_port_output(Port, <<>>).

collect_port_output(Port, Acc) ->
    receive
        {Port, {data, Data}} ->
            collect_port_output(Port, <<Acc/binary, Data/binary>>);
        {Port, {exit_status, 0}} ->
            Acc;
        {Port, {exit_status, Code}} ->
            error({xmllint_failed, Code, Acc})
    after 5000 ->
        error(xmllint_timeout)
    end.

run_our_c14n(FilePath) ->
    {ParsedXml, _} = xmerl_scan:file(FilePath),
    Simplified = xmerl_lib:simplify_element(ParsedXml),
    signerl_c14n:canonicalize(Simplified).
