-module(signerl_xml).
-include("signerl_xml.hrl").

-export([
    parse_file/1,
    parse_binary/1,
    parse_prolog/1,
    add_new_element/2,
    export/2,
    to_file/2
]).

-type simplified_xml() :: {atom(), [{atom(), string() | number()}], [simplified_xml()]}.
-export_type([simplified_xml/0]).

-spec parse_file(FileName) -> SimplifiedXml when
    FileName :: string(),
    SimplifiedXml :: simplified_xml().
parse_file(FileName) ->
    {Element, _} = xmerl_scan:file(FileName, [{space, normalize}]),
    simplifie_xml_element(Element).

-spec parse_binary(Message) -> SimplifiedXml when
    Message :: binary(),
    SimplifiedXml :: simplified_xml().
parse_binary(Message) ->
    {Element, _} = xmerl_scan:string(binary_to_list(Message)),
    simplifie_xml_element(Element).

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

% private
-spec simplifie_xml_element(XmlElement) -> SimplifiedXml when
    XmlElement :: term(),
    SimplifiedXml :: simplified_xml().
simplifie_xml_element(XmlElement) ->
    [Clean] = xmerl_lib:remove_whitespace([XmlElement]),
    xmerl_lib:simplify_element(Clean).

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
    Exported = xmerl:export([xmerl_lib:normalize_element(XmlTerm)], xmerl_xml, [{prolog, Prolog}]),
    list_to_binary(Exported ++ "\n").

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
