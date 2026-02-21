-module(signerl_xml_test).

-include_lib("eunit/include/eunit.hrl").

parse_test() ->
    Path = "test/examples/books.xml",
    {library, [{id, "112233"}], [
        {book, _, _},
        {book, _, _},
        {book, _, _}
    ]} = signerl_xml:parse_file(
        Path
    ).

add_new_test() ->
    Path = "test/examples/books.xml",
    ExpectedPath = "test/examples/books_with_new.xml",

    Root = signerl_xml:parse_file(Path),
    Expected = signerl_xml:parse_file(ExpectedPath),

    New =
        signerl_xml:add_new_element(new_test_element(), Root),

    ?assertEqual(
        Expected,
        New
    ).

export_test() ->
    Path = "test/examples/books.xml",
    PathTo = "test/examples/books_export_test.xml",
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

%% Utils

new_test_element() ->
    NewTag = book,
    NewAttrs = [{id, "4"}],
    NewContent = [{title, [], ["My new book"]}],
    {NewTag, NewAttrs, NewContent}.
