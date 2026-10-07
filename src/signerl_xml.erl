-module(signerl_xml).
-include("signerl_xml.hrl").

-export([
    parse_file/1,
    parse_binary/1,
    parse_prolog/1,
    add_new_element/2,
    find_path/2,
    single_text/1,
    attr_value/2,
    attr_value_or_undefined/2,
    is_signature_element/1,
    export_fragment/1,
    export/2,
    to_file/2
]).

-type simplified_xml_item() :: simplified_xml() | string().
-type simplified_xml() :: {atom(), [{atom(), string() | number()}], [simplified_xml_item()]}.
-export_type([simplified_xml/0]).

-spec parse_file(FileName) -> SimplifiedXml when
    FileName :: string(),
    SimplifiedXml :: simplified_xml().
parse_file(FileName) ->
    {ok, Message} = file:read_file(FileName),
    {ok, Xml} = parse_binary(Message, [
        {current_location, filename:absname(filename:dirname(FileName))}
    ]),
    Xml.

-spec parse_binary(Message) -> Result when
    Message :: binary(),
    Result :: {ok, simplified_xml()} | {error, invalid_xml}.
parse_binary(Message) ->
    parse_binary(Message, []).

parse_binary(Message, Options) ->
    try
        Message = unicode:characters_to_binary(Message, utf8, utf8),
        true = utf8_encoding(Message),
        % NUL is illegal XML and also exposes BOM-less UTF-16/32 autodetection.
        nomatch = binary:match(Message, <<0>>),
        {ok, {[], [{document, [], [Root]}]}, Rest} = scan_xml(Message, Options),
        ok = validate_remainder(Rest),
        {ok, Root}
    catch
        _:_ ->
            {error, invalid_xml}
    end.

-spec parse_prolog(Message) -> Result when
    Message :: binary(),
    Result :: {ok, [string()]} | {error, invalid_prolog}.
parse_prolog(<<239, 187, 191, _/binary>>) ->
    {error, invalid_prolog};
parse_prolog(Message) when is_binary(Message) ->
    case re:run(Message, ?XML_PROLOG_EXTRACT_RE, [{capture, first, binary}]) of
        {match, [PrologBin]} ->
            case valid_prolog(PrologBin) of
                true ->
                    {ok, [binary_to_list(PrologBin)]};
                false ->
                    {error, invalid_prolog}
            end;
        nomatch ->
            {error, invalid_prolog}
    end.

scan_xml(Message, Options) ->
    xmerl_sax_parser:stream(Message, [
        {event_fun, fun xml_event/3},
        {event_state, {[], [{document, [], []}]}},
        disallow_entities,
        {external_entities, none},
        {entity_recurse_limit, ?XML_ENTITY_RECURSE_LIMIT},
        {fail_undeclared_ref, true}
        | Options
    ]).

% SAX streams can stop at a nonempty root's closing tag. Parsing the remainder
% after an empty sentinel root consumes XML Misc (comments/whitespace), rejects
% PIs through the same callback, and leaves any second document/garbage to reject.
validate_remainder(<<>>) ->
    ok;
validate_remainder(Rest) ->
    {ok, {[], [{document, [], [{tail, [], []}]}]}, <<>>} = scan_xml(
        <<"<tail/>", Rest/binary>>, []
    ),
    ok.

% Accumulate children in reverse order; namespace declarations belong to the
% following startElement. Keep character data, including whitespace-only events.
xml_event({startPrefixMapping, Prefix, Uri}, _, {Namespaces, Stack}) ->
    Name =
        case Prefix of
            [] -> xmlns;
            _ -> qualified_name({"xmlns", Prefix})
        end,
    {[{Name, Uri} | Namespaces], Stack};
xml_event({startElement, _, _, Name, Attributes}, _, {Namespaces, Stack}) ->
    Attrs = [{qualified_name({Prefix, Local}), Value} || {_, Prefix, Local, Value} <- Attributes],
    {[], [{qualified_name(Name), lists:reverse(Namespaces) ++ Attrs, []} | Stack]};
xml_event({endElement, _, _, _}, _, {[], [{Tag, Attrs, Content}, Parent | Stack]}) ->
    {[], [prepend_content({Tag, Attrs, lists:reverse(Content)}, Parent) | Stack]};
xml_event({ignorableWhitespace, _}, _, {[], [{document, [], _}]} = State) ->
    State;
xml_event({Kind, Text}, _, {Namespaces, [Element | Stack]}) when
    Kind =:= characters; Kind =:= ignorableWhitespace
->
    {Namespaces, [prepend_content(Text, Element) | Stack]};
% Abort before xmerl reads a DTD subset or resolves any declared entity.
xml_event({startDTD, _, _, _}, _, _) ->
    error(unsupported_dtd);
% xmerl can emit only endDTD for a bare <!DOCTYPE root>.
xml_event(endDTD, _, _) ->
    error(unsupported_dtd);
xml_event({processingInstruction, _, _}, _, _) ->
    error(unsupported_processing_instruction);
xml_event(_, _, State) ->
    State.

prepend_content(Item, {Tag, Attrs, Content}) ->
    {Tag, Attrs, [Item | Content]}.

qualified_name({[], Local}) -> list_to_atom(Local);
qualified_name({Prefix, Local}) -> list_to_atom(Prefix ++ ":" ++ Local).

utf8_encoding(Message) ->
    case re:run(Message, ?XML_ENCODING_EXTRACT_RE, [{capture, [2], binary}]) of
        {match, [Encoding]} -> string:lowercase(Encoding) =:= <<"utf-8">>;
        nomatch -> true
    end.

valid_prolog(PrologBin) ->
    case re:run(PrologBin, ?XML_PROLOG_VALID_RE) of
        {match, _} -> true;
        nomatch -> false
    end.

-spec export(Prolog, XmlTerm) -> Result when
    Prolog :: [string()],
    XmlTerm :: simplified_xml(),
    Result :: binary().
export(Prolog, XmlTerm) ->
    true = utf8_encoding(iolist_to_binary(Prolog)),
    unicode:characters_to_binary([Prolog, export_element(XmlTerm), "\n"]).

-spec export_fragment(XmlTerm) -> Result when
    XmlTerm :: simplified_xml(),
    Result :: binary().
export_fragment(XmlTerm) ->
    unicode:characters_to_binary(["<?xml version=\"1.0\"?>", export_element(XmlTerm)]).

-spec to_file(FileName, XmlBinary) -> Result when
    FileName :: string(),
    XmlBinary :: binary(),
    Result :: ok.
to_file(FileName, XmlBinary) ->
    Result = file:write_file(FileName, XmlBinary),
    Result.

-spec add_new_element(NewElement, Xml) -> Xml when
    NewElement :: simplified_xml(),
    Xml :: simplified_xml().
add_new_element(NewElement, {Tag, Attrs, Content}) ->
    {Tag, Attrs, Content ++ [NewElement]}.

-spec find_path(Path, Xml) -> Result when
    Path :: [atom(), ...],
    Xml :: simplified_xml(),
    Result :: {ok, simplified_xml()} | {error, not_found}.
find_path([Tag], Xml) ->
    find_unique_child(Tag, Xml);
find_path([Tag | Rest], Xml) ->
    case find_unique_child(Tag, Xml) of
        {ok, Child} ->
            find_path(Rest, Child);
        {error, not_found} ->
            {error, not_found}
    end.

-spec single_text(Xml) -> Result when
    Xml :: simplified_xml(),
    Result :: {ok, binary()} | {error, not_found}.
single_text({_, _, [Text]}) when is_binary(Text) ->
    {ok, Text};
single_text({_, _, [Text]}) when is_list(Text) ->
    {ok, unicode:characters_to_binary(Text)};
single_text(_) ->
    {error, not_found}.

-spec attr_value(Key, Attrs) -> Result when
    Key :: atom(),
    Attrs :: [{atom(), string() | number()}],
    Result :: {ok, string() | number()} | {error, missing_attribute}.
attr_value(Key, Attrs) ->
    case lists:keyfind(Key, 1, Attrs) of
        {Key, Value} ->
            {ok, Value};
        false ->
            {error, missing_attribute}
    end.

-spec attr_value_or_undefined(Key, Attrs) -> Result when
    Key :: atom(),
    Attrs :: [{atom(), string() | number()}],
    Result :: string() | number() | undefined.
attr_value_or_undefined(Key, Attrs) ->
    case lists:keyfind(Key, 1, Attrs) of
        {Key, Value} ->
            Value;
        false ->
            undefined
    end.

-spec is_signature_element(term()) -> boolean().
is_signature_element({'ds:Signature', _, _}) -> true;
is_signature_element(_) -> false.

find_unique_child(Tag, {_, _, Content}) ->
    Children = [Element || Element = {TagValue, _, _} <- Content, TagValue =:= Tag],
    case Children of
        [Child] ->
            {ok, Child};
        _ ->
            {error, not_found}
    end.

export_element(Element) ->
    export_content([Element], [], []).

% Keep pending closing tags and siblings on an explicit stack, so XML depth
% does not grow the call stack or the nesting of the accumulated output.
export_content([], [], Acc) ->
    lists:reverse(Acc);
export_content([], [{Name, Siblings} | Parents], Acc) ->
    export_content(Siblings, Parents, [["</", Name, ">"] | Acc]);
export_content([{Tag, Attrs, Content} | Rest], Parents, Acc) ->
    Name = atom_to_list(Tag),
    Attributes = [
        [" ", atom_to_list(Key), "=\"", export_attribute(Value), "\""]
     || {Key, Value} <- Attrs
    ],
    case Content of
        [] ->
            export_content(Rest, Parents, [["<", Name, Attributes, "/>"] | Acc]);
        _ ->
            export_content(Content, [{Name, Rest} | Parents], [["<", Name, Attributes, ">"] | Acc])
    end;
export_content([Text | Rest], Parents, Acc) ->
    Escaped = [export_character(Char, text) || Char <- xmerl_lib:export_text(Text)],
    export_content(Rest, Parents, [Escaped | Acc]).

export_attribute(Value) ->
    [export_character(Char, attribute) || Char <- xmerl_lib:export_attribute(Value)].

export_character($\r, _) -> "&#xD;";
export_character($\t, attribute) -> "&#x9;";
export_character($\n, attribute) -> "&#xA;";
export_character(Char, _) -> Char.
