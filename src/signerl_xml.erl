-module(signerl_xml).

-export([
         parse_file/1,
         add_new_element/2,
         export/2,
         to_file/2
        ]).

parse_file(FileName) ->
    {Element, _} = xmerl_scan:file(FileName, [{space, normalize}]),
    [Clean] = xmerl_lib:remove_whitespace([Element]),
    xmerl_lib:simplify_element(Clean).

export(Prolog, XmlTerm) ->
    Exported = xmerl:export([xmerl_lib:normalize_element(XmlTerm)], xmerl_xml, [{prolog, Prolog}]),
    list_to_binary(Exported ++ "\n").

to_file(FileName, XmlBinary) ->
    file:write_file(FileName, XmlBinary).

add_new_element(NewElement, {Tag, Attrs, Content}) ->
    {Tag, Attrs, Content ++ [NewElement]}.
