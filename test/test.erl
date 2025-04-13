-module(test).

-include_lib("eunit/include/eunit.hrl").

parse_test() ->
    Path = "examples/books.xml",
    {ok, _Xml} = ktn_xml:parse(Path).
