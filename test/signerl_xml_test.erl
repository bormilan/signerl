-module(signerl_xml_test).

-include_lib("eunit/include/eunit.hrl").
-include("signerl_dsig.hrl").

parse_test() ->
    Path = "test/examples/base/books.xml",
    {<<"library">>, [{<<"id">>, "112233"}], [
        "\n    ",
        {<<"book">>, _, _},
        "\n    ",
        {<<"book">>, _, _},
        "\n    ",
        {<<"book">>, _, _},
        "\n"
    ]} = signerl_xml:parse_file(Path).

add_new_test() ->
    {ok, Root} = signerl_xml:parse_binary(
        <<"<library id='112233'> before <book/> after </library>">>
    ),
    Expected =
        {<<"library">>, [{<<"id">>, "112233"}], [
            " before ",
            {<<"book">>, [], []},
            " after ",
            {<<"book">>, [{<<"id">>, "4"}], [{<<"title">>, [], ["My new book"]}]}
        ]},
    ?assertEqual(Expected, signerl_xml:add_new_element(new_test_element(), Root)).

export_test() ->
    Path = "test/examples/base/books.xml",
    Root = signerl_xml:parse_file(Path),
    Prolog = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"],
    Binary = signerl_xml:export(Prolog, Root),

    ?assertEqual({ok, Prolog}, signerl_xml:parse_prolog(Binary)),
    ?assertEqual({ok, Root}, signerl_xml:parse_binary(Binary)).

caller_constructed_tree_test() ->
    Text = <<"árvíz & 東京"/utf8>>,
    Attrs = [{<<"label">>, <<"café & \"tea\""/utf8>>}],
    Root = {<<"root">>, Attrs, ["before ", {<<"child">>, [], [Text]}, " after"]},
    Expected = <<
        "<root label=\"café &amp; &quot;tea&quot;\">before "
        "<child>árvíz &amp; 東京</child> after</root>"/utf8
    >>,
    ?assertEqual(<<Expected/binary, "\n">>, signerl_xml:export([], Root)),
    ?assertEqual(
        <<"<?xml version=\"1.0\"?>", Expected/binary>>, signerl_xml:export_fragment(Root)
    ),
    {ok, Child} = signerl_xml:find_path([<<"child">>], Root),
    ?assertEqual({ok, Text}, signerl_xml:single_text(Child)),
    {ok, Parsed} = signerl_xml:parse_binary(signerl_xml:export([], Root)),
    ?assertEqual(Expected, signerl_c14n:canonicalize(Parsed)),
    ?assertEqual(Expected, signerl_c14n:canonicalize(Root)),
    ?assertEqual(Expected, signerl_c14n:canonicalize(Root, exc_c14n)).

attribute_value_representations_test_() ->
    [
        {Name, fun() ->
            Attrs = [{<<"value">>, Value}],
            Root = {<<"root">>, Attrs, []},
            ?assertEqual({ok, Value}, signerl_xml:attr_value(<<"value">>, Attrs)),
            ?assertEqual(Value, signerl_xml:attr_value_or_undefined(<<"value">>, Attrs)),
            ?assertEqual(
                {ok, {<<"root">>, [{<<"value">>, ParsedValue}], []}},
                signerl_xml:parse_binary(signerl_xml:export([], Root))
            ),
            Expected = unicode:characters_to_binary(["<root value=\"", ParsedValue, "\"></root>"]),
            ?assertEqual(Expected, signerl_c14n:canonicalize(Root)),
            ?assertEqual(Expected, signerl_c14n:canonicalize(Root, exc_c14n))
        end}
     || {Name, Value, ParsedValue} <- [
            {"Unicode character list", "café", "café"},
            {"UTF-8 binary", <<"café"/utf8>>, "café"},
            {"integer", -42, "-42"},
            {"atom", hello, "hello"}
        ]
    ].

export_nested_content_order_test() ->
    Root =
        {<<"root">>, [{<<"id">>, "a&b"}], [
            "before ",
            {<<"outer">>, [], ["left ", {<<"inner">>, [], ["<&>"]}, " right"]},
            " between ",
            {<<"empty">>, [{<<"value">>, "\t"}], []},
            " after"
        ]},
    Expected = <<
        "<root id=\"a&amp;b\">before <outer>left <inner>&lt;&amp;&gt;</inner> right</outer>"
        " between <empty value=\"&#x9;\"/> after</root>"
    >>,
    ?assertEqual(<<Expected/binary, "\n">>, signerl_xml:export([], Root)),
    ?assertEqual(
        <<"<?xml version=\"1.0\"?>", Expected/binary>>, signerl_xml:export_fragment(Root)
    ).

export_deep_tree_test() ->
    Depth = 10000,
    Root = lists:foldl(
        fun(_, Child) -> {<<"branch">>, [], [Child]} end,
        {<<"leaf">>, [], ["end<&>"]},
        lists:seq(1, Depth)
    ),
    Expected = iolist_to_binary([
        binary:copy(<<"<branch>">>, Depth),
        <<"<leaf>end&lt;&amp;&gt;</leaf>">>,
        binary:copy(<<"</branch>">>, Depth),
        "\n"
    ]),
    ?assertEqual(Expected, signerl_xml:export([], Root)).

parse_prolog_valid_test() ->
    Message = <<"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><root/>">>,
    ?assertEqual(
        {ok, ["<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"]},
        signerl_xml:parse_prolog(Message)
    ).

parse_prolog_missing_test() ->
    Message = <<"<root/>">>,
    ?assertEqual({error, invalid_prolog}, signerl_xml:parse_prolog(Message)).

parse_prolog_invalid_typo_test() ->
    Message = <<"<?xml versoin=\"1.0\" encoding=\"UTF-8\"?><root/>">>,
    ?assertEqual({error, invalid_prolog}, signerl_xml:parse_prolog(Message)).

parse_prolog_invalid_attribute_test() ->
    Message = <<"<?xml version=\"1.0\" foo=\"bar\"?><root/>">>,
    ?assertEqual({error, invalid_prolog}, signerl_xml:parse_prolog(Message)).

parse_prolog_invalid_malformed_declaration_test() ->
    Message = <<"<?xml version=\"1.0\" encoding=\"UTF-8\"<root/>">>,
    ?assertEqual({error, invalid_prolog}, signerl_xml:parse_prolog(Message)).

parse_prolog_rejects_bom_test() ->
    Message = <<16#EF, 16#BB, 16#BF, "<?xml version=\"1.0\" encoding=\"UTF-8\"?><root/>">>,
    ?assertEqual({error, invalid_prolog}, signerl_xml:parse_prolog(Message)).

parse_prolog_only_extracts_declaration_test() ->
    Message = <<"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root><child>1</child></root>">>,
    {ok, [Prolog]} = signerl_xml:parse_prolog(Message),
    ?assertEqual("<?xml version=\"1.0\" encoding=\"UTF-8\"?>", Prolog).

find_path_success_test() ->
    Root = test_helpers:signature_element([
        {<<"xades:SigningTime">>, [], ["2026-01-01T00:00:00Z"]}
    ]),
    ?assertMatch(
        {ok, {<<"xades:SigningTime">>, _, _}},
        signerl_xml:find_path(
            [
                <<"ds:Object">>,
                <<"xades:QualifyingProperties">>,
                <<"xades:SignedProperties">>,
                <<"xades:SignedSignatureProperties">>,
                <<"xades:SigningTime">>
            ],
            Root
        )
    ).

find_path_errors_on_missing_or_ambiguous_nodes_test_() ->
    [
        {Name, ?_assertEqual({error, not_found}, signerl_xml:find_path([<<"ds:Object">>], Root))}
     || {Name, Root} <- [
            {"missing", {<<"ds:Signature">>, [], []}},
            {"ambiguous",
                {<<"ds:Signature">>, [], [
                    {<<"ds:Object">>, [], []}, {<<"ds:Object">>, [], []}
                ]}}
        ]
    ].

single_text_test_() ->
    [
        {Name, ?_assertEqual(Expected, signerl_xml:single_text({<<"tag">>, [], Content}))}
     || {Name, Content, Expected} <- [
            {"binary", [<<"abc">>], {ok, <<"abc">>}},
            {"byte list", ["abc"], {ok, <<"abc">>}},
            {"empty", [], {error, not_found}},
            {"multiple text nodes", ["a", "b"], {error, not_found}}
        ]
    ].

export_fragment_exact_xml_test_() ->
    [
        {Name, ?_assertEqual(Expected, signerl_xml:export_fragment(Element))}
     || {Name, Element, Expected} <- [
            {"text content", {<<"tag">>, [], ["content"]},
                <<"<?xml version=\"1.0\"?><tag>content</tag>">>},
            {"empty element", {<<"tag">>, [], []}, <<"<?xml version=\"1.0\"?><tag/>">>},
            {"escaped attribute and text", {<<"tag">>, [{<<"id">>, "a&b"}], ["<value>"]},
                <<"<?xml version=\"1.0\"?><tag id=\"a&amp;b\">&lt;value&gt;</tag>">>}
        ]
    ].

%% Utils

new_test_element() ->
    NewTag = <<"book">>,
    NewAttrs = [{<<"id">>, "4"}],
    NewContent = [{<<"title">>, [], ["My new book"]}],
    {NewTag, NewAttrs, NewContent}.

is_signature_element_shared_test() ->
    SigElement = {<<"ds:Signature">>, [{<<"xmlns:ds">>, ?DSIG_NAMESPACE_URI}], []},
    NonSigElement = {<<"ds:SignedInfo">>, [], []},
    ?assertEqual(true, signerl_xml:is_signature_element(SigElement)),
    ?assertEqual(false, signerl_xml:is_signature_element(NonSigElement)),
    ?assertEqual(false, signerl_xml:is_signature_element("text")).

unicode_export_roundtrip_test() ->
    Root = {<<"root">>, [{<<"value">>, "café árvíztűrő 東京 😀"}], ["café árvíztűrő 東京 😀"]},
    Prolog = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"],
    Expected = <<"café árvíztűrő 東京 😀"/utf8>>,
    lists:foreach(
        fun(Binary) -> assert_export_roundtrip(Root, Expected, Binary) end,
        [signerl_xml:export(Prolog, Root), signerl_xml:export_fragment(Root)]
    ),
    ?assertEqual(
        {ok, Expected}, signerl_xml:single_text({<<"root">>, [], ["café árvíztűrő 東京 😀"]})
    ).

utf8_declaration_test_() ->
    [
        {Encoding, ?_assertEqual(Expected, signerl_xml:parse_prolog(Message))}
     || {Encoding, Expected, Message} <- [
            {"default", {ok, ["<?xml version='1.0'?>"]}, <<"<?xml version='1.0'?><root/>">>},
            {"mixed case", {ok, ["<?xml version='1.0' encoding = 'uTf-8'?>"]},
                <<"<?xml version='1.0' encoding = 'uTf-8'?><root/>">>},
            {"Latin-1", {error, invalid_prolog},
                <<"<?xml version='1.0' encoding='ISO-8859-1'?><root/>">>},
            {"UTF-16", {error, invalid_prolog},
                <<"<?xml version='1.0' encoding='UTF-16'?><root/>">>}
        ]
    ].

reject_non_utf8_input_test_() ->
    [
        {Name, ?_assertEqual({error, invalid_xml}, signerl_xml:parse_binary(Message))}
     || {Name, Message} <- [
            {"Latin-1 declaration", <<"<?xml version='1.0' encoding='ISO-8859-1'?><root/>">>},
            {"UTF-8 BOM with Latin-1 declaration",
                <<239, 187, 191, "<?xml version='1.0' encoding='ISO-8859-1'?><root/>">>},
            {"UTF-16 bytes",
                unicode:characters_to_binary(
                    "<?xml version='1.0' encoding='UTF-16'?><root/>", unicode, {utf16, big}
                )},
            {"UTF-16 bytes with no declaration",
                unicode:characters_to_binary("<root/>", unicode, {utf16, big})},
            {"isolated continuation byte", <<"<root>", 16#80, "</root>">>},
            {"overlong encoding", <<"<root>", 16#C0, 16#AF, "</root>">>},
            {"surrogate", <<"<root>", 16#ED, 16#A0, 16#80, "</root>">>},
            {"incomplete character", <<"<root/>", 16#F0, 16#9F>>}
        ]
    ].

export_rejects_unsupported_encoding_test() ->
    ?assertException(
        error,
        _,
        signerl_xml:export(
            ["<?xml version='1.0' encoding='ISO-8859-1'?>"], {<<"root">>, [], ["café"]}
        )
    ).

preserve_character_content_test_() ->
    [
        {Name,
            ?_assertEqual(
                Expected, signerl_c14n:canonicalize(element(2, signerl_xml:parse_binary(Xml)))
            )}
     || {Name, Xml, Expected} <- [
            {"separating whitespace", <<"<root><a/> <b/></root>">>,
                <<"<root><a></a> <b></b></root>">>},
            {"mixed and whitespace-only content", <<"<root>  before <a> \t\n </a> after  </root>">>,
                <<"<root>  before <a> \t\n </a> after  </root>">>},
            {"CDATA characters", <<"<root>left<![CDATA[ <&>\t ]]>right</root>">>,
                <<"<root>left &lt;&amp;&gt;\t right</root>">>},
            {"text carriage-return references", <<"<root>x&#xD;&#13;y</root>">>,
                <<"<root>x&#xD;&#xD;y</root>">>},
            {"literal line endings including CDATA",
                <<"<root>x\r\ny\rz<![CDATA[a\r\nb\rc]]></root>">>,
                <<"<root>x\ny\nza\nb\nc</root>">>},
            {"xml:space preserve", <<"<root xml:space='preserve'> \t\n </root>">>,
                <<"<root xml:space=\"preserve\"> \t\n </root>">>}
        ]
    ].

export_preserves_character_references_test() ->
    Root =
        {<<"root">>,
            [{<<"tab">>, "x\ty"}, {<<"lf">>, "x\ny"}, {<<"cr">>, "x\ry"}, {<<"literal">>, "&#x9;"}],
            ["t\rt<&>"]},
    ExpectedBody = <<
        "<root tab=\"x&#x9;y\" lf=\"x&#xA;y\" cr=\"x&#xD;y\" literal=\"&amp;#x9;\">"
        "t&#xD;t&lt;&amp;&gt;</root>"
    >>,
    lists:foreach(
        fun(Output) -> assert_export_roundtrip(Root, ExpectedBody, Output) end,
        [signerl_xml:export([], Root), signerl_xml:export_fragment(Root)]
    ).

reject_processing_instructions_test_() ->
    [
        {Name, ?_assertEqual({error, invalid_xml}, signerl_xml:parse_binary(Xml))}
     || {Name, Xml} <- [
            {"inside root", <<"<root><?report preserved?></root>">>},
            {"before root", <<"<?report preserved?><root/>">>},
            {"after empty root", <<"<root/><?report preserved?>">>},
            {"after nonempty root", <<"<root><a/></root><?report preserved?>">>},
            {"stylesheet", <<"<?xml-stylesheet href='a.xsl'?><root/>">>}
        ]
    ].

processing_instruction_text_is_not_an_instruction_test() ->
    ?assertEqual(
        {ok, {<<"root">>, [], ["<?report preserved?>"]}},
        signerl_xml:parse_binary(<<"<root><![CDATA[<?report preserved?>]]></root>">>)
    ),
    ?assertEqual(
        {ok, {<<"root">>, [], ["text"]}},
        signerl_xml:parse_binary(<<"<root><!-- <?report preserved?> -->text</root>">>)
    ).

trailing_misc_test_() ->
    [
        {Name, ?_assertEqual(Expected, signerl_xml:parse_binary(Xml))}
     || {Name, Xml, Expected} <- [
            {"trailing comments and whitespace",
                <<"<root><a/></root> \t\r\n<!-- preserved profile omits comments -->">>,
                {ok, {<<"root">>, [], [{<<"a">>, [], []}]}}},
            {"second root", <<"<root><a/></root><other/>">>, {error, invalid_xml}},
            {"trailing declaration", <<"<root><a/></root><?xml version='1.0'?>">>,
                {error, invalid_xml}},
            {"trailing DTD", <<"<root><a/></root><!DOCTYPE tail>">>, {error, invalid_xml}},
            {"trailing text", <<"<root><a/></root>unexpected">>, {error, invalid_xml}},
            {"second root after empty root", <<"<root/><extra/>">>, {error, invalid_xml}},
            {"trailing text after empty root", <<"<root/>not XML">>, {error, invalid_xml}},
            {"comments after empty root", <<"<root/> \t\r\n<!-- <extra/> -->">>,
                {ok, {<<"root">>, [], []}}},
            {"garbage after a comment", <<"<root/><!-- fine -->not XML">>, {error, invalid_xml}},
            {"unterminated comment", <<"<root><a/></root><!-- unfinished">>, {error, invalid_xml}},
            {"invalid comment separator", <<"<root/><!-- invalid -- separator -->">>,
                {error, invalid_xml}},
            {"incomplete markup", <<"<root><a/></root><">>, {error, invalid_xml}},
            {"CDATA outside root", <<"<root/><![CDATA[ ]]>">>, {error, invalid_xml}},
            {"character reference outside root", <<"<root><a/></root>&#x20;">>,
                {error, invalid_xml}},
            {"non-XML whitespace", <<"<root/>", 16#C2, 16#A0>>, {error, invalid_xml}},
            {"trailing BOM", <<"<root><a/></root>", 239, 187, 191>>, {error, invalid_xml}}
        ]
    ].

assert_export_roundtrip(Root, ExpectedBytes, Output) ->
    ?assertMatch({_, _}, binary:match(Output, ExpectedBytes)),
    ?assertEqual({ok, Root}, signerl_xml:parse_binary(Output)).

reject_dtd_test_() ->
    [
        {Name, ?_assertEqual({error, invalid_xml}, signerl_xml:parse_binary(Xml))}
     || {Name, Xml} <- [
            {"bare doctype", <<"<!DOCTYPE root><root/>">>},
            {"doctype whitespace", <<"<!DOCTYPE root \t\r\n><root/>">>},
            {"empty subset", <<"<!DOCTYPE root []><root/>">>},
            {"element declaration", <<"<!DOCTYPE root [<!ELEMENT root EMPTY>]><root/>">>},
            {"default attribute",
                <<"<!DOCTYPE root [<!ATTLIST root id CDATA 'default'>]><root/>">>},
            {"internal entity",
                <<"<!DOCTYPE root [<!ENTITY value 'expanded'>]><root>&value;</root>">>},
            {"parameter entity",
                <<"<!DOCTYPE root [<!ENTITY % value '<!ELEMENT root EMPTY>'>%value;]><root/>">>},
            {"undeclared entity", <<"<root>&unknown;</root>">>}
        ]
    ].

reject_bounded_exponential_expansion_test() ->
    % A small billion-laughs shape: at most 256 characters if expanded.
    Xml = <<
        "<!DOCTYPE root [<!ENTITY a 'ha'><!ENTITY b '&a;&a;&a;&a;'>"
        "<!ENTITY c '&b;&b;&b;&b;'>]><root>&c;&c;&c;&c;&c;&c;&c;&c;</root>"
    >>,
    ?assertEqual({error, invalid_xml}, signerl_xml:parse_binary(Xml)).

reject_bounded_quadratic_expansion_test() ->
    % A long entity repeated many times, bounded to 32 KiB before the fix.
    Value = binary:copy(<<"a">>, 512),
    Refs = binary:copy(<<"&value;">>, 64),
    Xml =
        <<"<!DOCTYPE root [<!ENTITY value '", Value/binary, "'>]><root>", Refs/binary, "</root>">>,
    ?assertEqual({error, invalid_xml}, signerl_xml:parse_binary(Xml)).

predefined_entities_and_character_references_test() ->
    Xml =
        <<
            "<root value='&lt;&gt;&amp;&quot;&apos;&#65;&#x1F600;'>"
            "&lt;&gt;&amp;&quot;&apos;&#65;&#x1F600;&amp;unknown;</root>"
        >>,
    ?assertEqual(
        {ok, {<<"root">>, [{<<"value">>, "<>&\"'A😀"}], ["<>&\"'A😀&unknown;"]}},
        signerl_xml:parse_binary(Xml)
    ).

dtd_looking_text_is_not_a_declaration_test() ->
    Xml =
        <<
            "<!-- <!DOCTYPE root> --><root>"
            "<![CDATA[<!DOCTYPE root [<!ENTITY value 'text'>]>]]></root>"
            "<!-- <!DOCTYPE root> -->"
        >>,
    ?assertEqual(
        {ok, {<<"root">>, [], ["<!DOCTYPE root [<!ENTITY value 'text'>]>"]}},
        signerl_xml:parse_binary(Xml)
    ).

xml_names_are_utf8_binaries_test() ->
    Xml =
        <<
            "<ár xmlns='urn:default' xmlns:ő='urn:prefixed' érték='v'>"/utf8,
            "<ő:東京 ő:érték='w'/></ár>"/utf8
        >>,
    Expected =
        {<<"ár"/utf8>>,
            [
                {<<"xmlns">>, "urn:default"},
                {<<"xmlns:ő"/utf8>>, "urn:prefixed"},
                {<<"érték"/utf8>>, "v"}
            ],
            [{<<"ő:東京"/utf8>>, [{<<"ő:érték"/utf8>>, "w"}], []}]},
    ?assertEqual({ok, Expected}, signerl_xml:parse_binary(Xml)).

xml_name_longer_than_atom_limit_test() ->
    Name = binary:copy(<<"n">>, 300),
    Xml = <<"<", Name/binary, " ", Name/binary, "='v'/>">>,
    ?assertEqual({ok, {Name, [{Name, "v"}], []}}, signerl_xml:parse_binary(Xml)).

namespace_qualified_lookup_test_() ->
    [
        {Label, fun() ->
            {ok, Root} = signerl_xml:parse_binary(Xml),
            Result = signerl_xml:find_path(Path, Root),
            case Expected of
                not_found -> ?assertEqual({error, not_found}, Result);
                Name -> ?assertMatch({ok, {Name, _, _}}, Result)
            end
        end}
     || {Label, Xml, Path, Expected} <- [
            {"inherited alias",
                <<"<root xmlns:s='http://www.w3.org/2000/09/xmldsig#'><s:SignedInfo/></root>">>,
                [?DSIG_NAME(<<"SignedInfo">>)], <<"s:SignedInfo">>},
            {"default namespace",
                <<"<root><SignedInfo xmlns='http://www.w3.org/2000/09/xmldsig#'/></root>">>,
                [?DSIG_NAME(<<"SignedInfo">>)], <<"SignedInfo">>},
            {"nested inherited binding",
                <<"<root xmlns:s='", ?DSIG_NAMESPACE_URI,
                    "'><s:Signature><s:SignedInfo/></s:Signature></root>">>,
                [?DSIG_NAME(<<"Signature">>), ?DSIG_NAME(<<"SignedInfo">>)], <<"s:SignedInfo">>},
            {"wrong URI decoy",
                <<"<root xmlns:ds='urn:wrong' xmlns:s='", ?DSIG_NAMESPACE_URI,
                    "'><ds:SignedInfo/><s:SignedInfo/></root>">>,
                [?DSIG_NAME(<<"SignedInfo">>)], <<"s:SignedInfo">>},
            {"subtree redeclaration",
                <<"<root xmlns:s='", ?DSIG_NAMESPACE_URI,
                    "'><s:Signature><s:SignedInfo xmlns:s='urn:wrong'/></s:Signature></root>">>,
                [?DSIG_NAME(<<"Signature">>), ?DSIG_NAME(<<"SignedInfo">>)], not_found},
            {"aliases are ambiguous",
                <<"<root xmlns:a='", ?DSIG_NAMESPACE_URI, "' xmlns:b='", ?DSIG_NAMESPACE_URI,
                    "'><a:SignedInfo/><b:SignedInfo/></root>">>,
                [?DSIG_NAME(<<"SignedInfo">>)], not_found},
            {"default undeclaration", <<"<root xmlns='urn:app'><child xmlns=''/></root>">>,
                [{<<>>, <<"child">>}], <<"child">>},
            {"wrong default URI", <<"<root xmlns='urn:app'><SignedInfo/></root>">>,
                [?DSIG_NAME(<<"SignedInfo">>)], not_found},
            {"missing intermediate node", <<"<root/>">>,
                [?DSIG_NAME(<<"Signature">>), ?DSIG_NAME(<<"SignedInfo">>)], not_found}
        ]
    ].

namespace_lookup_preserves_context_test() ->
    {ok, Root} = signerl_xml:parse_binary(<<
        "<root xmlns='urn:app' xmlns:s='http://www.w3.org/2000/09/xmldsig#' xmlns:q='urn:outer'>"
        "<s:Signature xmlns:q='urn:inner'><s:SignedInfo><q:child/>"
        "</s:SignedInfo></s:Signature></root>"
    >>),
    {ok, {<<"s:SignedInfo">>, Attrs, _} = Child} = signerl_xml:find_path(
        [?DSIG_NAME(<<"Signature">>), ?DSIG_NAME(<<"SignedInfo">>)], Root
    ),
    ?assertEqual({ok, "urn:app"}, signerl_xml:attr_value(<<"xmlns">>, Attrs)),
    ?assertEqual({ok, "urn:inner"}, signerl_xml:attr_value(<<"xmlns:q">>, Attrs)),
    ?assertEqual({ok, ?DSIG_NAMESPACE_URI}, signerl_xml:attr_value(<<"xmlns:s">>, Attrs)),
    ?assertEqual(
        <<"<s:SignedInfo xmlns=\"urn:app\" xmlns:q=\"urn:inner\" xmlns:s=\"", ?DSIG_NAMESPACE_URI,
            "\"><q:child></q:child></s:SignedInfo>">>,
        signerl_c14n:canonicalize(Child)
    ),
    %% Existing binary selectors remain lexical and return the original tuple.
    {ok, {<<"s:Signature">>, _, [Original]}} = signerl_xml:find_path([<<"s:Signature">>], Root),
    ?assertEqual(
        {ok, Original}, signerl_xml:find_path([<<"s:Signature">>, <<"s:SignedInfo">>], Root)
    ).

expanded_names_preserve_content_and_scope_test() ->
    Attrs = [{<<"xmlns:p">>, "urn:outer"}],
    InnerAttrs = [{<<"xmlns:p">>, <<"urn:inner">>}],
    Root =
        {<<"p:root">>, Attrs, [
            "before",
            {<<"p:child">>, InnerAttrs, [<<"text">>]},
            {<<"p:child">>, [], []},
            {<<"unbound:child">>, [], []},
            "after"
        ]},
    ?assertEqual(
        {{<<"urn:outer">>, <<"root">>}, Attrs, [
            "before",
            {{<<"urn:inner">>, <<"child">>}, InnerAttrs, [<<"text">>]},
            {{<<"urn:outer">>, <<"child">>}, [], []},
            {{undefined, <<"child">>}, [], []},
            "after"
        ]},
        signerl_xml:expanded_names(Root)
    ).

namespace_signature_recognition_test_() ->
    [
        {Label, ?_assertEqual(Expected, signerl_xml:is_signature_element(Element))}
     || {Label, Element, Expected} <- [
            {"alias", {<<"sig:Signature">>, [{<<"xmlns:sig">>, ?DSIG_NAMESPACE_URI}], []}, true},
            {"default", {<<"Signature">>, [{<<"xmlns">>, ?DSIG_NAMESPACE_URI}], []}, true},
            {"undeclared prefix", {<<"ds:Signature">>, [], []}, false},
            {"wrong namespace", {<<"ds:Signature">>, [{<<"xmlns:ds">>, "urn:wrong"}], []}, false},
            {"text", "ds:Signature", false}
        ]
    ].

parse_rejects_namespace_constraint_violations_test_() ->
    [
        {Label, ?_assertEqual({error, invalid_xml}, signerl_xml:parse_binary(Xml))}
     || {Label, Xml} <- [
            {"undeclared element prefix", <<"<p:root/>">>},
            {"undeclared attribute prefix", <<"<root p:a='1'/>">>},
            {"reserved xml rebinding",
                <<"<xml:Signature xmlns:xml='http://www.w3.org/2000/09/xmldsig#'/>">>},
            {"reserved xmlns prefix", <<"<root xmlns:xmlns='urn:wrong'/>">>},
            {"reserved xmlns URI", <<"<root xmlns:p='http://www.w3.org/2000/xmlns/'/>">>},
            {"XML URI on another prefix",
                <<"<root xmlns:p='http://www.w3.org/XML/1998/namespace'/>">>},
            {"XML URI as default", <<"<root xmlns='http://www.w3.org/XML/1998/namespace'/>">>},
            {"empty prefixed declaration", <<"<root xmlns:p=''><p:child/></root>">>},
            {"duplicate declaration", <<"<root xmlns:p='urn:one' xmlns:p='urn:two'/>">>},
            {"duplicate expanded attributes",
                <<"<root xmlns:a='urn:u' xmlns:b='urn:u' a:id='1' b:id='2'/>">>},
            {"multiple QName colons", <<"<a:b:c xmlns:a='urn:a'/>">>},
            {"empty QName local name", <<"<a: xmlns:a='urn:a'/>">>},
            {"empty QName prefix", <<"<:root/>">>},
            {"numeric QName local name", <<"<a:1 xmlns:a='urn:a'/>">>},
            {"attribute QName colons", <<"<root xmlns:a='urn:a' a:b:c='1'/>">>},
            {"numeric attribute local name", <<"<root xmlns:a='urn:a' a:1='1'/>">>},
            {"xmlns element prefix", <<"<xmlns:root/>">>},
            {"empty namespace declaration prefix", <<"<root xmlns:='urn:x'/>">>},
            {"spaced empty namespace prefix", <<"<root label='ok' xmlns: = 'urn:x'/>">>},
            {"nested empty namespace prefix",
                <<"<root xmlns:p='urn:x'><child xmlns:='urn:y'/></root>">>},
            {"relative prefixed URI", <<"<root xmlns:p='relative'/>">>},
            {"relative default URI", <<"<root xmlns='../relative'/>">>},
            {"fragment namespace URI", <<"<root xmlns:p='#local'/>">>},
            {"reserved xmlns default URI", <<"<root xmlns='http://www.w3.org/2000/xmlns/'/>">>}
        ]
    ].

parse_accepts_reserved_xml_and_rebound_namespaces_test() ->
    Xml = <<
        "<root xmlns:xml='http://www.w3.org/XML/1998/namespace' xml:lang='en' "
        "xmlns:p='urn:outer'><p:child xmlns:p='urn:inner' p:id='1'/><p:child/></root>"
    >>,
    ?assertMatch(
        {ok, {<<"root">>, _, [{<<"p:child">>, _, []}, {<<"p:child">>, _, []}]}},
        signerl_xml:parse_binary(Xml)
    ).

parse_accepts_distinct_attribute_namespaces_test() ->
    Xml = <<
        "<root xmlns='urn:root' xmlns:p='urn:root' id='1' p:id='2' xml:lang='en'>"
        "<child xmlns=''/></root>"
    >>,
    {ok, {<<"root">>, Attrs, [{<<"child">>, [{<<"xmlns">>, []}], []}]}} =
        signerl_xml:parse_binary(Xml),
    ?assertEqual({ok, "1"}, signerl_xml:attr_value(<<"id">>, Attrs)),
    ?assertEqual({ok, "2"}, signerl_xml:attr_value(<<"p:id">>, Attrs)).

parse_accepts_unicode_namespace_names_test() ->
    Xml = unicode:characters_to_binary("<é:根 xmlns:é='urn:unicode' é:値='ok'/>"),
    ?assertMatch({ok, {_, _, []}}, signerl_xml:parse_binary(Xml)).

lexical_path_missing_ancestor_test() ->
    Xml = {<<"root">>, [], [{<<"child">>, [], []}]},
    ?assertEqual({error, not_found}, signerl_xml:find_path([<<"missing">>, <<"child">>], Xml)).

namespace_like_literals_are_preserved_test_() ->
    [
        ?_assertMatch({ok, _}, signerl_xml:parse_binary(Xml))
     || Xml <- [
            <<"<root><!-- <child xmlns:='urn:x'/> --></root>">>,
            <<"<root><![CDATA[<child xmlns:='urn:x'/>]]></root>">>,
            <<"<root label=\"xmlns:='urn:x'\"/>">>,
            <<"<root>xmlns: = 'urn:x'</root>">>
        ]
    ].
