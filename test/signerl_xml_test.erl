-module(signerl_xml_test).

-include_lib("eunit/include/eunit.hrl").

parse_test() ->
    Path = "test/examples/books.xml",
    {library,
     [{id, "112233"}],
     [{book, _, _}, {book, _, _}, {book, _, _}]} = signerl_xml:parse_file(Path).

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

%% Utils

new_test_element() ->
    NewTag = book,
    NewAttrs = [{id, "4"}],
    NewContent = [{title, [], ["My new book"]}],
    {NewTag, NewAttrs, NewContent}.
