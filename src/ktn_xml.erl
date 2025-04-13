-module(ktn_xml).

-feature(maybe_expr, enable).

-export([parse/1]).

% -define(ANGLE, Value).
-record(xml_node, {name, attributes, content, indent, children}).

parse(_File) ->
    FilePath = "examples/books_raw.xml",
    {ok, Binary} = file:read_file(FilePath),
    {Prolog, Xml} = get_first_tag(Binary),
    Tags = parse_tags(Xml),
    io:format(user, "~n----------------------------------~n", []),
    io:format(user, "~p~n", [Prolog]),
    io:format(user, "~p~n", [Tags]),
    io:format(user, "------------------------------------~n", []),
    ok.

parse_tags(Binary) ->
    parse_tags(Binary, []).

parse_tags(<<"\n\n">>, Acc) ->
    lists:reverse(Acc);
parse_tags({Binary, _}, Acc) ->
    {TagHead, Tail} = get_first_tag(Binary),
    {TagName, Attributes} = parse_tag_head(TagHead),

    io:format(user, "~n----------------------------------~n", []),
    io:format(user, "~p~n", [TagName]),
    io:format(user, "------------------------------------~n", []),
    [TagTail, ContentTail] =
        case is_tag(Tail) of
            true ->
                io:format(user, "~n----------------------------------~n", []),
                io:format(user, "~p~n", [1]),
                io:format(user, "------------------------------------~n", []),
                binary:split(Tail, [<<"</", TagName/binary, ">">>]);
            false ->
                io:format(user, "~n----------------------------------~n", []),
                io:format(user, "~p~n", [Tail]),
                io:format(user, "------------------------------------~n", []),
                cut_content(Tail)
        end,

    NewTag = #xml_node{
        name = TagName, attributes = Attributes, content = TagTail, indent = [], children = []
    },
    % <<TagHead/binary, " ", Attributes/binary, TagTail/binary>>
    case is_tag(NewTag#xml_node.content) of
        true -> parse_tags({NewTag#xml_node.content, ContentTail}, Acc);
        false -> parse_tags(ContentTail, [NewTag | Acc])
    end;
parse_tags(Binary, Acc) ->
    parse_tags({Binary, root}, Acc).

get_first_tag(Binary) ->
    [Tag, Tail] = binary:split(Binary, [<<">">>]),
    case binary:first(Tag) of
        $/ -> get_first_tag(Tail);
        _ -> {<<Tag/binary, ">">>, Tail}
    end.

parse_tag_head(TagHead) ->
    case binary:split(TagHead, [<<" ">>]) of
        [TagName, Attributes] -> {strip_tag(TagName), Attributes};
        _ -> {strip_tag(TagHead), <<>>}
    end.

strip_tag(Tag) ->
    binary:replace(Tag, [<<"<">>, <<">">>], <<"">>).

-spec is_tag(binary()) -> boolean().
is_tag(Binary) ->
    $< =:= binary:first(Binary).

cut_content(Binary) ->
    binary:split(Binary, [<<"<">>]).
