-module(signerl_verify).
-feature(maybe_expr, enable).
-include("signerl_dsig.hrl").

-export([extract_signature_data/1, verify_reference_digests/2]).

-spec extract_signature_data(Message) -> Result when
    Message :: {atom(), [{atom(), string() | number()}], [any()]},
    Result :: {ok, map()} | {error, invalid_signature}.
extract_signature_data({Tag, Attrs, Content}) ->
    {SignatureElements, UnsignedContent} = lists:partition(fun is_signature_element/1, Content),
    case SignatureElements of
        [SignatureElement] ->
            decode_signature_data(SignatureElement, {Tag, Attrs, UnsignedContent});
        _ ->
            {error, invalid_signature}
    end.

-spec verify_reference_digests(SignatureData, Hash) -> Result when
    SignatureData :: map(),
    Hash :: atom(),
    Result :: true | false | {error, invalid_signature}.
verify_reference_digests(
    #{
        unsigned_message := UnsignedMessage,
        signature_element := SignatureElement,
        references := #{
            document := #{digest_value := DocumentDigestValue} = DocumentReference,
            signed_properties := #{
                digest_value := SignedPropertiesDigestValue
            } = SignedPropertiesReference
        } = References
    },
    Hash
) ->
    maybe
        {ok, DigestMethodUri} ?= digest_method_uri(Hash),
        SignatureMethodUris = [?DSIG_SIG_RSA_SHA256_URI, ?DSIG_SIG_ECDSA_SHA256_URI],
        ok ?= validate_signed_info_algorithms(References, SignatureMethodUris),
        ok ?= validate_document_reference(DocumentReference, DigestMethodUri),
        ok ?= validate_signed_properties_reference(SignedPropertiesReference, DigestMethodUri),
        {ok, SignedPropertiesElement} ?=
            signerl_xades_xml:find_signed_properties_element(SignatureElement),
        DocumentPayload = signerl_xml:export_fragment(UnsignedMessage),
        SignedPropertiesPayload = signerl_xml:export_fragment(SignedPropertiesElement),
        DocumentDigest = crypto:hash(Hash, DocumentPayload),
        SignedPropertiesDigest = crypto:hash(Hash, SignedPropertiesPayload),
        case
            {
                DocumentDigest =:= DocumentDigestValue,
                SignedPropertiesDigest =:= SignedPropertiesDigestValue
            }
        of
            {true, true} ->
                true;
            _ ->
                false
        end
    else
        _ ->
            {error, invalid_signature}
    end;
verify_reference_digests(_, _) ->
    {error, invalid_signature}.

decode_signature_data(SignatureElement, UnsignedMessage) ->
    maybe
        {ok, SignatureBytes} ?= signature_value(SignatureElement),
        {ok, SignedProperties} ?= signerl_signed_properties:extract(SignatureElement),
        {ok, SignedInfoElement} ?= signed_info_element(SignatureElement),
        {ok, References} ?= signed_info_references(SignedInfoElement),
        {ok, #{
            signature_bytes => SignatureBytes,
            unsigned_message => UnsignedMessage,
            signed_properties => SignedProperties,
            signature_element => SignatureElement,
            signed_info_element => SignedInfoElement,
            references => References
        }}
    else
        _ ->
            {error, invalid_signature}
    end.

is_signature_element({'ds:Signature', _, _}) ->
    true;
is_signature_element(_) ->
    false.

signature_value({'ds:Signature', _, _} = SignatureElement) ->
    decode_signature_value(signerl_xml:find_path(['ds:SignatureValue'], SignatureElement)).

decode_signature_value({ok, {'ds:SignatureValue', _, [SignatureValue]}}) ->
    decode_base64_binary(SignatureValue);
decode_signature_value({ok, {'ds:SignatureValue', _, _}}) ->
    {error, invalid_signature};
decode_signature_value(error) ->
    {error, invalid_signature}.

signed_info_element({'ds:Signature', _, _} = SignatureElement) ->
    case signerl_xml:find_path(['ds:SignedInfo'], SignatureElement) of
        {ok, {'ds:SignedInfo', _, _} = SignedInfoElement} ->
            {ok, SignedInfoElement};
        _ ->
            {error, invalid_signature}
    end.

signed_info_references({'ds:SignedInfo', _, _} = SignedInfoElement) ->
    {'ds:SignedInfo', _, SignedInfoContent} = SignedInfoElement,
    maybe
        {ok, {'ds:CanonicalizationMethod', C14NAttrs, _}} ?=
            signerl_xml:find_path(['ds:CanonicalizationMethod'], SignedInfoElement),
        {ok, C14NAlgorithm} ?= attr_value('Algorithm', C14NAttrs),
        {ok, {'ds:SignatureMethod', SignatureMethodAttrs, _}} ?=
            signerl_xml:find_path(['ds:SignatureMethod'], SignedInfoElement),
        {ok, SignatureMethodAlgorithm} ?= attr_value('Algorithm', SignatureMethodAttrs),
        ReferenceElements =
            [Element || Element = {'ds:Reference', _, _} <- SignedInfoContent],
        {ok, DocumentReference, SignedPropertiesReference} ?=
            decode_reference_elements(ReferenceElements),
        {ok, #{
            c14n_algorithm => C14NAlgorithm,
            signature_algorithm => SignatureMethodAlgorithm,
            document => DocumentReference,
            signed_properties => SignedPropertiesReference
        }}
    else
        _ ->
            {error, invalid_signature}
    end.

decode_reference_elements(ReferenceElements) ->
    DocumentReferences =
        [
            Reference
         || Reference = {'ds:Reference', Attrs, _} <- ReferenceElements,
            attr_value('URI', Attrs) =:= {ok, ""}
        ],
    SignedPropertiesReferences =
        [
            Reference
         || Reference = {'ds:Reference', Attrs, _} <- ReferenceElements,
            attr_value('URI', Attrs) =:= {ok, "#" ++ ?SIGNED_PROPERTIES_ID}
        ],
    case {DocumentReferences, SignedPropertiesReferences} of
        {[DocumentReferenceElement], [SignedPropertiesReferenceElement]} ->
            maybe
                {ok, DocumentReference} ?= decode_reference(DocumentReferenceElement),
                {ok, SignedPropertiesReference} ?=
                    decode_reference(SignedPropertiesReferenceElement),
                {ok, DocumentReference, SignedPropertiesReference}
            else
                _ ->
                    {error, invalid_signature}
            end;
        _ ->
            {error, invalid_signature}
    end.

decode_reference({'ds:Reference', Attrs, ReferenceContent}) ->
    ReferenceElement = {'ds:Reference', [], ReferenceContent},
    maybe
        {ok, Uri} ?= attr_value('URI', Attrs),
        {ok, TransformUris} ?= transform_uris(ReferenceElement),
        {ok, DigestMethodElement} ?= signerl_xml:find_path(['ds:DigestMethod'], ReferenceElement),
        {ok, DigestMethodUri} ?= attr_value('Algorithm', element(2, DigestMethodElement)),
        {ok, DigestValueElement} ?= signerl_xml:find_path(['ds:DigestValue'], ReferenceElement),
        {ok, DigestValueText} ?= signerl_xml:single_text(DigestValueElement),
        {ok, DigestValue} ?= decode_base64_binary(DigestValueText),
        {ok, #{
            uri => Uri,
            type => attr_value_or_undefined('Type', Attrs),
            transforms => TransformUris,
            digest_method => DigestMethodUri,
            digest_value => DigestValue
        }}
    else
        _ ->
            {error, invalid_signature}
    end.

transform_uris(ReferenceElement) ->
    case signerl_xml:find_path(['ds:Transforms'], ReferenceElement) of
        {ok, {'ds:Transforms', _, TransformElements}} ->
            decode_transform_uris(TransformElements, []);
        error ->
            {ok, []}
    end.

decode_transform_uris([], Acc) ->
    {ok, lists:reverse(Acc)};
decode_transform_uris([{'ds:Transform', Attrs, []} | Rest], Acc) ->
    case attr_value('Algorithm', Attrs) of
        {ok, Algorithm} ->
            decode_transform_uris(Rest, [Algorithm | Acc]);
        {error, invalid_signature} ->
            {error, invalid_signature}
    end;
decode_transform_uris([_Other | _Rest], _Acc) ->
    {error, invalid_signature}.

validate_signed_info_algorithms(References, SignatureMethodUris) ->
    maybe
        {ok, ?DSIG_C14N11_ALGO_URI} ?= maps:find(c14n_algorithm, References),
        {ok, SignatureMethodUri} ?= maps:find(signature_algorithm, References),
        true ?= lists:member(SignatureMethodUri, SignatureMethodUris),
        ok
    else
        _ ->
            {error, invalid_signature}
    end.

validate_document_reference(Reference, DigestMethodUri) ->
    maybe
        {ok, ""} ?= maps:find(uri, Reference),
        {ok, [?DSIG_ENVELOPED_SIGNATURE_TRANSFORM_URI]} ?= maps:find(transforms, Reference),
        {ok, DigestMethodUri} ?= maps:find(digest_method, Reference),
        ok
    else
        _ ->
            {error, invalid_signature}
    end.

validate_signed_properties_reference(Reference, DigestMethodUri) ->
    maybe
        {ok, "#" ++ ?SIGNED_PROPERTIES_ID} ?= maps:find(uri, Reference),
        {ok, ?XADES_SIGNED_PROPERTIES_TYPE_URI} ?= maps:find(type, Reference),
        {ok, []} ?= maps:find(transforms, Reference),
        {ok, DigestMethodUri} ?= maps:find(digest_method, Reference),
        ok
    else
        _ ->
            {error, invalid_signature}
    end.

attr_value(Key, Attrs) ->
    case [Value || {AttrKey, Value} <- Attrs, AttrKey =:= Key] of
        [Value] ->
            {ok, Value};
        _ ->
            {error, invalid_signature}
    end.

attr_value_or_undefined(Key, Attrs) ->
    case [Value || {AttrKey, Value} <- Attrs, AttrKey =:= Key] of
        [Value] ->
            Value;
        [] ->
            undefined;
        _ ->
            undefined
    end.

decode_base64_binary(Value) when is_binary(Value) ->
    decode_base64_binary_value(Value);
decode_base64_binary(Value) when is_list(Value) ->
    case signerl_utils:is_byte_list(Value) of
        true ->
            decode_base64_binary_value(list_to_binary(Value));
        false ->
            {error, invalid_signature}
    end;
decode_base64_binary(_) ->
    {error, invalid_signature}.

decode_base64_binary_value(<<>>) ->
    {error, invalid_signature};
decode_base64_binary_value(Value) ->
    try
        {ok, base64:decode(Value)}
    catch
        _:_ ->
            {error, invalid_signature}
    end.

digest_method_uri(sha256) ->
    {ok, ?DSIG_DIGEST_SHA256_URI};
digest_method_uri(_) ->
    {error, invalid_signature}.
