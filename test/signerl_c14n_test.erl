-module(signerl_c14n_test).

-include_lib("eunit/include/eunit.hrl").

%% Basic

empty_element_expansion_test() ->
    Input = {doc, [], []},
    ?assertEqual(<<"<doc></doc>">>, signerl_c14n:canonicalize(Input)).

self_closing_to_start_end_test() ->
    Input = {doc, [], [{e1, [], []}, {e2, [], []}]},
    Expected = <<"<doc><e1></e1><e2></e2></doc>">>,
    ?assertEqual(Expected, signerl_c14n:canonicalize(Input)).

preserves_text_content_test() ->
    Input = {doc, [], ["Hello, world!"]},
    ?assertEqual(<<"<doc>Hello, world!</doc>">>, signerl_c14n:canonicalize(Input)).

preserves_whitespace_in_text_test() ->
    Input = {doc, [], ["  spaces  and\nnewlines  "]},
    ?assertEqual(<<"<doc>  spaces  and\nnewlines  </doc>">>, signerl_c14n:canonicalize(Input)).

nested_elements_test() ->
    Input = {a, [], [{b, [], [{c, [], ["text"]}]}]},
    ?assertEqual(<<"<a><b><c>text</c></b></a>">>, signerl_c14n:canonicalize(Input)).

multiple_children_test() ->
    Input = {doc, [], ["text1", {child, [], []}, "text2"]},
    ?assertEqual(<<"<doc>text1<child></child>text2</doc>">>, signerl_c14n:canonicalize(Input)).

%% Namespace

sorts_namespace_declarations_test() ->
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

eliminates_superfluous_ns_decls_test() ->
    Input =
        {root, [{'xmlns:a', "http://a.com"}], [
            {child, [{'xmlns:a', "http://a.com"}], ["text"]}
        ]},
    Expected = <<"<root xmlns:a=\"http://a.com\"><child>text</child></root>">>,
    ?assertEqual(Expected, signerl_c14n:canonicalize(Input)).

namespace_inheritance_test() ->
    Input =
        {root, [{'xmlns:ds', "http://www.w3.org/2000/09/xmldsig#"}], [
            {'ds:Child', [], ["content"]}
        ]},
    Expected = <<
        "<root xmlns:ds=\"http://www.w3.org/2000/09/xmldsig#\">"
        "<ds:Child>content</ds:Child></root>"
    >>,
    ?assertEqual(Expected, signerl_c14n:canonicalize(Input)).

default_namespace_test() ->
    Input =
        {root, [{xmlns, "http://example.org"}], [
            {child, [], ["text"]}
        ]},
    Expected = <<"<root xmlns=\"http://example.org\"><child>text</child></root>">>,
    ?assertEqual(Expected, signerl_c14n:canonicalize(Input)).

attribute_sorting_by_ns_uri_test() ->
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

mixed_ns_and_regular_attrs_test() ->
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

unprefixed_attrs_sort_before_prefixed_test() ->
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

%% Escaping

escapes_text_ampersand_test() ->
    Input = {doc, [], ["a&b"]},
    ?assertEqual(<<"<doc>a&amp;b</doc>">>, signerl_c14n:canonicalize(Input)).

escapes_text_lt_test() ->
    Input = {doc, [], ["a<b"]},
    ?assertEqual(<<"<doc>a&lt;b</doc>">>, signerl_c14n:canonicalize(Input)).

escapes_text_gt_test() ->
    Input = {doc, [], ["a>b"]},
    ?assertEqual(<<"<doc>a&gt;b</doc>">>, signerl_c14n:canonicalize(Input)).

escapes_text_cr_test() ->
    Input = {doc, [], ["a\rb"]},
    ?assertEqual(<<"<doc>a&#xD;b</doc>">>, signerl_c14n:canonicalize(Input)).

escapes_attr_ampersand_test() ->
    Input = {doc, [{v, "a&b"}], []},
    ?assertEqual(<<"<doc v=\"a&amp;b\"></doc>">>, signerl_c14n:canonicalize(Input)).

escapes_attr_lt_test() ->
    Input = {doc, [{v, "a<b"}], []},
    ?assertEqual(<<"<doc v=\"a&lt;b\"></doc>">>, signerl_c14n:canonicalize(Input)).

escapes_attr_quot_test() ->
    Input = {doc, [{v, "a\"b"}], []},
    ?assertEqual(<<"<doc v=\"a&quot;b\"></doc>">>, signerl_c14n:canonicalize(Input)).

escapes_attr_whitespace_chars_test() ->
    Input = {doc, [{v, "a\tb\nc\rd"}], []},
    ?assertEqual(<<"<doc v=\"a&#x9;b&#xA;c&#xD;d\"></doc>">>, signerl_c14n:canonicalize(Input)).

no_xml_declaration_test() ->
    Input = {doc, [], ["text"]},
    Result = signerl_c14n:canonicalize(Input),
    ?assertNotEqual(match, re:run(Result, "^<\\?xml", [{capture, none}])).

binary_text_child_test() ->
    Input = {doc, [], [<<"binary text">>]},
    ?assertEqual(<<"<doc>binary text</doc>">>, signerl_c14n:canonicalize(Input)).

attr_value_types_test() ->
    Input = {doc, [{b, <<"bin">>}, {i, 42}, {a, hello}], []},
    ?assertEqual(
        <<"<doc a=\"hello\" b=\"bin\" i=\"42\"></doc>">>,
        signerl_c14n:canonicalize(Input)
    ).

%% Transform

remove_signature_from_root_test() ->
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

remove_signature_preserves_other_children_test() ->
    Input =
        {root, [{id, "1"}], [
            {a, [], []},
            {b, [], []},
            {'ds:Signature', [], [{value, [], ["sig"]}]},
            {c, [], []}
        ]},
    Expected = {root, [{id, "1"}], [{a, [], []}, {b, [], []}, {c, [], []}]},
    ?assertEqual(Expected, signerl_c14n:remove_signature_elements(Input)).

remove_signature_no_signature_present_test() ->
    Input = {root, [], [{child, [], ["text"]}]},
    ?assertEqual(Input, signerl_c14n:remove_signature_elements(Input)).

%% Exc C14N

exc_c14n_omits_unused_ns_test() ->
    %% Parent declares ns1 and ns2, child only uses ns1 in tag.
    %% Exc-C14N: root emits neither (not visibly used), child emits ns1.
    Input = two_ns_input(),
    Result = signerl_c14n:canonicalize(Input, exc_c14n),
    ?assertEqual(
        <<"<root><ns1:child xmlns:ns1=\"http://ns1\">text</ns1:child></root>">>,
        Result
    ).

exc_c14n_keeps_visibly_used_ns_test() ->
    %% Child uses ns1 in tag and ns2 in attribute — both should be emitted.
    Input =
        {root, [{'xmlns:ns1', "http://ns1"}, {'xmlns:ns2', "http://ns2"}], [
            {'ns1:child', [{'ns2:attr', "val"}], ["text"]}
        ]},
    Result = signerl_c14n:canonicalize(Input, exc_c14n),
    ?assertNotEqual(nomatch, binary:match(Result, <<"xmlns:ns1=\"http://ns1\"">>)),
    ?assertNotEqual(nomatch, binary:match(Result, <<"xmlns:ns2=\"http://ns2\"">>)).

exc_c14n_propagates_ns_to_children_test() ->
    %% Grandchild uses ns1 but parent doesn't — exc-c14n should emit ns1 on grandchild.
    Input =
        {root, [{'xmlns:ns1', "http://ns1"}], [
            {middle, [], [
                {'ns1:leaf', [], ["deep"]}
            ]}
        ]},
    Result = signerl_c14n:canonicalize(Input, exc_c14n),
    ?assertNotEqual(
        nomatch, binary:match(Result, <<"<ns1:leaf xmlns:ns1=\"http://ns1\">deep</ns1:leaf>">>)
    ).

exc_c14n_binary_text_child_test() ->
    %% Binary text child should be handled the same as list text.
    Input = {root, [], [<<"binary text">>]},
    ?assertEqual(<<"<root>binary text</root>">>, signerl_c14n:canonicalize(Input, exc_c14n)).

exc_c14n_default_namespace_test() ->
    %% Element using default namespace (no prefix) should emit xmlns="...".
    Input = {child, [{xmlns, "http://default"}], ["text"]},
    Result = signerl_c14n:canonicalize(Input, exc_c14n),
    ?assertEqual(<<"<child xmlns=\"http://default\">text</child>">>, Result).

exc_c14n_ns_already_in_output_scope_test() ->
    %% When parent already emitted ns1, child should not re-emit it (NeedEmit=false path).
    Input =
        {'ns1:parent', [{'xmlns:ns1', "http://ns1"}], [
            {'ns1:child', [], ["text"]}
        ]},
    Result = signerl_c14n:canonicalize(Input, exc_c14n),
    %% ns1 appears once on parent, not re-emitted on child
    ?assertEqual(
        <<"<ns1:parent xmlns:ns1=\"http://ns1\"><ns1:child>text</ns1:child></ns1:parent>">>,
        Result
    ).

c14n11_emits_all_ns_decls_test() ->
    %% C14N 1.1 should emit ns2 on root even if only used by descendants.
    Input = two_ns_input(),
    C14N11 = signerl_c14n:canonicalize(Input, c14n11),
    %% ns2 should appear on root but NOT re-emitted on child
    ?assertNotEqual(nomatch, binary:match(C14N11, <<"xmlns:ns2=\"http://ns2\"">>)),
    %% Verify ns2 is NOT on child element in C14N 1.1
    ChildPart =
        case binary:match(C14N11, <<"<ns1:child">>) of
            {Start, _} -> binary:part(C14N11, Start, byte_size(C14N11) - Start);
            nomatch -> <<>>
        end,
    ?assertEqual(nomatch, binary:match(ChildPart, <<"xmlns:ns2">>)).

canonicalize_1_defaults_to_c14n11_test() ->
    Input = {root, [{'xmlns:ns1', "http://ns1"}], [{'ns1:child', [], ["text"]}]},
    ?assertEqual(
        signerl_c14n:canonicalize(Input, c14n11),
        signerl_c14n:canonicalize(Input)
    ).

%% Fixture helpers

two_ns_input() ->
    {root, [{'xmlns:ns1', "http://ns1"}, {'xmlns:ns2', "http://ns2"}], [
        {'ns1:child', [], ["text"]}
    ]}.

utf8_canonical_bytes_test_() ->
    Text = "café árvíztűrő 東京 😀",
    Utf8 = unicode:characters_to_binary(Text),
    Expected = <<"<ár érték=\"café árvíztűrő 東京 😀\">café árvíztűrő 東京 😀</ár>"/utf8>>,
    [
        {
            atom_to_list(Mode) ++ " " ++ Kind,
            ?_assertEqual(
                Expected, signerl_c14n:canonicalize({'ár', [{'érték', Value}], [Value]}, Mode)
            )
        }
     || Mode <- [c14n11, exc_c14n], {Kind, Value} <- [{"characters", Text}, {"UTF-8 bytes", Utf8}]
    ].
