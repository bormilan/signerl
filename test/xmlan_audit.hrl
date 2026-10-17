-define(XMLAN_GENERIC, [
    {parse_file, 1},
    {parse_binary, 1},
    {parse_prolog, 1},
    {add_new_element, 2},
    {find_path, 2},
    {find_children, 2},
    {namespace_context, 2},
    {with_namespace_context, 2},
    {expanded_name, 2},
    {expanded_names, 1},
    {single_text, 1},
    {attr_value, 2},
    {attr_value_or_undefined, 2},
    {export_fragment, 1},
    {export, 2},
    {to_file, 2}
]).
-define(XMLAN_ALIASES, [
    attribute_value, simplified_xml, expanded_name, namespace_context, expanded_xml
]).
