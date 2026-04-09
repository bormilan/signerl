-module(signerl_c14n).

-export([canonicalize/1, remove_signature_elements/1]).

-spec canonicalize(signerl_xml:simplified_xml()) -> binary().
canonicalize(XmlTerm) ->
    list_to_binary(canonicalize_element(XmlTerm, #{})).

-spec remove_signature_elements(signerl_xml:simplified_xml()) -> signerl_xml:simplified_xml().
remove_signature_elements({Tag, Attrs, Children}) ->
    Filtered = [C || C <- Children, not is_signature_element(C)],
    {Tag, Attrs, Filtered}.

is_signature_element({'ds:Signature', _, _}) -> true;
is_signature_element(_) -> false.

%% --- Element serialization ---

-spec canonicalize_element(signerl_xml:simplified_xml(), map()) -> iolist().
canonicalize_element({Tag, Attrs, Children}, ParentNs) ->
    TagStr = atom_to_list(Tag),
    {NsDecls, RegularAttrs} = partition_attrs(Attrs),
    CurrentNs = merge_namespaces(ParentNs, NsDecls),
    NewNsDecls = new_namespace_decls(ParentNs, NsDecls),
    VisiblyUsed = visibly_used_prefixes(TagStr, RegularAttrs),
    EmittedNsDecls = filter_visibly_used(NewNsDecls, VisiblyUsed, ParentNs),
    SortedNsDecls = sort_ns_decls(EmittedNsDecls),
    SortedAttrs = sort_attributes(RegularAttrs, CurrentNs),
    [
        "<",
        TagStr,
        render_ns_decls(SortedNsDecls),
        render_attributes(SortedAttrs),
        ">",
        render_children(Children, CurrentNs),
        "</",
        TagStr,
        ">"
    ].

%% --- Attribute partitioning ---

partition_attrs(Attrs) ->
    partition_attrs(Attrs, [], []).

partition_attrs([], NsAcc, RegAcc) ->
    {lists:reverse(NsAcc), lists:reverse(RegAcc)};
partition_attrs([{Name, Value} | Rest], NsAcc, RegAcc) ->
    NameStr = atom_to_list(Name),
    case is_ns_decl(NameStr) of
        true ->
            partition_attrs(Rest, [{NameStr, Value} | NsAcc], RegAcc);
        false ->
            partition_attrs(Rest, NsAcc, [{NameStr, Value} | RegAcc])
    end.

is_ns_decl("xmlns") -> true;
is_ns_decl("xmlns:" ++ _) -> true;
is_ns_decl(_) -> false.

%% --- Namespace tracking ---

merge_namespaces(ParentNs, NsDecls) ->
    lists:foldl(
        fun({NameStr, Value}, Acc) ->
            Prefix = ns_decl_prefix(NameStr),
            Acc#{Prefix => Value}
        end,
        ParentNs,
        NsDecls
    ).

new_namespace_decls(ParentNs, NsDecls) ->
    [
        {NameStr, Value}
     || {NameStr, Value} <- NsDecls,
        maps:get(ns_decl_prefix(NameStr), ParentNs, undefined) =/= Value
    ].

ns_decl_prefix("xmlns") -> "";
ns_decl_prefix("xmlns:" ++ Prefix) -> Prefix.

%% --- Visible use filtering ---
%% C14N 1.1 §2.3: only emit namespace declarations for prefixes
%% that are visibly utilized by the element or its attributes.
%% For full-document canonicalization (not document subsets),
%% we emit all new/changed declarations since they are needed
%% by the element itself or its descendants.

visibly_used_prefixes(TagStr, RegularAttrs) ->
    TagPrefix = extract_prefix(TagStr),
    AttrPrefixes = [extract_prefix(N) || {N, _} <- RegularAttrs, extract_prefix(N) =/= ""],
    sets:from_list([TagPrefix | AttrPrefixes]).

extract_prefix(Name) ->
    case string:split(Name, ":") of
        [Prefix, _] -> Prefix;
        [_] -> ""
    end.

filter_visibly_used(NewNsDecls, _VisiblyUsed, _ParentNs) ->
    %% For full-document canonicalization, all new/changed namespace
    %% declarations must be emitted (they may be needed by descendants).
    %% Superfluous declarations are already filtered by new_namespace_decls/2.
    NewNsDecls.

%% --- Sorting ---

sort_ns_decls(NsDecls) ->
    lists:sort(
        fun({A, _}, {B, _}) ->
            ns_decl_prefix(A) =< ns_decl_prefix(B)
        end,
        NsDecls
    ).

sort_attributes(Attrs, NsMap) ->
    Keyed = [
        {attr_sort_key(Name, NsMap), Name, Value}
     || {Name, Value} <- Attrs
    ],
    Sorted = lists:sort(
        fun({KeyA, _, _}, {KeyB, _, _}) -> KeyA =< KeyB end,
        Keyed
    ),
    [{Name, Value} || {_, Name, Value} <- Sorted].

attr_sort_key(Name, NsMap) ->
    case string:split(Name, ":") of
        [Prefix, LocalName] ->
            NsUri = maps:get(Prefix, NsMap, ""),
            {NsUri, LocalName};
        [LocalName] ->
            {"", LocalName}
    end.

%% --- Rendering ---

render_ns_decls([]) ->
    [];
render_ns_decls([{NameStr, Value} | Rest]) ->
    [" ", NameStr, "=\"", escape_attr_value(Value), "\"" | render_ns_decls(Rest)].

render_attributes([]) ->
    [];
render_attributes([{Name, Value} | Rest]) ->
    StrValue = value_to_string(Value),
    [" ", Name, "=\"", escape_attr_value(StrValue), "\"" | render_attributes(Rest)].

render_children([], _Ns) ->
    [];
render_children([Child | Rest], Ns) ->
    [render_child(Child, Ns) | render_children(Rest, Ns)].

render_child({_, _, _} = Element, Ns) ->
    canonicalize_element(Element, Ns);
render_child(Text, _Ns) when is_list(Text) ->
    escape_text(Text);
render_child(Text, _Ns) when is_binary(Text) ->
    escape_text(binary_to_list(Text)).

%% --- Escaping (C14N 1.1 §2.3) ---

escape_attr_value(Value) ->
    escape_attr_value(Value, []).

escape_attr_value([], Acc) ->
    lists:reverse(Acc);
escape_attr_value([$& | Rest], Acc) ->
    escape_attr_value(Rest, lists:reverse("&amp;", Acc));
escape_attr_value([$< | Rest], Acc) ->
    escape_attr_value(Rest, lists:reverse("&lt;", Acc));
escape_attr_value([$" | Rest], Acc) ->
    escape_attr_value(Rest, lists:reverse("&quot;", Acc));
escape_attr_value([16#09 | Rest], Acc) ->
    escape_attr_value(Rest, lists:reverse("&#x9;", Acc));
escape_attr_value([16#0A | Rest], Acc) ->
    escape_attr_value(Rest, lists:reverse("&#xA;", Acc));
escape_attr_value([16#0D | Rest], Acc) ->
    escape_attr_value(Rest, lists:reverse("&#xD;", Acc));
escape_attr_value([C | Rest], Acc) ->
    escape_attr_value(Rest, [C | Acc]).

escape_text(Text) ->
    escape_text(Text, []).

escape_text([], Acc) ->
    lists:reverse(Acc);
escape_text([$& | Rest], Acc) ->
    escape_text(Rest, lists:reverse("&amp;", Acc));
escape_text([$< | Rest], Acc) ->
    escape_text(Rest, lists:reverse("&lt;", Acc));
escape_text([$> | Rest], Acc) ->
    escape_text(Rest, lists:reverse("&gt;", Acc));
escape_text([16#0D | Rest], Acc) ->
    escape_text(Rest, lists:reverse("&#xD;", Acc));
escape_text([C | Rest], Acc) ->
    escape_text(Rest, [C | Acc]).

%% --- Helpers ---

value_to_string(V) when is_list(V) -> V;
value_to_string(V) when is_binary(V) -> binary_to_list(V);
value_to_string(V) when is_integer(V) -> integer_to_list(V);
value_to_string(V) when is_atom(V) -> atom_to_list(V).
