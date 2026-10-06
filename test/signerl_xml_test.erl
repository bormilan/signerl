-module(signerl_xml_test).

-include_lib("eunit/include/eunit.hrl").

parse_test() ->
    Path = "test/examples/base/books.xml",
    {library, [{id, "112233"}], [
        {book, _, _},
        {book, _, _},
        {book, _, _}
    ]} = signerl_xml:parse_file(
        Path
    ).

add_new_test() ->
    Path = "test/examples/base/books.xml",
    ExpectedPath = "test/examples/xml/books_with_new.xml",

    Root = signerl_xml:parse_file(Path),
    Expected = signerl_xml:parse_file(ExpectedPath),

    New =
        signerl_xml:add_new_element(new_test_element(), Root),

    ?assertEqual(
        Expected,
        New
    ).

export_test() ->
    Path = "test/examples/base/books.xml",
    Root = signerl_xml:parse_file(Path),
    Prolog = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"],
    Binary = signerl_xml:export(Prolog, Root),

    ?assertEqual({ok, Prolog}, signerl_xml:parse_prolog(Binary)),
    ?assertEqual({ok, Root}, signerl_xml:parse_binary(Binary)).

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
        {'xades:SigningTime', [], ["2026-01-01T00:00:00Z"]}
    ]),
    ?assertMatch(
        {ok, {'xades:SigningTime', _, _}},
        signerl_xml:find_path(
            [
                'ds:Object',
                'xades:QualifyingProperties',
                'xades:SignedProperties',
                'xades:SignedSignatureProperties',
                'xades:SigningTime'
            ],
            Root
        )
    ).

find_path_errors_on_missing_or_ambiguous_nodes_test() ->
    MissingRoot = {'ds:Signature', [], []},
    ?assertEqual({error, not_found}, signerl_xml:find_path(['ds:Object'], MissingRoot)),
    AmbiguousRoot = {
        'ds:Signature',
        [],
        [
            {'ds:Object', [], []},
            {'ds:Object', [], []}
        ]
    },
    ?assertEqual({error, not_found}, signerl_xml:find_path(['ds:Object'], AmbiguousRoot)).

single_text_test_() ->
    [
        {Name, ?_assertEqual(Expected, signerl_xml:single_text({tag, [], Content}))}
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
            {"text content", {tag, [], ["content"]},
                <<"<?xml version=\"1.0\"?><tag>content</tag>">>},
            {"empty element", {tag, [], []}, <<"<?xml version=\"1.0\"?><tag/>">>},
            {"escaped attribute and text", {tag, [{id, "a&b"}], ["<value>"]},
                <<"<?xml version=\"1.0\"?><tag id=\"a&amp;b\">&lt;value&gt;</tag>">>}
        ]
    ].

%% Utils

new_test_element() ->
    NewTag = book,
    NewAttrs = [{id, "4"}],
    NewContent = [{title, [], ["My new book"]}],
    {NewTag, NewAttrs, NewContent}.

is_signature_element_shared_test() ->
    SigElement = {'ds:Signature', [], []},
    NonSigElement = {'ds:SignedInfo', [], []},
    ?assertEqual(true, signerl_xml:is_signature_element(SigElement)),
    ?assertEqual(false, signerl_xml:is_signature_element(NonSigElement)),
    ?assertEqual(false, signerl_xml:is_signature_element("text")).

unicode_export_roundtrip_test() ->
    Root = {root, [{value, "café árvíztűrő 東京 😀"}], ["café árvíztűrő 東京 😀"]},
    Prolog = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"],
    Expected = <<"café árvíztűrő 東京 😀"/utf8>>,
    lists:foreach(
        fun(Binary) ->
            ?assertMatch({_, _}, binary:match(Binary, Expected)),
            ?assertEqual({ok, Root}, signerl_xml:parse_binary(Binary))
        end,
        [signerl_xml:export(Prolog, Root), signerl_xml:export_fragment(Root)]
    ),
    ?assertEqual({ok, Expected}, signerl_xml:single_text({root, [], ["café árvíztűrő 東京 😀"]})).

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
            ["<?xml version='1.0' encoding='ISO-8859-1'?>"], {root, [], ["café"]}
        )
    ).
