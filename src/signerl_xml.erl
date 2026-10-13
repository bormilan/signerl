-module(signerl_xml).
-include("signerl_xml.hrl").
-include("signerl_dsig.hrl").

-export([
    parse_file/1,
    parse_binary/1,
    parse_prolog/1,
    add_new_element/2,
    find_path/2,
    find_children/2,
    namespace_context/2,
    with_namespace_context/2,
    expanded_name/2,
    expanded_names/1,
    single_text/1,
    attr_value/2,
    attr_value_or_undefined/2,
    is_signature_element/1,
    is_signature_element/2,
    export_fragment/1,
    export/2,
    to_file/2
]).

% Public, transparent tree: callers construct and pattern-match these tuples.
% Names and binary values are UTF-8; lists contain Unicode code points.
-type attribute_value() :: string() | binary() | integer() | atom().
-type simplified_xml_item() :: simplified_xml() | string() | binary().
-type simplified_xml() :: {binary(), [{binary(), attribute_value()}], [simplified_xml_item()]}.
-type expanded_name() :: {binary() | undefined, binary()}.
-type namespace_context() :: #{binary() => binary()}.
-type expanded_xml() ::
    {expanded_name(), [{binary(), attribute_value()}], [expanded_xml() | string() | binary()]}.
-export_type([
    simplified_xml/0,
    attribute_value/0,
    expanded_xml/0,
    expanded_name/0,
    namespace_context/0
]).

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
        % SAX normalizes invalid xmlns: into a default declaration. Check raw
        % start-tag attributes as well as the parsed namespace tree.
        nomatch = re:run(Message, ?XML_EMPTY_NAMESPACE_PREFIX_RE, [{capture, none}]),
        ok = validate_namespaces([Root], #{}, []),
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
    {ok, {[], [{document, [], [{<<"tail">>, [], []}]}]}, <<>>} = scan_xml(
        <<"<tail/>", Rest/binary>>, []
    ),
    ok.

% Accumulate children in reverse order; namespace declarations belong to the
% following startElement. Keep character data, including whitespace-only events.
xml_event({startPrefixMapping, Prefix, Uri}, _, {Namespaces, Stack}) ->
    Name =
        case Prefix of
            [] -> <<"xmlns">>;
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

% xmerl's SAX parser reports lexical names without enforcing all namespace
% constraints. Validate them without changing prefixes or serialized attributes.
validate_namespaces([], _Ns, []) ->
    ok;
validate_namespaces([], _Ns, [{Siblings, ParentNs} | Stack]) ->
    validate_namespaces(Siblings, ParentNs, Stack);
validate_namespaces([{Name, Attrs, Children} | Rest], ParentNs, Stack) ->
    Ns = namespace_context(Attrs, ParentNs),
    ok = validate_attributes(Attrs, Ns, #{}),
    _ = validated_name(Name, Ns, element),
    validate_namespaces(Children, Ns, [{Rest, ParentNs} | Stack]);
validate_namespaces([_Text | Rest], Ns, Stack) ->
    validate_namespaces(Rest, Ns, Stack).

validate_attributes([], _Ns, _Seen) ->
    ok;
validate_attributes([{Name, Value} | Rest], Ns, Seen) ->
    Expanded = validated_attribute(Name, Value, Ns),
    false = maps:is_key(Expanded, Seen),
    validate_attributes(Rest, Ns, Seen#{Expanded => true}).

validated_attribute(<<"xmlns">>, Uri, _Ns) ->
    ok = validate_binding(<<>>, unicode:characters_to_binary(Uri)),
    {?XMLNS_NAMESPACE_URI, <<>>};
validated_attribute(<<"xmlns:", Prefix/binary>>, Uri, _Ns) ->
    ok = validate_ncname(Prefix),
    ok = validate_binding(Prefix, unicode:characters_to_binary(Uri)),
    {?XMLNS_NAMESPACE_URI, Prefix};
validated_attribute(Name, _Value, Ns) ->
    validated_name(Name, Ns, attribute).

validate_binding(Prefix, Uri) ->
    true = Prefix =/= <<"xmlns">>,
    true = Uri =/= ?XMLNS_NAMESPACE_URI,
    true = (Prefix =:= <<"xml">>) =:= (Uri =:= ?XML_NAMESPACE_URI),
    true = Prefix =:= <<>> orelse Uri =/= <<>>,
    case Uri of
        <<>> ->
            ok;
        _ ->
            #{scheme := _} = uri_string:parse(Uri),
            ok
    end.

validated_name(Name, Ns, Kind) ->
    case binary:split(Name, <<":">>, [global]) of
        [Prefix, Local] ->
            ok = validate_ncname(Prefix),
            ok = validate_ncname(Local),
            true = Prefix =/= <<"xmlns">>,
            {maps:get(Prefix, Ns), Local};
        [Local] ->
            ok = validate_ncname(Local),
            case Kind of
                element -> {maps:get(<<>>, Ns), Local};
                attribute -> {<<>>, Local}
            end
    end.

validate_ncname(Name) ->
    match = re:run(Name, ?XML_NCNAME_RE, [unicode, {capture, none}]),
    ok.

prepend_content(Item, {Tag, Attrs, Content}) ->
    {Tag, Attrs, [Item | Content]}.

qualified_name({[], Local}) -> unicode:characters_to_binary(Local);
qualified_name({Prefix, Local}) -> unicode:characters_to_binary([Prefix, ":", Local]).

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
    Path :: [binary(), ...] | [expanded_name(), ...],
    Xml :: simplified_xml(),
    Result :: {ok, simplified_xml()} | {error, not_found}.
find_path([Name | _] = Path, Xml) when is_tuple(Name) ->
    find_namespace_path(Path, Xml, #{});
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
    Key :: binary(),
    Attrs :: [{binary(), attribute_value()}],
    Result :: {ok, attribute_value()} | {error, missing_attribute}.
attr_value(Key, Attrs) ->
    case lists:keyfind(Key, 1, Attrs) of
        {Key, Value} ->
            {ok, Value};
        false ->
            {error, missing_attribute}
    end.

-spec attr_value_or_undefined(Key, Attrs) -> Result when
    Key :: binary(),
    Attrs :: [{binary(), attribute_value()}],
    Result :: attribute_value() | undefined.
attr_value_or_undefined(Key, Attrs) ->
    case lists:keyfind(Key, 1, Attrs) of
        {Key, Value} ->
            Value;
        false ->
            undefined
    end.

% Namespace selectors return a standalone subtree with its in-scope bindings.
% Lexical binary selectors above retain the existing exact-name behavior.
find_namespace_path([Name | Rest], {_, Attrs, _} = Xml, ParentNs) ->
    CurrentNs = namespace_context(Attrs, ParentNs),
    case matching_children(Name, Xml, CurrentNs) of
        [Child] when Rest =:= [] ->
            {ok, with_namespace_context(Child, CurrentNs)};
        [Child] ->
            find_namespace_path(Rest, Child, CurrentNs);
        _ ->
            {error, not_found}
    end.

-spec find_children(expanded_name(), simplified_xml()) -> [simplified_xml()].
find_children(Name, {_, Attrs, _} = Xml) ->
    CurrentNs = namespace_context(Attrs, #{}),
    [with_namespace_context(Child, CurrentNs) || Child <- matching_children(Name, Xml, CurrentNs)].

matching_children(Name, {_, _, Content}, CurrentNs) ->
    [
        Child
     || Child = {Tag, _, _} <- Content,
        is_binary(Tag),
        expanded_name(Child, CurrentNs) =:= Name
    ].

-spec namespace_context([{binary(), attribute_value()}], namespace_context()) ->
    namespace_context().
namespace_context(Attrs, ParentNs) ->
    Initial = maps:merge(#{<<>> => <<>>, <<"xml">> => ?XML_NAMESPACE_URI}, ParentNs),
    lists:foldl(fun namespace_binding/2, Initial, Attrs).

namespace_binding({<<"xmlns">>, Uri}, Ns) ->
    Ns#{<<>> => unicode:characters_to_binary(Uri)};
namespace_binding({<<"xmlns:", Prefix/binary>>, Uri}, Ns) ->
    Ns#{Prefix => unicode:characters_to_binary(Uri)};
namespace_binding(_, Ns) ->
    Ns.

-spec expanded_name(simplified_xml(), namespace_context()) -> expanded_name().
expanded_name({Name, Attrs, _}, ParentNs) ->
    CurrentNs = namespace_context(Attrs, ParentNs),
    resolve_name(Name, CurrentNs).

resolve_name(Name, Ns) ->
    case binary:split(Name, <<":">>) of
        [Prefix, Local] -> {maps:get(Prefix, Ns, undefined), Local};
        [Local] -> {maps:get(<<>>, Ns), Local}
    end.

-spec with_namespace_context(simplified_xml(), namespace_context()) -> simplified_xml().
with_namespace_context({Name, Attrs, Content}, ParentNs) ->
    CurrentNs = namespace_context(Attrs, ParentNs),
    Inherited = [
        {namespace_attribute(Prefix), unicode:characters_to_list(Uri)}
     || {Prefix, Uri} <- maps:to_list(CurrentNs),
        Prefix =/= <<"xml">>,
        Uri =/= <<>>,
        not lists:keymember(namespace_attribute(Prefix), 1, Attrs)
    ],
    {Name, Attrs ++ Inherited, Content}.

namespace_attribute(<<>>) -> <<"xmlns">>;
namespace_attribute(Prefix) -> <<"xmlns:", Prefix/binary>>.

% This projection is for metadata validation only. Canonicalization always uses
% the original lexical names plus context, because prefixes affect signed bytes.
-spec expanded_names(simplified_xml()) -> expanded_xml().
expanded_names(Xml) ->
    expand_content([Xml], #{}, [], []).

expand_content([], _Ns, [], [Xml]) ->
    Xml;
expand_content([], _Ns, [{Name, Attrs, Siblings, ParentNs, Acc} | Stack], Children) ->
    expand_content(Siblings, ParentNs, Stack, [{Name, Attrs, lists:reverse(Children)} | Acc]);
expand_content([{Name, Attrs, Children} | Siblings], ParentNs, Stack, Acc) when is_binary(Name) ->
    CurrentNs = namespace_context(Attrs, ParentNs),
    Expanded = resolve_name(Name, CurrentNs),
    expand_content(Children, CurrentNs, [{Expanded, Attrs, Siblings, ParentNs, Acc} | Stack], []);
expand_content([Text | Rest], Ns, Stack, Acc) ->
    expand_content(Rest, Ns, Stack, [Text | Acc]).

-spec is_signature_element(term()) -> boolean().
is_signature_element(Element) ->
    is_signature_element(Element, #{}).

-spec is_signature_element(term(), namespace_context()) -> boolean().
is_signature_element({Name, _, _} = Element, ParentNs) when is_binary(Name) ->
    expanded_name(Element, ParentNs) =:= ?DSIG_NAME(<<"Signature">>);
is_signature_element(_, _) ->
    false.

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
export_content([{Name, Attrs, Content} | Rest], Parents, Acc) ->
    Attributes = [
        [" ", Key, "=\"", export_attribute(Value), "\""]
     || {Key, Value} <- Attrs
    ],
    case Content of
        [] ->
            export_content(Rest, Parents, [["<", Name, Attributes, "/>"] | Acc]);
        _ ->
            export_content(Content, [{Name, Rest} | Parents], [["<", Name, Attributes, ">"] | Acc])
    end;
export_content([Text | Rest], Parents, Acc) ->
    Escaped = [
        export_character(Char, text)
     || Char <- xmerl_lib:export_text(unicode:characters_to_list(Text))
    ],
    export_content(Rest, Parents, [Escaped | Acc]).

export_attribute(Value) when is_binary(Value) ->
    export_attribute(unicode:characters_to_list(Value));
export_attribute(Value) ->
    [export_character(Char, attribute) || Char <- xmerl_lib:export_attribute(Value)].

export_character($\r, _) -> "&#xD;";
export_character($\t, attribute) -> "&#x9;";
export_character($\n, attribute) -> "&#xA;";
export_character(Char, _) -> Char.
