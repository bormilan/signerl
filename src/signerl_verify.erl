-module(signerl_verify).
-feature(maybe_expr, enable).
-include("signerl_dsig.hrl").

-export([extract_signature_data/1, verify_reference_digests/2, c14n_mode/1, verify_signature/3]).

-spec extract_signature_data(Message) -> Result when
    Message :: xmlan:simplified_xml(),
    Result :: {ok, map()} | {error, atom()}.
extract_signature_data({Tag, Attrs, Content} = Message) ->
    ParentNs = xmlan:namespace_context(Attrs, #{}),
    {SignatureElements, UnsignedContent} = lists:partition(
        fun(Element) -> signerl_dsig_utils:is_signature_element(Element, ParentNs) end, Content
    ),
    {Count, Ids} = signerl_dsig_utils:signature_inventory(Message),
    case {SignatureElements, Count} of
        {[SignatureElement], 1} ->
            decode_signature_data(
                xmlan:with_namespace_context(SignatureElement, ParentNs),
                {Tag, Attrs, UnsignedContent},
                Ids
            );
        {[], 0} ->
            {error, missing_signature};
        _ ->
            {error, invalid_signature_structure}
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
        key_info := KeyInfo,
        id_counts := Ids
    },
    HashAlgorithm
) ->
    maybe
        {ok, DigestMethodUri} ?= digest_method_uri(HashAlgorithm),
        SignatureMethodUris = [?DSIG_SIG_RSA_SHA256_URI, ?DSIG_SIG_ECDSA_SHA256_URI],
        ok ?= validate_signed_info_algorithms(References, SignatureMethodUris),
        ok ?= validate_reference_pair(DocumentReference, SignedPropertiesReference),
        {ok, SignedPropertiesElement} ?=
            resolve_signed_properties(SignatureElement, SignedPropertiesReference, Ids),
        ok ?= validate_document_reference(DocumentReference, DigestMethodUri),
        ok ?= validate_signed_properties_reference(SignedPropertiesReference, DigestMethodUri),
        ok ?= verify_cert_digest(SignedProperties, KeyInfo, HashAlgorithm),
        DocumentPayload = xmlan_c14n:canonicalize(UnsignedMessage),
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
        {error, unsupported_hash} ->
            {error, unsupported_hash};
        {error, cert_digest_mismatch} ->
            {error, cert_digest_mismatch};
        _ ->
            {error, invalid_signature_structure}
    end;
verify_reference_digests(_, _) ->
    {error, invalid_signature_structure}.

decode_signature_data(SignatureElement, UnsignedMessage, Ids) ->
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
            key_info => KeyInfo,
            id_counts => Ids
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
        {ok, C14NAlgorithm} ?= method_algorithm(<<"CanonicalizationMethod">>, SignedInfoElement),
        {ok, SignatureMethodAlgorithm} ?=
            method_algorithm(<<"SignatureMethod">>, SignedInfoElement),
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

decode_reference_elements([_, _] = ReferenceElements) ->
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
            {ok, [$# | Id]} <- [xmlan:attr_value(<<"URI">>, Attrs)],
            Id =/= []
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
    end;
decode_reference_elements(_) ->
    {error, invalid_reference}.

decode_reference({_, Attrs, _} = ReferenceElement) ->
    maybe
        {ok, Uri} ?= xmlan:attr_value(<<"URI">>, Attrs),
        {ok, TransformUris, TransformsPresent} ?= transform_uris(ReferenceElement),
        {ok, DigestMethodUri} ?= method_algorithm(<<"DigestMethod">>, ReferenceElement),
        {ok, DigestValueElement} ?=
            xmlan:find_path([?DSIG_NAME(<<"DigestValue">>)], ReferenceElement),
        {ok, DigestValueText} ?= xmlan:single_text(DigestValueElement),
        {ok, DigestValue} ?= decode_base64_binary(DigestValueText),
        {ok, #{
            uri => Uri,
            type => xmlan:attr_value_or_undefined(<<"Type">>, Attrs),
            transforms => TransformUris,
            transforms_present => TransformsPresent,
            digest_method => DigestMethodUri,
            digest_value => DigestValue
        }}
    else
        _ ->
            {error, invalid_reference}
    end.

transform_uris(ReferenceElement) ->
    case xmlan:find_children(?DSIG_NAME(<<"Transforms">>), ReferenceElement) of
        [{_, Attrs, TransformElements}] ->
            maybe
                true ?= only_attributes([], Attrs),
                {ok, Uris} ?=
                    decode_transform_uris(
                        TransformElements,
                        xmlan:namespace_context(Attrs, #{}),
                        []
                    ),
                {ok, Uris, true}
            else
                _ -> {error, invalid_reference}
            end;
        [] ->
            {ok, [], false};
        _ ->
            {error, invalid_reference}
    end.

decode_transform_uris([], _ParentNs, Acc) ->
    {ok, lists:reverse(Acc)};
decode_transform_uris([{Name, Attrs, Children} = Element | Rest], ParentNs, Acc) when
    is_binary(Name)
->
    maybe
        ?DSIG_NAME(<<"Transform">>) ?= xmlan:expanded_name(Element, ParentNs),
        true ?= only_attributes([<<"Algorithm">>], Attrs),
        true ?= whitespace_only(Children),
        {ok, Algorithm} ?= xmlan:attr_value(<<"Algorithm">>, Attrs),
        decode_transform_uris(Rest, ParentNs, [Algorithm | Acc])
    else
        _ -> {error, invalid_reference}
    end;
decode_transform_uris([Text | Rest], ParentNs, Acc) ->
    case whitespace_only([Text]) of
        true -> decode_transform_uris(Rest, ParentNs, Acc);
        false -> {error, invalid_reference}
    end.

method_algorithm(Name, Parent) ->
    maybe
        {ok, {_, Attrs, Content}} ?= xmlan:find_path([?DSIG_NAME(Name)], Parent),
        true ?= only_attributes([<<"Algorithm">>], Attrs),
        true ?= whitespace_only(Content),
        xmlan:attr_value(<<"Algorithm">>, Attrs)
    else
        _ -> {error, unsupported_algorithm}
    end.

only_attributes(Allowed, Attrs) ->
    lists:all(
        fun
            ({<<"xmlns">>, _}) -> true;
            ({<<"xmlns:", _/binary>>, _}) -> true;
            ({Name, _}) -> lists:member(Name, Allowed)
        end,
        Attrs
    ).

whitespace_only(Content) ->
    lists:all(
        fun
            (Text) when is_list(Text); is_binary(Text) ->
                lists:all(
                    fun(Char) -> lists:member(Char, " \t\r\n") end,
                    unicode:characters_to_list(Text)
                );
            (_) ->
                false
        end,
        Content
    ).

validate_reference_pair(
    #{transforms := [?DSIG_ENVELOPED_SIGNATURE_TRANSFORM_URI, ?DSIG_C14N11_ALGO_URI]},
    #{transforms := [?DSIG_C14N11_ALGO_URI]}
) ->
    ok;
validate_reference_pair(
    #{transforms := [?DSIG_ENVELOPED_SIGNATURE_TRANSFORM_URI]},
    #{transforms := [], transforms_present := false}
) ->
    ok;
validate_reference_pair(_, _) ->
    {error, invalid_reference}.

resolve_signed_properties({_, SignatureAttrs, _} = Signature, #{uri := Uri}, Ids) ->
    maybe
        true ?= lists:all(fun(Count) -> Count =:= 1 end, maps:values(Ids)),
        {ok, SignatureId} ?= xmlan:attr_value(<<"Id">>, SignatureAttrs),
        true ?= SignatureId =/= [],
        1 ?= maps:get(SignatureId, Ids, 0),
        {ok, {_, QualifyingAttrs, _} = Qualifying} ?=
            xmlan:find_path(
                [?DSIG_NAME(<<"Object">>), ?XADES_NAME(<<"QualifyingProperties">>)], Signature
            ),
        {ok, "#" ++ SignatureId} ?= xmlan:attr_value(<<"Target">>, QualifyingAttrs),
        {ok, {_, PropertiesAttrs, _} = Properties} ?=
            xmlan:find_path(
                [?XADES_NAME(<<"SignedProperties">>)], Qualifying
            ),
        {ok, PropertiesId} ?= xmlan:attr_value(<<"Id">>, PropertiesAttrs),
        true ?= PropertiesId =/= [],
        1 ?= maps:get(PropertiesId, Ids, 0),
        true ?= Uri =:= "#" ++ PropertiesId,
        {ok, Properties}
    else
        _ -> {error, invalid_reference}
    end.

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
        {ok, undefined} ?= maps:find(type, Reference),
        {ok, DigestMethodUri} ?= maps:find(digest_method, Reference),
        ok
    else
        _ ->
            {error, invalid_reference}
    end.

validate_signed_properties_reference(Reference, DigestMethodUri) ->
    maybe
        {ok, ?XADES_SIGNED_PROPERTIES_TYPE_URI} ?= maps:find(type, Reference),
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

-spec verify_signature(map(), atom(), public_key:public_key() | public_key:private_key()) ->
    boolean() | {error, invalid_signature_structure}.
verify_signature(
    #{
        references := #{signature_algorithm := Algorithm},
        signed_info_element := SignedInfo,
        signature_bytes := SignatureBytes
    } = Data,
    Hash,
    Key
) ->
    case verification_method_uri(Key) of
        Algorithm ->
            Bytes = xmlan_c14n:canonicalize(SignedInfo, c14n_mode(Data)),
            public_key:verify(Bytes, Hash, SignatureBytes, Key);
        _ ->
            {error, invalid_signature_structure}
    end.

verification_method_uri({'RSAPublicKey', _, _}) ->
    ?DSIG_SIG_RSA_SHA256_URI;
verification_method_uri(Key) when is_tuple(Key), element(1, Key) =:= 'RSAPrivateKey' ->
    ?DSIG_SIG_RSA_SHA256_URI;
verification_method_uri({{'ECPoint', _}, _}) ->
    ?DSIG_SIG_ECDSA_SHA256_URI.

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
