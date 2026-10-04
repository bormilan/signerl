-module(signerl_verify_test).

-include_lib("eunit/include/eunit.hrl").
-include("signerl_dsig.hrl").

signed_info_test_() ->
    {setup, fun signature_fixture/0, fun signed_info_cases/1}.

signed_info_cases(Config) ->
    [
        {"signature_reconstruction_preserves_valid_baseline",
            ?_test(signature_reconstruction_preserves_valid_baseline(Config))},
        {"verify_returns_error_with_non_text_signature_value_in_signedinfo",
            ?_test(verify_returns_error_with_non_text_signature_value_in_signedinfo(Config))},
        {"verify_returns_error_with_non_byte_list_signature_value_in_signedinfo",
            ?_test(verify_returns_error_with_non_byte_list_signature_value_in_signedinfo(Config))},
        {"verify_returns_error_with_empty_binary_signature_value_in_signedinfo",
            ?_test(verify_returns_error_with_empty_binary_signature_value_in_signedinfo(Config))},
        {"verify_returns_error_without_signed_info",
            ?_test(verify_returns_error_without_signed_info(Config))},
        {"extract_signature_data_returns_error_with_missing_c14n",
            ?_test(extract_signature_data_returns_error_with_missing_c14n(Config))},
        {"verify_reference_digests_returns_error_with_invalid_c14n_algorithm",
            ?_test(verify_reference_digests_returns_error_with_invalid_c14n_algorithm(Config))},
        {"reference_digests_are_independent_of_signed_info_c14n",
            ?_test(reference_digests_are_independent_of_signed_info_c14n(Config))},
        {"verify_reference_digests_returns_error_with_invalid_signature_method_algorithm",
            ?_test(
                verify_reference_digests_returns_error_with_invalid_signature_method_algorithm(
                    Config
                )
            )},
        {"extract_signature_data_returns_error_with_missing_reference_uri",
            ?_test(extract_signature_data_returns_error_with_missing_reference_uri(Config))},
        {"extract_signature_data_returns_error_with_invalid_reference_payload",
            ?_test(extract_signature_data_returns_error_with_invalid_reference_payload(Config))},
        {"verify_reference_digests_returns_error_with_missing_document_transforms",
            ?_test(
                verify_reference_digests_returns_error_with_missing_document_transforms(
                    Config
                )
            )},
        {"verify_reference_digests_returns_error_with_invalid_document_transform_algorithm",
            ?_test(
                verify_reference_digests_returns_error_with_invalid_document_transform_algorithm(
                    Config
                )
            )},
        {"verify_reference_digests_returns_error_with_transform_without_algorithm",
            ?_test(
                verify_reference_digests_returns_error_with_transform_without_algorithm(
                    Config
                )
            )},
        {"verify_reference_digests_returns_error_with_invalid_transform_element",
            ?_test(verify_reference_digests_returns_error_with_invalid_transform_element(Config))},
        {"verify_rejects_duplicate_reference_attributes",
            ?_test(verify_rejects_duplicate_reference_attributes(Config))},
        {"verify_reference_digests_returns_error_with_missing_signed_properties_element",
            ?_test(
                verify_reference_digests_returns_error_with_missing_signed_properties_element(
                    Config
                )
            )},
        {"verify_reference_digests_returns_error_with_invalid_document_reference",
            ?_test(verify_reference_digests_returns_error_with_invalid_document_reference(Config))},
        {"verify_reference_digests_returns_error_with_invalid_signed_properties_reference",
            ?_test(
                verify_reference_digests_returns_error_with_invalid_signed_properties_reference(
                    Config
                )
            )},
        {"verify_reference_digests_returns_error_with_invalid_signature_data",
            ?_test(verify_reference_digests_returns_error_with_invalid_signature_data(Config))}
    ].

signature_reconstruction_preserves_valid_baseline(Config) ->
    SignatureData = proplists:get_value(signature_data, Config),
    ?assertEqual(true, signerl_verify:verify_reference_digests(SignatureData, sha256)),
    SignatureElement = maps:get(signature_element, SignatureData),
    Message = message_with_signature(SignatureData, SignatureElement),
    {ok, RebuiltData} = signerl_verify:extract_signature_data(Message),
    ?assertEqual(true, signerl_verify:verify_reference_digests(RebuiltData, sha256)).

verify_returns_error_with_non_text_signature_value_in_signedinfo(Config) ->
    SignatureData = validated_signature_data(Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = replace_signature_value(SignatureElement, [{'invalid', [], []}]),
    ?assertNotEqual(SignatureElement, BrokenSignature),
    Message = message_with_signature(SignatureData, BrokenSignature),
    ?assertEqual({error, invalid_base64}, signerl_verify:extract_signature_data(Message)).

verify_returns_error_with_non_byte_list_signature_value_in_signedinfo(Config) ->
    SignatureData = validated_signature_data(Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = replace_signature_value(SignatureElement, [[65, {invalid, [], []}]]),
    ?assertNotEqual(SignatureElement, BrokenSignature),
    Message = message_with_signature(SignatureData, BrokenSignature),
    ?assertEqual({error, invalid_base64}, signerl_verify:extract_signature_data(Message)).

verify_returns_error_with_empty_binary_signature_value_in_signedinfo(Config) ->
    SignatureData = validated_signature_data(Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = replace_signature_value(SignatureElement, [<<>>]),
    ?assertNotEqual(SignatureElement, BrokenSignature),
    Message = message_with_signature(SignatureData, BrokenSignature),
    ?assertEqual({error, invalid_base64}, signerl_verify:extract_signature_data(Message)).

verify_returns_error_without_signed_info(Config) ->
    SignatureData = validated_signature_data(Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = remove_signed_info_from_signature(SignatureElement),
    ?assertNotEqual(SignatureElement, BrokenSignature),
    Message = message_with_signature(SignatureData, BrokenSignature),
    ?assertEqual({error, missing_signed_info}, signerl_verify:extract_signature_data(Message)).

extract_signature_data_returns_error_with_missing_c14n(Config) ->
    SignatureData = validated_signature_data(Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = remove_c14n_from_signature(SignatureElement),
    ?assertNotEqual(SignatureElement, BrokenSignature),
    Message = message_with_signature(SignatureData, BrokenSignature),
    ?assertEqual({error, invalid_signed_info}, signerl_verify:extract_signature_data(Message)).

verify_reference_digests_returns_error_with_invalid_c14n_algorithm(Config) ->
    SignatureData = validated_signature_data(Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = replace_c14n_algorithm(SignatureElement, "invalid-c14n"),
    ?assertNotEqual(SignatureElement, BrokenSignature),
    Message = message_with_signature(SignatureData, BrokenSignature),
    {ok, BrokenData} = signerl_verify:extract_signature_data(Message),
    ?assertEqual(
        {error, invalid_signature_structure},
        signerl_verify:verify_reference_digests(BrokenData, sha256)
    ).

reference_digests_are_independent_of_signed_info_c14n(Config) ->
    SignatureData = validated_signature_data(Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    ExcSignature = replace_c14n_algorithm(SignatureElement, ?DSIG_EXC_C14N_ALGO_URI),
    ?assertNotEqual(SignatureElement, ExcSignature),
    Message = message_with_signature(SignatureData, ExcSignature),
    {ok, ExcData} = signerl_verify:extract_signature_data(Message),
    OriginalReferences = maps:get(references, SignatureData),
    ExcReferences = maps:get(references, ExcData),
    ?assertEqual(
        maps:remove(c14n_algorithm, OriginalReferences),
        maps:remove(c14n_algorithm, ExcReferences)
    ),
    ?assertEqual(true, signerl_verify:verify_reference_digests(ExcData, sha256)),
    %% SignedInfo changed, so the unchanged SignatureValue must no longer verify.
    Modified = signerl_xml:export([], Message),
    ?assertEqual(
        false, signerl:verify(Modified, sha256, proplists:get_value(rsa_public_key, Config))
    ).

verify_reference_digests_returns_error_with_invalid_signature_method_algorithm(Config) ->
    SignatureData = validated_signature_data(Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = replace_signature_method_algorithm(
        SignatureElement, "invalid-signature-method"
    ),
    ?assertNotEqual(SignatureElement, BrokenSignature),
    Message = message_with_signature(SignatureData, BrokenSignature),
    {ok, BrokenData} = signerl_verify:extract_signature_data(Message),
    ?assertEqual(
        {error, invalid_signature_structure},
        signerl_verify:verify_reference_digests(BrokenData, sha256)
    ).

extract_signature_data_returns_error_with_missing_reference_uri(Config) ->
    SignatureData = validated_signature_data(Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = remove_document_reference_uri(SignatureElement),
    ?assertNotEqual(SignatureElement, BrokenSignature),
    Message = message_with_signature(SignatureData, BrokenSignature),
    ?assertEqual({error, invalid_signed_info}, signerl_verify:extract_signature_data(Message)).

extract_signature_data_returns_error_with_invalid_reference_payload(Config) ->
    SignatureData = validated_signature_data(Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = remove_document_reference_digest_value(SignatureElement),
    ?assertNotEqual(SignatureElement, BrokenSignature),
    Message = message_with_signature(SignatureData, BrokenSignature),
    ?assertEqual({error, invalid_signed_info}, signerl_verify:extract_signature_data(Message)).

verify_reference_digests_returns_error_with_missing_document_transforms(Config) ->
    SignatureData = validated_signature_data(Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = remove_document_reference_transforms(SignatureElement),
    ?assertNotEqual(SignatureElement, BrokenSignature),
    Message = message_with_signature(SignatureData, BrokenSignature),
    {ok, BrokenData} = signerl_verify:extract_signature_data(Message),
    ?assertEqual(
        {error, invalid_signature_structure},
        signerl_verify:verify_reference_digests(BrokenData, sha256)
    ).

verify_reference_digests_returns_error_with_invalid_document_transform_algorithm(Config) ->
    SignatureData = validated_signature_data(Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature =
        replace_document_reference_transform_algorithm(SignatureElement, "invalid-transform"),
    ?assertNotEqual(SignatureElement, BrokenSignature),
    Message = message_with_signature(SignatureData, BrokenSignature),
    {ok, BrokenData} = signerl_verify:extract_signature_data(Message),
    ?assertEqual(
        {error, invalid_signature_structure},
        signerl_verify:verify_reference_digests(BrokenData, sha256)
    ).

verify_reference_digests_returns_error_with_transform_without_algorithm(Config) ->
    SignatureData = validated_signature_data(Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = replace_document_transforms(SignatureElement, [{'ds:Transform', [], []}]),
    ?assertNotEqual(SignatureElement, BrokenSignature),
    Message = message_with_signature(SignatureData, BrokenSignature),
    ?assertEqual({error, invalid_signed_info}, signerl_verify:extract_signature_data(Message)).

verify_reference_digests_returns_error_with_invalid_transform_element(Config) ->
    SignatureData = validated_signature_data(Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature =
        replace_document_transforms(SignatureElement, [{'ds:InvalidTransform', [], []}]),
    ?assertNotEqual(SignatureElement, BrokenSignature),
    Message = message_with_signature(SignatureData, BrokenSignature),
    ?assertEqual({error, invalid_signed_info}, signerl_verify:extract_signature_data(Message)).

verify_rejects_duplicate_reference_attributes(Config) ->
    SignatureData = validated_signature_data(Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    Message = message_with_signature(SignatureData, SignatureElement),
    SignedMessage = signerl_xml:export([], Message),
    %% Duplicate attributes are invalid XML; exercise the parser through the public API.
    Duplicate = test_helpers:replace_once(
        SignedMessage, <<"Type=">>, <<"Type=\"duplicate\" Type=">>
    ),
    ?assertEqual(
        {error, invalid_xml},
        signerl:verify(Duplicate, sha256, proplists:get_value(rsa_public_key, Config))
    ).

verify_reference_digests_returns_error_with_missing_signed_properties_element(Config) ->
    SignatureData = validated_signature_data(Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = remove_signed_properties_from_signature(SignatureElement),
    ?assertNotEqual(SignatureElement, BrokenSignature),
    BrokenData = maps:put(signature_element, BrokenSignature, SignatureData),
    ?assertEqual(
        {error, invalid_signature_structure},
        signerl_verify:verify_reference_digests(BrokenData, sha256)
    ).

verify_reference_digests_returns_error_with_invalid_document_reference(Config) ->
    SignatureData = validated_signature_data(Config),
    References = maps:get(references, SignatureData),
    DocumentReference = maps:get(document, References),
    BrokenDocumentReference = maps:put(uri, "invalid", DocumentReference),
    BrokenReferences = maps:put(document, BrokenDocumentReference, References),
    ?assertNotEqual(References, BrokenReferences),
    BrokenData = maps:put(references, BrokenReferences, SignatureData),
    ?assertEqual(
        {error, invalid_signature_structure},
        signerl_verify:verify_reference_digests(BrokenData, sha256)
    ).

verify_reference_digests_returns_error_with_invalid_signed_properties_reference(Config) ->
    SignatureData = validated_signature_data(Config),
    References = maps:get(references, SignatureData),
    SignedPropertiesReference = maps:get(signed_properties, References),
    BrokenSignedPropertiesReference = maps:put(type, undefined, SignedPropertiesReference),
    BrokenReferences = maps:put(signed_properties, BrokenSignedPropertiesReference, References),
    ?assertNotEqual(References, BrokenReferences),
    BrokenData = maps:put(references, BrokenReferences, SignatureData),
    ?assertEqual(
        {error, invalid_signature_structure},
        signerl_verify:verify_reference_digests(BrokenData, sha256)
    ).

verify_reference_digests_returns_error_with_invalid_signature_data(_Config) ->
    ?assertEqual(
        {error, invalid_signature_structure}, signerl_verify:verify_reference_digests(#{}, sha256)
    ).

extract_signature_returns_error_without_signature_element_direct_test() ->
    Message = signerl_xml:parse_file("test/examples/base/books.xml"),
    ?assertEqual({error, missing_signature}, signerl_verify:extract_signature_data(Message)).

c14n_mode_returns_exc_for_exc_c14n_algorithm_test() ->
    SigData = #{references => #{c14n_algorithm => "http://www.w3.org/2001/10/xml-exc-c14n#"}},
    ?assertEqual(exc_c14n, signerl_verify:c14n_mode(SigData)),
    SigDataC14N11 = #{references => #{c14n_algorithm => "http://www.w3.org/2006/12/xml-c14n11"}},
    ?assertEqual(c14n11, signerl_verify:c14n_mode(SigDataC14N11)).

extract_x509_certificate_returns_undefined_for_invalid_cert_test() ->
    %% Sign a message with certificate, then corrupt the cert to test error paths.
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),
    RsaKey = signerl_cert_helpers:signer_rsa_key(),
    RsaCertDer = test_helpers:cert_der(signerl_cert_helpers:signer_rsa_cert_path()),
    SignedMessage = signerl:sign(RawMessage, sha256, RsaKey, RsaCertDer),
    PublicKey = test_helpers:rsa_public_key_from_cert(
        signerl_cert_helpers:signer_rsa_cert_path()
    ),
    Parsed = test_helpers:parse_verified_message(SignedMessage, PublicKey),
    {ok, #{key_info := #{x509_certificate := RsaCertDer}}} =
        signerl_verify:extract_signature_data(Parsed),
    %% Test 1: Corrupt cert to invalid structure (multiple children → _ catch-all)
    CorruptedStructure = corrupt_x509_certificate(Parsed, [{'invalid', [], []}, {'extra', [], []}]),
    ?assertNotEqual(Parsed, CorruptedStructure),
    {ok, ParsedStructure} = signerl_xml:parse_binary(signerl_xml:export([], CorruptedStructure)),
    {ok, #{key_info := KeyInfo1}} = signerl_verify:extract_signature_data(ParsedStructure),
    ?assertEqual(undefined, KeyInfo1),
    %% Test 2: Corrupt cert to invalid base64 (single list child → decode error)
    CorruptedBase64 = corrupt_x509_certificate(Parsed, ["!!!not-base64!!!"]),
    ?assertNotEqual(Parsed, CorruptedBase64),
    {ok, ParsedBase64} = signerl_xml:parse_binary(signerl_xml:export([], CorruptedBase64)),
    {ok, #{key_info := KeyInfo2}} = signerl_verify:extract_signature_data(ParsedBase64),
    ?assertEqual(undefined, KeyInfo2).

%% Fixture setup and mutation helpers

signature_fixture() ->
    SignatureData = compute_valid_signature_data(),
    PublicKey = test_helpers:rsa_public_key_from_cert(
        signerl_cert_helpers:signer_rsa_cert_path()
    ),
    [{signature_data, SignatureData}, {rsa_public_key, PublicKey}].

validated_signature_data(Config) ->
    SignatureData = proplists:get_value(signature_data, Config),
    ?assertEqual(true, signerl_verify:verify_reference_digests(SignatureData, sha256)),
    SignatureElement = maps:get(signature_element, SignatureData),
    Message = message_with_signature(SignatureData, SignatureElement),
    test_helpers:parse_verified_message(
        signerl_xml:export([], Message), proplists:get_value(rsa_public_key, Config)
    ),
    SignatureData.

compute_valid_signature_data() ->
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),
    Key = signerl_cert_helpers:signer_rsa_key(),
    SignedMessage = signerl:sign(RawMessage, sha256, Key),
    PublicKey = test_helpers:rsa_public_key_from_cert(
        signerl_cert_helpers:signer_rsa_cert_path()
    ),
    ParsedSignedMessage = test_helpers:parse_verified_message(SignedMessage, PublicKey),
    {ok, SignatureData} = signerl_verify:extract_signature_data(ParsedSignedMessage),
    SignatureData.

message_with_signature(#{unsigned_message := Message}, SignatureElement) ->
    signerl_xml:add_new_element(SignatureElement, Message).

remove_c14n_from_signature(
    {'ds:Signature', Attrs, [SignedInfo, SignatureValue, SignatureObject]}
) ->
    {'ds:SignedInfo', SignedInfoAttrs, SignedInfoContent} = SignedInfo,
    FilteredSignedInfoContent =
        [
            Element
         || Element = {Tag, _, _} <- SignedInfoContent, Tag =/= 'ds:CanonicalizationMethod'
        ],
    {'ds:Signature', Attrs, [
        {'ds:SignedInfo', SignedInfoAttrs, FilteredSignedInfoContent},
        SignatureValue,
        SignatureObject
    ]}.

replace_c14n_algorithm(
    {'ds:Signature', Attrs, [SignedInfo, SignatureValue, SignatureObject]}, Algorithm
) ->
    {SignedInfoAttrs, _C14N, SignatureMethod, DocumentReference, SignedPropsReference} =
        signed_info_parts(SignedInfo),
    {'ds:Signature', Attrs, [
        {'ds:SignedInfo', SignedInfoAttrs, [
            {'ds:CanonicalizationMethod', [{'Algorithm', Algorithm}], []},
            SignatureMethod,
            DocumentReference,
            SignedPropsReference
        ]},
        SignatureValue,
        SignatureObject
    ]}.

replace_signature_method_algorithm(
    {'ds:Signature', Attrs, [SignedInfo, SignatureValue, SignatureObject]}, Algorithm
) ->
    {SignedInfoAttrs, C14N, _SignatureMethod, DocumentReference, SignedPropsReference} =
        signed_info_parts(SignedInfo),
    {'ds:Signature', Attrs, [
        {'ds:SignedInfo', SignedInfoAttrs, [
            C14N,
            {'ds:SignatureMethod', [{'Algorithm', Algorithm}], []},
            DocumentReference,
            SignedPropsReference
        ]},
        SignatureValue,
        SignatureObject
    ]}.

remove_document_reference_uri(
    {'ds:Signature', Attrs, [SignedInfo, SignatureValue, SignatureObject]}
) ->
    {SignedInfoAttrs, C14N, SignatureMethod, DocumentReference, SignedPropsReference} =
        signed_info_parts(SignedInfo),
    {'ds:Reference', _DocAttrs, DocContent} = DocumentReference,
    {'ds:Signature', Attrs, [
        {'ds:SignedInfo', SignedInfoAttrs, [
            C14N,
            SignatureMethod,
            {'ds:Reference', [], DocContent},
            SignedPropsReference
        ]},
        SignatureValue,
        SignatureObject
    ]}.

remove_document_reference_digest_value(Signature) ->
    with_document_reference(
        Signature,
        fun({'ds:Reference', DocAttrs, [Transforms, DigestMethod, _DigestValue]}) ->
            {'ds:Reference', DocAttrs, [Transforms, DigestMethod]}
        end
    ).

remove_document_reference_transforms(Signature) ->
    with_document_reference(
        Signature,
        fun({'ds:Reference', DocAttrs, [_Transforms, DigestMethod, DigestValue]}) ->
            {'ds:Reference', DocAttrs, [DigestMethod, DigestValue]}
        end
    ).

replace_document_reference_transform_algorithm(Signature, Algorithm) ->
    with_document_reference(
        Signature,
        fun({'ds:Reference', DocAttrs, [Transforms, DigestMethod, DigestValue]}) ->
            {'ds:Transforms', TransformsAttrs, [{'ds:Transform', _TransformAttrs, []}]} =
                Transforms,
            {'ds:Reference', DocAttrs, [
                {'ds:Transforms', TransformsAttrs, [
                    {'ds:Transform', [{'Algorithm', Algorithm}], []}
                ]},
                DigestMethod,
                DigestValue
            ]}
        end
    ).

replace_document_transforms(Signature, NewTransformElements) ->
    with_document_reference(
        Signature,
        fun({'ds:Reference', DocAttrs, [Transforms, DigestMethod, DigestValue]}) ->
            {'ds:Transforms', TransformsAttrs, _ExistingTransforms} = Transforms,
            {'ds:Reference', DocAttrs, [
                {'ds:Transforms', TransformsAttrs, NewTransformElements},
                DigestMethod,
                DigestValue
            ]}
        end
    ).

with_document_reference(
    {'ds:Signature', Attrs, [SignedInfo, SignatureValue, SignatureObject]}, UpdateFun
) ->
    {SignedInfoAttrs, C14N, SignatureMethod, DocumentReference, SignedPropsReference} =
        signed_info_parts(SignedInfo),
    UpdatedDocumentReference = UpdateFun(DocumentReference),
    {'ds:Signature', Attrs, [
        {'ds:SignedInfo', SignedInfoAttrs, [
            C14N,
            SignatureMethod,
            UpdatedDocumentReference,
            SignedPropsReference
        ]},
        SignatureValue,
        SignatureObject
    ]}.

remove_signed_properties_from_signature(
    {'ds:Signature', Attrs, [SignedInfo, SignatureValue, _SignatureObject]}
) ->
    {'ds:Signature', Attrs, [SignedInfo, SignatureValue]}.

remove_signed_info_from_signature(
    {'ds:Signature', Attrs, [_SignedInfo, SignatureValue, SignatureObject]}
) ->
    {'ds:Signature', Attrs, [SignatureValue, SignatureObject]}.

replace_signature_value(
    {'ds:Signature', Attrs, [SignedInfo, _SignatureValue, SignatureObject]}, NewContent
) ->
    {'ds:Signature', Attrs, [SignedInfo, {'ds:SignatureValue', [], NewContent}, SignatureObject]}.

signed_info_parts(
    {'ds:SignedInfo', SignedInfoAttrs, [
        C14N, SignatureMethod, DocumentReference, SignedPropsReference
    ]}
) ->
    {SignedInfoAttrs, C14N, SignatureMethod, DocumentReference, SignedPropsReference}.

corrupt_x509_certificate({Tag, Attrs, Children}, Replacement) ->
    {Tag, Attrs, [corrupt_x509_certificate_child(C, Replacement) || C <- Children]}.

corrupt_x509_certificate_child({'ds:Signature', Attrs, Content}, Replacement) ->
    {'ds:Signature', Attrs, [corrupt_x509_certificate_child(C, Replacement) || C <- Content]};
corrupt_x509_certificate_child({'ds:KeyInfo', Attrs, Content}, Replacement) ->
    {'ds:KeyInfo', Attrs, [corrupt_x509_certificate_child(C, Replacement) || C <- Content]};
corrupt_x509_certificate_child({'ds:X509Data', Attrs, Content}, Replacement) ->
    {'ds:X509Data', Attrs, [corrupt_x509_certificate_child(C, Replacement) || C <- Content]};
corrupt_x509_certificate_child({'ds:X509Certificate', Attrs, _}, Replacement) ->
    {'ds:X509Certificate', Attrs, Replacement};
corrupt_x509_certificate_child(Other, _Replacement) ->
    Other.
