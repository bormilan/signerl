-module(signerl_verify).
-feature(maybe_expr, enable).
-include("signerl_dsig.hrl").

-export([extract_signature_data/1, verify_reference_digests/2, c14n_mode/1]).

-spec extract_signature_data(Message) -> Result when
    Message :: xmlan:simplified_xml(),
    Result :: {ok, map()} | {error, atom()}.
extract_signature_data({Tag, Attrs, Content}) ->
    ParentNs = xmlan:namespace_context(Attrs, #{}),
    {SignatureElements, UnsignedContent} = lists:partition(
        fun(Element) -> signerl_dsig_utils:is_signature_element(Element, ParentNs) end, Content
    ),
    case SignatureElements of
        [SignatureElement] ->
            decode_signature_data(
                xmlan:with_namespace_context(SignatureElement, ParentNs),
                {Tag, Attrs, UnsignedContent}
            );
        _ ->
            {error, missing_signature}
    end.

-spec verify_reference_digests(SignatureData, HashAlgorithm) -> Result when
    SignatureData :: map(),
    HashAlgorithm :: atom(),
    Result :: true | false | {error, atom()}.
verify_reference_digests(
    #{
        unsigned_message := UnsignedMessage,
        signature_element := SignatureElement,
        signed_properties := SignedProperties,
        references := #{
            document := #{digest_value := DocumentDigestValue} = DocumentReference,
            signed_properties := #{
                digest_value := SignedPropertiesDigestValue
            } = SignedPropertiesReference
        } = References,
        key_info := KeyInfo
    },
    HashAlgorithm
) ->
    maybe
        {ok, DigestMethodUri} ?= digest_method_uri(HashAlgorithm),
        SignatureMethodUris = [?DSIG_SIG_RSA_SHA256_URI, ?DSIG_SIG_ECDSA_SHA256_URI],
        ok ?= validate_signed_info_algorithms(References, SignatureMethodUris),
        ok ?= validate_document_reference(DocumentReference, DigestMethodUri),
        ok ?= validate_signed_properties_reference(SignedPropertiesReference, DigestMethodUri),
        ok ?= verify_cert_digest(SignedProperties, KeyInfo, HashAlgorithm),
        {ok, SignedPropertiesElement} ?=
            signerl_xades_xml:find_signed_properties_element(SignatureElement),
        DocumentPayload = xmlan_c14n:canonicalize(
            signerl_dsig_utils:remove_signature_elements(UnsignedMessage)
        ),
        SignedPropertiesPayload = xmlan_c14n:canonicalize(SignedPropertiesElement),
        DocumentDigest = crypto:hash(HashAlgorithm, DocumentPayload),
        SignedPropertiesDigest = crypto:hash(HashAlgorithm, SignedPropertiesPayload),
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
        {error, cert_digest_mismatch} ->
            {error, cert_digest_mismatch};
        _ ->
            {error, invalid_signature_structure}
    end;
verify_reference_digests(_, _) ->
    {error, invalid_signature_structure}.

decode_signature_data(SignatureElement, UnsignedMessage) ->
    maybe
        {ok, SignatureBytes} ?= signature_value(SignatureElement),
        {ok, SignedProperties} ?= signerl_signed_properties:extract(SignatureElement),
        {ok, SignedInfoElement} ?= signed_info_element(SignatureElement),
        {ok, References} ?= signed_info_references(SignedInfoElement),
        KeyInfo = extract_key_info(SignatureElement),
        {ok, #{
            signature_bytes => SignatureBytes,
            unsigned_message => UnsignedMessage,
            signed_properties => SignedProperties,
            signature_element => SignatureElement,
            signed_info_element => SignedInfoElement,
            references => References,
            key_info => KeyInfo
        }}
    end.

signature_value(SignatureElement) ->
    decode_signature_value(
        xmlan:find_path([?DSIG_NAME(<<"SignatureValue">>)], SignatureElement)
    ).

decode_signature_value({ok, {_, _, [SignatureValue]}}) ->
    decode_base64_binary(SignatureValue);
decode_signature_value({ok, {_, _, _}}) ->
    {error, missing_signature_value};
decode_signature_value({error, not_found}) ->
    {error, missing_signature_value}.

signed_info_element(SignatureElement) ->
    case xmlan:find_path([?DSIG_NAME(<<"SignedInfo">>)], SignatureElement) of
        {ok, {_, _, _} = SignedInfoElement} ->
            {ok, SignedInfoElement};
        _ ->
            {error, missing_signed_info}
    end.

signed_info_references(SignedInfoElement) ->
    maybe
        {ok, {_, C14NAttrs, _}} ?=
            xmlan:find_path([?DSIG_NAME(<<"CanonicalizationMethod">>)], SignedInfoElement),
        {ok, C14NAlgorithm} ?= xmlan:attr_value(<<"Algorithm">>, C14NAttrs),
        {ok, {_, SignatureMethodAttrs, _}} ?=
            xmlan:find_path([?DSIG_NAME(<<"SignatureMethod">>)], SignedInfoElement),
        {ok, SignatureMethodAlgorithm} ?=
            xmlan:attr_value(<<"Algorithm">>, SignatureMethodAttrs),
        ReferenceElements = xmlan:find_children(
            ?DSIG_NAME(<<"Reference">>), SignedInfoElement
        ),
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
            {error, invalid_signed_info}
    end.

decode_reference_elements(ReferenceElements) ->
    DocumentReferences =
        [
            Reference
         || Reference = {_, Attrs, _} <- ReferenceElements,
            xmlan:attr_value(<<"URI">>, Attrs) =:= {ok, ""}
        ],
    SignedPropertiesReferences =
        [
            Reference
         || Reference = {_, Attrs, _} <- ReferenceElements,
            xmlan:attr_value(<<"URI">>, Attrs) =:= {ok, "#" ++ ?SIGNED_PROPERTIES_ID}
        ],
    case {DocumentReferences, SignedPropertiesReferences} of
        {[DocumentReferenceElement], [SignedPropertiesReferenceElement]} ->
            maybe
                {ok, DocumentReference} ?= decode_reference(DocumentReferenceElement),
                {ok, SignedPropertiesReference} ?=
                    decode_reference(SignedPropertiesReferenceElement),
                {ok, DocumentReference, SignedPropertiesReference}
            end;
        _ ->
            {error, invalid_reference}
    end.

decode_reference({_, Attrs, _} = ReferenceElement) ->
    maybe
        {ok, Uri} ?= xmlan:attr_value(<<"URI">>, Attrs),
        {ok, TransformUris} ?= transform_uris(ReferenceElement),
        {ok, DigestMethodElement} ?=
            xmlan:find_path([?DSIG_NAME(<<"DigestMethod">>)], ReferenceElement),
        {ok, DigestMethodUri} ?=
            xmlan:attr_value(<<"Algorithm">>, element(2, DigestMethodElement)),
        {ok, DigestValueElement} ?=
            xmlan:find_path([?DSIG_NAME(<<"DigestValue">>)], ReferenceElement),
        {ok, DigestValueText} ?= xmlan:single_text(DigestValueElement),
        {ok, DigestValue} ?= decode_base64_binary(DigestValueText),
        {ok, #{
            uri => Uri,
            type => xmlan:attr_value_or_undefined(<<"Type">>, Attrs),
            transforms => TransformUris,
            digest_method => DigestMethodUri,
            digest_value => DigestValue
        }}
    else
        _ ->
            {error, invalid_reference}
    end.

transform_uris(ReferenceElement) ->
    case xmlan:find_path([?DSIG_NAME(<<"Transforms">>)], ReferenceElement) of
        {ok, {_, Attrs, TransformElements}} ->
            decode_transform_uris(TransformElements, xmlan:namespace_context(Attrs, #{}), []);
        {error, not_found} ->
            {ok, []}
    end.

decode_transform_uris([], _ParentNs, Acc) ->
    {ok, lists:reverse(Acc)};
decode_transform_uris([{Name, Attrs, []} = Element | Rest], ParentNs, Acc) when is_binary(Name) ->
    case xmlan:expanded_name(Element, ParentNs) of
        ?DSIG_NAME(<<"Transform">>) ->
            case xmlan:attr_value(<<"Algorithm">>, Attrs) of
                {ok, Algorithm} -> decode_transform_uris(Rest, ParentNs, [Algorithm | Acc]);
                {error, _} = Err -> Err
            end;
        _ ->
            {error, invalid_reference}
    end;
decode_transform_uris([_Other | _Rest], _ParentNs, _Acc) ->
    {error, invalid_reference}.

validate_signed_info_algorithms(References, SignatureMethodUris) ->
    maybe
        {ok, C14NAlgorithm} ?= maps:find(c14n_algorithm, References),
        true ?= is_supported_c14n(C14NAlgorithm),
        {ok, SignatureMethodUri} ?= maps:find(signature_algorithm, References),
        true ?= lists:member(SignatureMethodUri, SignatureMethodUris),
        ok
    else
        _ ->
            {error, unsupported_algorithm}
    end.

is_supported_c14n(?DSIG_C14N11_ALGO_URI) -> true;
is_supported_c14n(?DSIG_EXC_C14N_ALGO_URI) -> true;
is_supported_c14n(_) -> false.

validate_document_reference(Reference, DigestMethodUri) ->
    maybe
        {ok, ""} ?= maps:find(uri, Reference),
        {ok, [?DSIG_ENVELOPED_SIGNATURE_TRANSFORM_URI]} ?= maps:find(transforms, Reference),
        {ok, DigestMethodUri} ?= maps:find(digest_method, Reference),
        ok
    else
        _ ->
            {error, invalid_reference}
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
            {error, invalid_reference}
    end.

decode_base64_binary(Value) when is_binary(Value) ->
    decode_base64_binary_value(Value);
decode_base64_binary(Value) when is_list(Value) ->
    case signerl_utils:is_byte_list(Value) of
        true ->
            decode_base64_binary_value(list_to_binary(Value));
        false ->
            {error, invalid_base64}
    end;
decode_base64_binary(_) ->
    {error, invalid_base64}.

decode_base64_binary_value(<<>>) ->
    {error, invalid_base64};
decode_base64_binary_value(Value) ->
    try
        {ok, base64:decode(Value)}
    catch
        _:_ ->
            {error, invalid_base64}
    end.

digest_method_uri(sha256) ->
    {ok, ?DSIG_DIGEST_SHA256_URI};
digest_method_uri(_) ->
    {error, unsupported_hash}.

-spec c14n_mode(map()) -> xmlan_c14n:c14n_mode().
c14n_mode(#{references := #{c14n_algorithm := ?DSIG_EXC_C14N_ALGO_URI}}) ->
    exc_c14n;
c14n_mode(_) ->
    c14n11.

extract_key_info(SignatureElement) ->
    case xmlan:find_path([?DSIG_NAME(<<"KeyInfo">>)], SignatureElement) of
        {ok, KeyInfoElement} ->
            extract_x509_certificate(KeyInfoElement);
        {error, not_found} ->
            undefined
    end.

extract_x509_certificate(KeyInfoElement) ->
    maybe
        {ok, {_, _, [CertB64]}} ?=
            xmlan:find_path(
                [?DSIG_NAME(<<"X509Data">>), ?DSIG_NAME(<<"X509Certificate">>)], KeyInfoElement
            ),
        true ?= is_list(CertB64),
        {ok, CertDer} ?= decode_base64_binary(list_to_binary(CertB64)),
        #{x509_certificate => CertDer}
    else
        _ -> undefined
    end.

verify_cert_digest(
    #{
        signing_certificate_v2 := #{
            digest_method := DigestMethodUri, digest_value := ExpectedDigest
        }
    },
    #{x509_certificate := CertDer},
    HashAlgorithm
) ->
    case digest_method_uri(HashAlgorithm) of
        {ok, DigestMethodUri} ->
            ActualDigest = crypto:hash(HashAlgorithm, CertDer),
            case ActualDigest =:= ExpectedDigest of
                true -> ok;
                false -> {error, cert_digest_mismatch}
            end;
        _ ->
            {error, cert_digest_mismatch}
    end;
verify_cert_digest(#{signing_certificate_v2 := _}, undefined, _HashAlgorithm) ->
    ok;
verify_cert_digest(_SignedProperties, _KeyInfo, _HashAlgorithm) ->
    ok.
