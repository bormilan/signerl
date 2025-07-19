-module(signerl_xml).

-export([
    parse_file/1,
    add_new_element/2,
    export/2,
    to_file/2
]).

-type simplified_xml() :: {atom(), [{atom(), string() | number()}], [simplified_xml()]}.

-spec parse_file(FileName) -> SimplifiedXml when
    FileName :: string(),
    SimplifiedXml :: simplified_xml().
parse_file(FileName) ->
    {Element, _} = xmerl_scan:file(FileName, [{space, normalize}]),
    [Clean] = xmerl_lib:remove_whitespace([Element]),
    xmerl_lib:simplify_element(Clean).

-spec export(Prolog, XmlTerm) -> Result when
    Prolog :: string(),
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
    file:write_file(FileName, XmlBinary).

-spec add_new_element(NewElement, Xml) -> Xml when
    NewElement :: simplified_xml(),
    Xml :: simplified_xml().
add_new_element(NewElement, {Tag, Attrs, Content}) ->
    {Tag, Attrs, Content ++ [NewElement]}.
