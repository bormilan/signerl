-module(signerl_dsig_utils).
-include("signerl_dsig.hrl").

-export([
    digest_base64/2,
    signature_method_uri_for_key/1,
    is_signature_element/1,
    is_signature_element/2,
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

-spec remove_signature_elements(xmlan:simplified_xml()) -> xmlan:simplified_xml().
remove_signature_elements({Tag, Attrs, Children}) ->
    Namespaces = xmlan:namespace_context(Attrs, #{}),
    Filtered = [C || C <- Children, not is_signature_element(C, Namespaces)],
    {Tag, Attrs, Filtered}.
