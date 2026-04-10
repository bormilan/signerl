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
    PathTo = "test/examples/xml/books_export_test.xml",
    Root = signerl_xml:parse_file(Path),
    Prolog = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"],
    Binary = signerl_xml:export(Prolog, Root),

    % TODO: make it to a temp file or delete it after
    ok = signerl_xml:to_file(PathTo, Binary),
    ?assertEqual(
        Root,
        signerl_xml:parse_file(PathTo)
    ).

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
    Root = {
        'ds:Signature',
        [],
        [
            {'ds:Object', [], [
                {'xades:QualifyingProperties', [], [
                    {'xades:SignedProperties', [], [
                        {'xades:SignedSignatureProperties', [], [
                            {'xades:SigningTime', [], ["2026-01-01T00:00:00Z"]}
                        ]}
                    ]}
                ]}
            ]}
        ]
    },
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

single_text_handles_binary_list_and_invalid_shapes_test() ->
    ?assertEqual({ok, <<"abc">>}, signerl_xml:single_text({tag, [], [<<"abc">>]})),
    ?assertEqual({ok, <<"abc">>}, signerl_xml:single_text({tag, [], ["abc"]})),
    ?assertEqual({error, not_found}, signerl_xml:single_text({tag, [], []})),
    ?assertEqual({error, not_found}, signerl_xml:single_text({tag, [], ["a", "b"]})).

export_fragment_returns_binary_test() ->
    Element = {tag, [], ["content"]},
    Result = signerl_xml:export_fragment(Element),
    ?assert(is_binary(Result)),
    ?assertNotEqual(<<>>, Result).

%% Utils

new_test_element() ->
    NewTag = book,
    NewAttrs = [{id, "4"}],
    NewContent = [{title, [], ["My new book"]}],
    {NewTag, NewAttrs, NewContent}.
