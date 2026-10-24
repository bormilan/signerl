-module(signerl_dsig_utils).
-include("signerl_dsig.hrl").

-export([
    digest_base64/2,
    signature_method_uri_for_key/1,
    is_signature_element/1,
    is_signature_element/2,
    signature_inventory/1,
    remove_signature_elements/1
]).

digest_base64(HashAlgorithm, Payload) ->
    base64:encode(crypto:hash(HashAlgorithm, Payload)).

signature_method_uri_for_key(Key) when is_tuple(Key), tuple_size(Key) > 0 ->
    case element(1, Key) of
        'RSAPrivateKey' -> {ok, ?DSIG_SIG_RSA_SHA256_URI};
        'ECPrivateKey' -> {ok, ?DSIG_SIG_ECDSA_SHA256_URI};
        _ -> error
    end;
signature_method_uri_for_key(_) ->
    error.

-spec is_signature_element(term()) -> boolean().
is_signature_element(Element) ->
    is_signature_element(Element, #{}).

-spec is_signature_element(term(), xmlan:namespace_context()) -> boolean().
is_signature_element({Name, _, _} = Element, ParentNs) when is_binary(Name) ->
    xmlan:expanded_name(Element, ParentNs) =:= ?DSIG_NAME(<<"Signature">>);
is_signature_element(_, _) ->
    false.

% Signature policy only: count actual XMLDSig signatures at every depth and
% reserve unqualified Id / xml:id identities across the whole signed document.
-spec signature_inventory(xmlan:simplified_xml()) -> {non_neg_integer(), map()}.
signature_inventory(Message) ->
    signature_inventory([Message], #{}, [], 0, #{}).

signature_inventory([], _Ns, [], Count, Ids) ->
    {Count, Ids};
signature_inventory([], _Ns, [{Rest, ParentNs} | Stack], Count, Ids) ->
    signature_inventory(Rest, ParentNs, Stack, Count, Ids);
signature_inventory([{_, Attrs, Children} = Element | Rest], ParentNs, Stack, Count, Ids) ->
    Ns = xmlan:namespace_context(Attrs, ParentNs),
    NextCount =
        case is_signature_element(Element, ParentNs) of
            true -> Count + 1;
            false -> Count
        end,
    NextIds = lists:foldl(fun reserve_signature_id/2, Ids, Attrs),
    signature_inventory(Children, Ns, [{Rest, ParentNs} | Stack], NextCount, NextIds);
signature_inventory([_Text | Rest], Ns, Stack, Count, Ids) ->
    signature_inventory(Rest, Ns, Stack, Count, Ids).

reserve_signature_id({Name, Value}, Ids) when Name =:= <<"Id">>; Name =:= <<"xml:id">> ->
    Id = unicode:characters_to_list(Value),
    maps:update_with(Id, fun(Count) -> Count + 1 end, 1, Ids);
reserve_signature_id(_, Ids) ->
    Ids.

-spec remove_signature_elements(xmlan:simplified_xml()) -> xmlan:simplified_xml().
remove_signature_elements({Tag, Attrs, Children}) ->
    Namespaces = xmlan:namespace_context(Attrs, #{}),
    Filtered = [C || C <- Children, not is_signature_element(C, Namespaces)],
    {Tag, Attrs, Filtered}.
