-module(signerl_xml).
-include("signerl_dsig.hrl").

% Generic XML compatibility API; implementations are owned by xmlan.
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

% Compatibility aliases remain transparent to callers.
-type attribute_value() :: xmlan:attribute_value().
-type simplified_xml() :: xmlan:simplified_xml().
-type expanded_name() :: xmlan:expanded_name().
-type namespace_context() :: xmlan:namespace_context().
-type expanded_xml() :: xmlan:expanded_xml().
-export_type([
    simplified_xml/0, attribute_value/0, expanded_xml/0, expanded_name/0, namespace_context/0
]).

-spec parse_file(FileName) -> SimplifiedXml when
    FileName :: string(),
    SimplifiedXml :: simplified_xml().
parse_file(FileName) ->
    xmlan:parse_file(FileName).

-spec parse_binary(Message) -> Result when
    Message :: binary(),
    Result :: {ok, simplified_xml()} | {error, invalid_xml}.
parse_binary(Message) ->
    xmlan:parse_binary(Message).

-spec parse_prolog(Message) -> Result when
    Message :: binary(),
    Result :: {ok, [string()]} | {error, invalid_prolog}.
parse_prolog(Message) ->
    xmlan:parse_prolog(Message).

-spec add_new_element(NewElement, Xml) -> Xml when
    NewElement :: simplified_xml(),
    Xml :: simplified_xml().
add_new_element(NewElement, Xml) ->
    xmlan:add_new_element(NewElement, Xml).

-spec find_path(Path, Xml) -> Result when
    Path :: [binary(), ...] | [expanded_name(), ...],
    Xml :: simplified_xml(),
    Result :: {ok, simplified_xml()} | {error, not_found}.
find_path(Path, Xml) ->
    xmlan:find_path(Path, Xml).

-spec find_children(expanded_name(), simplified_xml()) -> [simplified_xml()].
find_children(Name, Xml) ->
    xmlan:find_children(Name, Xml).

-spec namespace_context([{binary(), attribute_value()}], namespace_context()) ->
    namespace_context().
namespace_context(Attrs, ParentNs) ->
    xmlan:namespace_context(Attrs, ParentNs).

-spec with_namespace_context(simplified_xml(), namespace_context()) -> simplified_xml().
with_namespace_context(Xml, ParentNs) ->
    xmlan:with_namespace_context(Xml, ParentNs).

-spec expanded_name(simplified_xml(), namespace_context()) -> expanded_name().
expanded_name(Xml, ParentNs) ->
    xmlan:expanded_name(Xml, ParentNs).

-spec expanded_names(simplified_xml()) -> expanded_xml().
expanded_names(Xml) ->
    xmlan:expanded_names(Xml).

-spec single_text(Xml) -> Result when
    Xml :: simplified_xml(),
    Result :: {ok, binary()} | {error, not_found}.
single_text(Xml) ->
    xmlan:single_text(Xml).

-spec attr_value(Key, Attrs) -> Result when
    Key :: binary(),
    Attrs :: [{binary(), attribute_value()}],
    Result :: {ok, attribute_value()} | {error, missing_attribute}.
attr_value(Key, Attrs) ->
    xmlan:attr_value(Key, Attrs).

-spec attr_value_or_undefined(Key, Attrs) -> Result when
    Key :: binary(),
    Attrs :: [{binary(), attribute_value()}],
    Result :: attribute_value() | undefined.
attr_value_or_undefined(Key, Attrs) ->
    xmlan:attr_value_or_undefined(Key, Attrs).

-spec export_fragment(XmlTerm) -> Result when
    XmlTerm :: simplified_xml(),
    Result :: binary().
export_fragment(XmlTerm) ->
    xmlan:export_fragment(XmlTerm).

-spec export(Prolog, XmlTerm) -> Result when
    Prolog :: [string()],
    XmlTerm :: simplified_xml(),
    Result :: binary().
export(Prolog, XmlTerm) ->
    xmlan:export(Prolog, XmlTerm).

-spec to_file(FileName, XmlBinary) -> Result when
    FileName :: string(),
    XmlBinary :: binary(),
    Result :: ok | {error, term()}.
to_file(FileName, XmlBinary) ->
    xmlan:to_file(FileName, XmlBinary).

-spec is_signature_element(term()) -> boolean().
is_signature_element(Element) ->
    is_signature_element(Element, #{}).

-spec is_signature_element(term(), namespace_context()) -> boolean().
is_signature_element({Name, _, _} = Element, ParentNs) when is_binary(Name) ->
    xmlan:expanded_name(Element, ParentNs) =:= ?DSIG_NAME(<<"Signature">>);
is_signature_element(_, _) ->
    false.
