-module(signerl_c14n).

-export([canonicalize/1, canonicalize/2, remove_signature_elements/1]).

-type c14n_mode() :: xmlan_c14n:c14n_mode().
-export_type([c14n_mode/0]).

-spec canonicalize(xmlan:simplified_xml()) -> binary().
canonicalize(XmlTerm) ->
    xmlan_c14n:canonicalize(XmlTerm).

-spec canonicalize(xmlan:simplified_xml(), c14n_mode()) -> binary().
canonicalize(XmlTerm, Mode) ->
    xmlan_c14n:canonicalize(XmlTerm, Mode).

-spec remove_signature_elements(xmlan:simplified_xml()) -> xmlan:simplified_xml().
remove_signature_elements({Tag, Attrs, Children}) ->
    Namespaces = xmlan:namespace_context(Attrs, #{}),
    Filtered = [C || C <- Children, not signerl_xml:is_signature_element(C, Namespaces)],
    {Tag, Attrs, Filtered}.
