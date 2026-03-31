-module(signerl_SUITE).

-include_lib("eunit/include/eunit.hrl").
-compile([export_all, nowarn_export_all]).

suite() ->
    [{timetrap, {seconds, 30}}].

init_per_suite(Config) ->
    Config.
end_per_suite(_Config) ->
    ok.
init_per_testcase(_TestCase, Config) ->
    Config.
end_per_testcase(_TestCase, _Config) ->
    ok.

%%%%%%%%%%%%%%%%%%%%%%%
%%% GROUPS
%%%%%%%%%%%%%%%%%%%%%%%

groups() ->
    [
        {sign_group, [], [
            add_signature_element_inserts_signature_value,
            add_signature_element_inserts_signed_properties,
            add_signature_element_extracts_signature_value,
            build_signature_element_rsa_and_ecdsa,
            build_signature_element_returns_error_with_invalid_hash_or_key,
            sign,
            sign_with_chain_leaf_rsa,
            sign_with_self_signed_rsa,
            sign_with_self_signed_ecdsa,
            sign_deterministic,
            sign_uses_input_prolog_binary_and_file,
            sign_missing_prolog_binary_returns_error,
            sign_invalid_prolog_file_returns_error,
            verify_missing_prolog_binary_returns_error,
            verify_invalid_prolog_file_returns_error,
            verify_returns_error_without_signature_element,
            verify_returns_error_without_signature_value,
            verify_returns_error_with_empty_signature_value,
            verify_returns_error_with_invalid_base64_signature_value,
            verify_returns_error_with_self_closing_signature_value,
            verify_returns_error_with_non_text_signature_value_in_signedinfo,
            verify_returns_error_with_non_byte_list_signature_value_in_signedinfo,
            verify_returns_error_with_empty_binary_signature_value_in_signedinfo,
            verify_returns_error_without_object,
            verify_returns_error_without_qualifying_properties,
            verify_returns_error_without_signed_properties,
            verify_returns_error_without_signed_signature_properties,
            verify_returns_error_without_signed_info,
            verify_returns_error_without_signing_time,
            verify_returns_error_with_invalid_signing_time,
            verify_returns_error_with_self_closing_signing_time,
            verify_returns_false_with_wrong_signature_value,
            verify_fails_on_modified_message,
            verify_fails_on_modified_signing_time,
            verify_fails_with_wrong_keys,
            sign_returns_error_with_unsupported_hash,
            sign_returns_error_with_unsupported_key,
            verify_returns_error_with_unsupported_hash,
            extract_signature_returns_error_without_signature_element_direct,
            extract_signature_data_returns_error_with_missing_c14n,
            verify_reference_digests_returns_error_with_invalid_c14n_algorithm,
            verify_reference_digests_returns_error_with_invalid_signature_method_algorithm,
            extract_signature_data_returns_error_with_missing_reference_uri,
            extract_signature_data_returns_error_with_invalid_reference_payload,
            verify_reference_digests_returns_error_with_missing_document_transforms,
            verify_reference_digests_returns_error_with_invalid_document_transform_algorithm,
            verify_reference_digests_returns_error_with_transform_without_algorithm,
            verify_reference_digests_returns_error_with_invalid_transform_element,
            extract_signature_data_handles_duplicate_signed_properties_type_attribute,
            verify_reference_digests_returns_error_with_missing_signed_properties_element,
            verify_reference_digests_returns_error_with_invalid_document_reference,
            verify_reference_digests_returns_error_with_invalid_signed_properties_reference,
            verify_reference_digests_returns_error_with_invalid_signature_data,
            xades_xml_returns_error_with_non_signature_input
        ]}
    ].

all() ->
    [{group, sign_group}].

%%%%%%%%%%%%%%%%%%%%%%%
%%% TEST CASES
%%%%%%%%%%%%%%%%%%%%%%%
init_per_group(sign_group, Config) ->
    Config;
init_per_group(_, Config) ->
    Config.
end_per_group(sign_group, _Config) ->
    ok;
end_per_group(_, _Config) ->
    ok.

add_signature_element_inserts_signature_value(_Config) ->
    Path = "test/examples/base/books.xml",
    Message = signerl_xml:parse_file(Path),
    Key = signerl_cert_helpers:signer_rsa_key(),
    {ok, SignatureElement} = signerl_signature:build_signature_element(Message, sha256, Key),
    SignedMessage = signerl_xml:add_new_element(SignatureElement, Message),
    ?assertMatch(
        {ok, {'ds:SignatureValue', [], [_]}},
        signerl_xml:find_path(
            [
                'ds:Signature',
                'ds:SignatureValue'
            ],
            SignedMessage
        )
    ).

add_signature_element_inserts_signed_properties(_Config) ->
    Message = signerl_xml:parse_file("test/examples/base/books.xml"),
    Key = signerl_cert_helpers:signer_rsa_key(),
    {ok, SignatureElement} = signerl_signature:build_signature_element(Message, sha256, Key),
    SignedMessage = signerl_xml:add_new_element(SignatureElement, Message),
    SignedMessageBin = signerl_xml:export(
        ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"], SignedMessage
    ),
    ?assertMatch({_, _}, binary:match(SignedMessageBin, <<"<ds:SignedInfo>">>)),
    ?assertMatch({_, _}, binary:match(SignedMessageBin, <<"<ds:Object>">>)),
    ?assertMatch({_, _}, binary:match(SignedMessageBin, <<"<xades:QualifyingProperties ">>)),
    ?assertMatch({_, _}, binary:match(SignedMessageBin, <<"<xades:SignedProperties ">>)),
    ?assertMatch({_, _}, binary:match(SignedMessageBin, <<"<xades:SigningTime>">>)),
    {ok, SigningTimeElement} = signerl_xml:find_path(
        [
            'ds:Signature',
            'ds:Object',
            'xades:QualifyingProperties',
            'xades:SignedProperties',
            'xades:SignedSignatureProperties',
            'xades:SigningTime'
        ],
        SignedMessage
    ),
    {ok, SigningTime} = signerl_xml:single_text(SigningTimeElement),
    ?assertEqual(true, signerl_utils:valid_utc_timestamp(SigningTime)).

add_signature_element_extracts_signature_value(_Config) ->
    Message = signerl_xml:parse_file("test/examples/base/books.xml"),
    Key = signerl_cert_helpers:signer_rsa_key(),
    {ok, SignatureElement} = signerl_signature:build_signature_element(Message, sha256, Key),
    SignedMessage = signerl_xml:add_new_element(SignatureElement, Message),
    {ok, #{
        signature_bytes := SignatureBytes,
        unsigned_message := Message,
        signed_properties := #{signing_time := SigningTime}
    }} =
        signerl_verify:extract_signature_data(SignedMessage),
    ?assertEqual(true, is_binary(SignatureBytes)),
    ?assertEqual(true, byte_size(SignatureBytes) > 0),
    ?assertEqual(true, signerl_utils:valid_utc_timestamp(SigningTime)),
    ok.

build_signature_element_rsa_and_ecdsa(_Config) ->
    Message = signerl_xml:parse_file("test/examples/base/books.xml"),
    RsaKey = signerl_cert_helpers:signer_rsa_key(),
    EcdsaKey = signerl_cert_helpers:signer_ecdsa_key(),
    {ok, RsaSignature} = signerl_signature:build_signature_element(Message, sha256, RsaKey),
    {ok, EcdsaSignature} = signerl_signature:build_signature_element(Message, sha256, EcdsaKey),

    assert_has_signed_info(RsaSignature),
    assert_has_signed_info(EcdsaSignature).

build_signature_element_returns_error_with_invalid_hash_or_key(_Config) ->
    Message = signerl_xml:parse_file("test/examples/base/books.xml"),
    RsaKey = signerl_cert_helpers:signer_rsa_key(),
    ?assertEqual(
        {error, invalid_signature},
        signerl_signature:build_signature_element(Message, sha512, RsaKey)
    ),
    ?assertEqual(
        {error, invalid_signature},
        signerl_signature:build_signature_element(Message, sha256, invalid_key)
    ),
    ?assertEqual(
        {error, invalid_signature},
        signerl_signature:build_signature_element(Message, sha256, {unsupported})
    ).

sign(_Config) ->
    KeyPath = signerl_utils:file_path("priv/key.pem"),
    {ok, KeyRaw} = file:read_file(KeyPath),
    [KeyDer] = public_key:pem_decode(KeyRaw),
    Key = public_key:pem_entry_decode(KeyDer),

    Path = "test/examples/base/books.xml",
    {ok, RawMessage} = file:read_file(signerl_utils:file_path(Path)),

    SignedMessage = signerl:sign(RawMessage, sha256, Key),
    SignedMessageFromFile = signerl:sign(signerl_utils:file_path(Path), sha256, KeyPath),
    ?assertEqual(true, signerl:verify(SignedMessage, sha256, Key)),
    ?assertEqual(true, signerl:verify(SignedMessageFromFile, sha256, KeyPath)).

sign_with_chain_leaf_rsa(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),

    Key = signerl_cert_helpers:leaf_key(),
    CertPath = signerl_cert_helpers:leaf_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    SignedMessage = signerl:sign(RawMessage, sha256, Key),
    ?assertEqual(true, signerl:verify(SignedMessage, sha256, PublicKey)).

sign_with_self_signed_rsa(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),

    Key = signerl_cert_helpers:signer_rsa_key(),
    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    SignedMessage = signerl:sign(RawMessage, sha256, Key),
    ?assertEqual(true, signerl:verify(SignedMessage, sha256, PublicKey)).

sign_with_self_signed_ecdsa(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),

    Key = signerl_cert_helpers:signer_ecdsa_key(),
    CertPath = signerl_cert_helpers:signer_ecdsa_cert_path(),
    PublicKey = test_helpers:ecdsa_public_key_from_cert(CertPath),

    SignedMessage = signerl:sign(RawMessage, sha256, Key),
    ?assertEqual(true, signerl:verify(SignedMessage, sha256, PublicKey)).

sign_deterministic(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),

    Key = signerl_cert_helpers:signer_rsa_key(),

    SignedMessage1 = signerl:sign(RawMessage, sha256, Key),
    SignedMessage2 = signerl:sign(RawMessage, sha256, Key),
    ?assertEqual(SignedMessage1, SignedMessage2).

sign_uses_input_prolog_binary_and_file(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/prolog/books_custom_prolog.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),

    Key = signerl_cert_helpers:signer_rsa_key(),
    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    SignedMessage = signerl:sign(RawMessage, sha256, Key),
    ?assertMatch({_, _}, binary:match(SignedMessage, <<"standalone=\"yes\"">>)),
    ?assertEqual(true, signerl:verify(SignedMessage, sha256, PublicKey)),
    SignedMessageFromFile = signerl:sign(MessagePath, sha256, Key),
    ?assertMatch({_, _}, binary:match(SignedMessageFromFile, <<"standalone=\"yes\"">>)),
    ?assertEqual(true, signerl:verify(SignedMessageFromFile, sha256, PublicKey)).

sign_missing_prolog_binary_returns_error(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/prolog/books_no_prolog.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),
    Key = signerl_cert_helpers:signer_rsa_key(),

    ?assertEqual({error, invalid_prolog}, signerl:sign(RawMessage, sha256, Key)).

sign_invalid_prolog_file_returns_error(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/prolog/books_invalid_prolog.xml"),
    Key = signerl_cert_helpers:signer_rsa_key(),

    ?assertEqual({error, invalid_prolog}, signerl:sign(MessagePath, sha256, Key)).

verify_missing_prolog_binary_returns_error(_Config) ->
    MissingPath = signerl_utils:file_path("test/examples/prolog/books_no_prolog.xml"),
    {ok, MissingRawMessage} = file:read_file(MissingPath),

    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    ?assertEqual({error, invalid_signature}, signerl:verify(MissingRawMessage, sha256, PublicKey)).

verify_invalid_prolog_file_returns_error(_Config) ->
    InvalidPath = signerl_utils:file_path("test/examples/prolog/books_invalid_prolog.xml"),

    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    ?assertEqual({error, invalid_signature}, signerl:verify(InvalidPath, sha256, PublicKey)).

verify_returns_error_without_signature_element(_Config) ->
    UnsignedPath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(UnsignedPath),
    SignKey = signerl_cert_helpers:signer_rsa_key(),

    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    ?assertEqual({error, invalid_signature}, signerl:verify(UnsignedPath, sha256, PublicKey)),
    SignedMessage = signerl:sign(RawMessage, sha256, SignKey),
    DoubleSignedMessage = signerl:sign(SignedMessage, sha256, SignKey),
    ?assertEqual(
        {error, invalid_signature}, signerl:verify(DoubleSignedMessage, sha256, PublicKey)
    ).

verify_returns_error_without_signature_value(_Config) ->
    SignedPath = signerl_utils:file_path(
        "test/examples/signed_properties/books_signature_no_value.xml"
    ),

    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    ?assertEqual({error, invalid_signature}, signerl:verify(SignedPath, sha256, PublicKey)).

verify_returns_error_with_empty_signature_value(_Config) ->
    EmptyValuePath = signerl_utils:file_path(
        "test/examples/signed_properties/books_signature_empty_value.xml"
    ),

    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    ?assertEqual({error, invalid_signature}, signerl:verify(EmptyValuePath, sha256, PublicKey)).

verify_returns_error_with_invalid_base64_signature_value(_Config) ->
    InvalidBase64Path = signerl_utils:file_path(
        "test/examples/signed_properties/books_signature_invalid_base64.xml"
    ),

    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    ?assertEqual({error, invalid_signature}, signerl:verify(InvalidBase64Path, sha256, PublicKey)).

verify_returns_error_with_self_closing_signature_value(_Config) ->
    SelfClosingValuePath = signerl_utils:file_path(
        "test/examples/signed_properties/books_signature_self_closing_value.xml"
    ),

    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    ?assertEqual(
        {error, invalid_signature}, signerl:verify(SelfClosingValuePath, sha256, PublicKey)
    ).

verify_returns_error_with_non_text_signature_value_in_signedinfo(_Config) ->
    SignatureData = valid_signature_data(),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = replace_signature_value(SignatureElement, [{'invalid', [], []}]),
    Message = message_with_signature(BrokenSignature),
    ?assertEqual({error, invalid_signature}, signerl_verify:extract_signature_data(Message)).

verify_returns_error_with_non_byte_list_signature_value_in_signedinfo(_Config) ->
    SignatureData = valid_signature_data(),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = replace_signature_value(SignatureElement, [[65, {invalid, [], []}]]),
    Message = message_with_signature(BrokenSignature),
    ?assertEqual({error, invalid_signature}, signerl_verify:extract_signature_data(Message)).

verify_returns_error_with_empty_binary_signature_value_in_signedinfo(_Config) ->
    SignatureData = valid_signature_data(),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = replace_signature_value(SignatureElement, [<<>>]),
    Message = message_with_signature(BrokenSignature),
    ?assertEqual({error, invalid_signature}, signerl_verify:extract_signature_data(Message)).

verify_returns_error_without_object(_Config) ->
    MissingObjectPath = signerl_utils:file_path(
        "test/examples/signed_properties/books_signature_missing_object.xml"
    ),

    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    ?assertEqual({error, invalid_signature}, signerl:verify(MissingObjectPath, sha256, PublicKey)).

verify_returns_error_without_qualifying_properties(_Config) ->
    MissingQualifyingPropsPath = signerl_utils:file_path(
        "test/examples/signed_properties/books_signature_missing_qualifying_properties.xml"
    ),

    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    ?assertEqual(
        {error, invalid_signature}, signerl:verify(MissingQualifyingPropsPath, sha256, PublicKey)
    ).

verify_returns_error_without_signed_properties(_Config) ->
    MissingPropsPath = signerl_utils:file_path(
        "test/examples/signed_properties/books_signature_missing_signed_properties.xml"
    ),

    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    ?assertEqual({error, invalid_signature}, signerl:verify(MissingPropsPath, sha256, PublicKey)).

verify_returns_error_without_signed_signature_properties(_Config) ->
    MissingSignedSigPropsPath = signerl_utils:file_path(
        "test/examples/signed_properties/books_signature_missing_signed_signature_properties.xml"
    ),

    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    ?assertEqual(
        {error, invalid_signature}, signerl:verify(MissingSignedSigPropsPath, sha256, PublicKey)
    ).

verify_returns_error_without_signed_info(_Config) ->
    SignatureData = valid_signature_data(),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = remove_signed_info_from_signature(SignatureElement),
    Message = message_with_signature(BrokenSignature),
    ?assertEqual({error, invalid_signature}, signerl_verify:extract_signature_data(Message)).

verify_returns_error_without_signing_time(_Config) ->
    MissingSigningTimePath = signerl_utils:file_path(
        "test/examples/signed_properties/books_signature_missing_signing_time.xml"
    ),

    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    ?assertEqual(
        {error, invalid_signature}, signerl:verify(MissingSigningTimePath, sha256, PublicKey)
    ).

verify_returns_error_with_invalid_signing_time(_Config) ->
    InvalidSigningTimePath = signerl_utils:file_path(
        "test/examples/signed_properties/books_signature_invalid_signing_time.xml"
    ),

    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    ?assertEqual(
        {error, invalid_signature}, signerl:verify(InvalidSigningTimePath, sha256, PublicKey)
    ).

verify_returns_error_with_self_closing_signing_time(_Config) ->
    SelfClosingSigningTimePath = signerl_utils:file_path(
        "test/examples/signed_properties/books_signature_self_closing_signing_time.xml"
    ),

    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    ?assertEqual(
        {error, invalid_signature}, signerl:verify(SelfClosingSigningTimePath, sha256, PublicKey)
    ).

verify_returns_false_with_wrong_signature_value(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),

    Key = signerl_cert_helpers:signer_rsa_key(),
    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    SignedMessage = signerl:sign(RawMessage, sha256, Key),
    {ok, ParsedSignedMessage} = signerl_xml:parse_binary(SignedMessage),
    {ok, SignatureData} = signerl_verify:extract_signature_data(ParsedSignedMessage),
    SignatureBytes = maps:get(signature_bytes, SignatureData),
    <<FirstByte, Rest/binary>> = SignatureBytes,
    CorruptedSignatureBytes = <<((FirstByte + 1) band 16#FF), Rest/binary>>,
    SignatureValue = base64:encode(SignatureBytes),
    CorruptedSignatureValue = base64:encode(CorruptedSignatureBytes),
    Corrupted = binary:replace(SignedMessage, SignatureValue, CorruptedSignatureValue, []),
    ?assertEqual(false, signerl:verify(Corrupted, sha256, PublicKey)).

verify_fails_on_modified_message(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),

    Key = signerl_cert_helpers:signer_rsa_key(),
    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    SignedMessage = signerl:sign(RawMessage, sha256, Key),
    % Change actual content to avoid being normalized away by XML parsing.
    Modified = binary:replace(SignedMessage, <<"Gatsby">>, <<"Gatzby">>, []),
    ?assertEqual(false, signerl:verify(Modified, sha256, PublicKey)).

verify_fails_on_modified_signing_time(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),

    Key = signerl_cert_helpers:signer_rsa_key(),
    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    SignedMessage = signerl:sign(RawMessage, sha256, Key),
    {ok, ParsedSignedMessage} = signerl_xml:parse_binary(SignedMessage),
    {ok, #{signed_properties := #{signing_time := SigningTime}}} =
        signerl_verify:extract_signature_data(ParsedSignedMessage),
    Modified = binary:replace(SignedMessage, SigningTime, <<"2000-01-01T00:00:00Z">>, []),
    ?assertEqual(false, signerl:verify(Modified, sha256, PublicKey)).

verify_fails_with_wrong_keys(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),

    SignKey = signerl_cert_helpers:signer_rsa_key(),
    WrongCertPath = signerl_cert_helpers:leaf_cert_path(),
    WrongPublicKey = test_helpers:rsa_public_key_from_cert(WrongCertPath),

    RsaSignedMessage = signerl:sign(RawMessage, sha256, SignKey),
    ?assertEqual(false, signerl:verify(RsaSignedMessage, sha256, WrongPublicKey)),
    EcdsaKey = signerl_cert_helpers:signer_ecdsa_key(),
    EcdsaSignedMessage = signerl:sign(RawMessage, sha256, EcdsaKey),
    % Wrong key type (RSA key against ECDSA signature) must fail verification.
    ?assertEqual(false, signerl:verify(EcdsaSignedMessage, sha256, WrongPublicKey)).

sign_returns_error_with_unsupported_hash(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),
    Key = signerl_cert_helpers:signer_rsa_key(),
    ?assertEqual({error, invalid_signature}, signerl:sign(RawMessage, sha512, Key)).

sign_returns_error_with_unsupported_key(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),
    ?assertEqual({error, invalid_signature}, signerl:sign(RawMessage, sha256, invalid_key)).

verify_returns_error_with_unsupported_hash(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),
    Key = signerl_cert_helpers:signer_rsa_key(),
    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),
    SignedMessage = signerl:sign(RawMessage, sha256, Key),
    ?assertEqual({error, invalid_signature}, signerl:verify(SignedMessage, sha512, PublicKey)).

extract_signature_returns_error_without_signature_element_direct(_Config) ->
    Message = signerl_xml:parse_file("test/examples/base/books.xml"),
    ?assertEqual({error, invalid_signature}, signerl_verify:extract_signature_data(Message)).

extract_signature_data_returns_error_with_missing_c14n(_Config) ->
    SignatureData = valid_signature_data(),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = remove_c14n_from_signature(SignatureElement),
    Message = message_with_signature(BrokenSignature),
    ?assertEqual({error, invalid_signature}, signerl_verify:extract_signature_data(Message)).

verify_reference_digests_returns_error_with_invalid_c14n_algorithm(_Config) ->
    SignatureData = valid_signature_data(),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = replace_c14n_algorithm(SignatureElement, "invalid-c14n"),
    Message = message_with_signature(BrokenSignature),
    {ok, BrokenData} = signerl_verify:extract_signature_data(Message),
    ?assertEqual(
        {error, invalid_signature}, signerl_verify:verify_reference_digests(BrokenData, sha256)
    ).

verify_reference_digests_returns_error_with_invalid_signature_method_algorithm(_Config) ->
    SignatureData = valid_signature_data(),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = replace_signature_method_algorithm(
        SignatureElement, "invalid-signature-method"
    ),
    Message = message_with_signature(BrokenSignature),
    {ok, BrokenData} = signerl_verify:extract_signature_data(Message),
    ?assertEqual(
        {error, invalid_signature}, signerl_verify:verify_reference_digests(BrokenData, sha256)
    ).

extract_signature_data_returns_error_with_missing_reference_uri(_Config) ->
    SignatureData = valid_signature_data(),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = remove_document_reference_uri(SignatureElement),
    Message = message_with_signature(BrokenSignature),
    ?assertEqual({error, invalid_signature}, signerl_verify:extract_signature_data(Message)).

extract_signature_data_returns_error_with_invalid_reference_payload(_Config) ->
    SignatureData = valid_signature_data(),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = remove_document_reference_digest_value(SignatureElement),
    Message = message_with_signature(BrokenSignature),
    ?assertEqual({error, invalid_signature}, signerl_verify:extract_signature_data(Message)).

verify_reference_digests_returns_error_with_missing_document_transforms(_Config) ->
    SignatureData = valid_signature_data(),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = remove_document_reference_transforms(SignatureElement),
    Message = message_with_signature(BrokenSignature),
    {ok, BrokenData} = signerl_verify:extract_signature_data(Message),
    ?assertEqual(
        {error, invalid_signature}, signerl_verify:verify_reference_digests(BrokenData, sha256)
    ).

verify_reference_digests_returns_error_with_invalid_document_transform_algorithm(_Config) ->
    SignatureData = valid_signature_data(),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature =
        replace_document_reference_transform_algorithm(SignatureElement, "invalid-transform"),
    Message = message_with_signature(BrokenSignature),
    {ok, BrokenData} = signerl_verify:extract_signature_data(Message),
    ?assertEqual(
        {error, invalid_signature}, signerl_verify:verify_reference_digests(BrokenData, sha256)
    ).

verify_reference_digests_returns_error_with_transform_without_algorithm(_Config) ->
    SignatureData = valid_signature_data(),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = replace_document_transforms(SignatureElement, [{'ds:Transform', [], []}]),
    Message = message_with_signature(BrokenSignature),
    ?assertEqual({error, invalid_signature}, signerl_verify:extract_signature_data(Message)).

verify_reference_digests_returns_error_with_invalid_transform_element(_Config) ->
    SignatureData = valid_signature_data(),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature =
        replace_document_transforms(SignatureElement, [{'ds:InvalidTransform', [], []}]),
    Message = message_with_signature(BrokenSignature),
    ?assertEqual({error, invalid_signature}, signerl_verify:extract_signature_data(Message)).

extract_signature_data_handles_duplicate_signed_properties_type_attribute(_Config) ->
    SignatureData = valid_signature_data(),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = duplicate_signed_properties_type_attr(SignatureElement),
    Message = message_with_signature(BrokenSignature),
    {ok, BrokenData} = signerl_verify:extract_signature_data(Message),
    ?assertEqual(
        {error, invalid_signature}, signerl_verify:verify_reference_digests(BrokenData, sha256)
    ).

verify_reference_digests_returns_error_with_missing_signed_properties_element(_Config) ->
    SignatureData = valid_signature_data(),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = remove_signed_properties_from_signature(SignatureElement),
    BrokenData = maps:put(signature_element, BrokenSignature, SignatureData),
    ?assertEqual(
        {error, invalid_signature}, signerl_verify:verify_reference_digests(BrokenData, sha256)
    ).

verify_reference_digests_returns_error_with_invalid_document_reference(_Config) ->
    SignatureData = valid_signature_data(),
    References = maps:get(references, SignatureData),
    DocumentReference = maps:get(document, References),
    BrokenDocumentReference = maps:put(uri, "invalid", DocumentReference),
    BrokenReferences = maps:put(document, BrokenDocumentReference, References),
    BrokenData = maps:put(references, BrokenReferences, SignatureData),
    ?assertEqual(
        {error, invalid_signature}, signerl_verify:verify_reference_digests(BrokenData, sha256)
    ).

verify_reference_digests_returns_error_with_invalid_signed_properties_reference(_Config) ->
    SignatureData = valid_signature_data(),
    References = maps:get(references, SignatureData),
    SignedPropertiesReference = maps:get(signed_properties, References),
    BrokenSignedPropertiesReference = maps:put(type, undefined, SignedPropertiesReference),
    BrokenReferences = maps:put(signed_properties, BrokenSignedPropertiesReference, References),
    BrokenData = maps:put(references, BrokenReferences, SignatureData),
    ?assertEqual(
        {error, invalid_signature}, signerl_verify:verify_reference_digests(BrokenData, sha256)
    ).

verify_reference_digests_returns_error_with_invalid_signature_data(_Config) ->
    ?assertEqual(
        {error, invalid_signature}, signerl_verify:verify_reference_digests(#{}, sha256)
    ).

xades_xml_returns_error_with_non_signature_input(_Config) ->
    InvalidElement = {'root', [], []},
    ?assertEqual(
        {error, invalid_signature},
        signerl_xades_xml:find_signed_signature_properties(InvalidElement)
    ),
    ?assertEqual(
        {error, invalid_signature},
        signerl_xades_xml:find_signed_properties_element(InvalidElement)
    ).

valid_signature_data() ->
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),
    Key = signerl_cert_helpers:signer_rsa_key(),
    SignedMessage = signerl:sign(RawMessage, sha256, Key),
    {ok, ParsedSignedMessage} = signerl_xml:parse_binary(SignedMessage),
    {ok, SignatureData} = signerl_verify:extract_signature_data(ParsedSignedMessage),
    SignatureData.

message_with_signature(SignatureElement) ->
    Message = signerl_xml:parse_file("test/examples/base/books.xml"),
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

duplicate_signed_properties_type_attr(
    {'ds:Signature', Attrs, [SignedInfo, SignatureValue, SignatureObject]}
) ->
    {SignedInfoAttrs, C14N, SignatureMethod, DocumentReference, SignedPropsReference} =
        signed_info_parts(SignedInfo),
    {'ds:Reference', SignedPropsAttrs, SignedPropsContent} = SignedPropsReference,
    {'ds:Signature', Attrs, [
        {'ds:SignedInfo', SignedInfoAttrs, [
            C14N,
            SignatureMethod,
            DocumentReference,
            {'ds:Reference', SignedPropsAttrs ++ [{'Type', "duplicate"}], SignedPropsContent}
        ]},
        SignatureValue,
        SignatureObject
    ]}.

signed_info_parts(
    {'ds:SignedInfo', SignedInfoAttrs, [
        C14N, SignatureMethod, DocumentReference, SignedPropsReference
    ]}
) ->
    {SignedInfoAttrs, C14N, SignatureMethod, DocumentReference, SignedPropsReference}.

assert_has_signed_info(SignatureElement) ->
    ?assertMatch(
        {ok, {'ds:SignedInfo', _, _}}, signerl_xml:find_path(['ds:SignedInfo'], SignatureElement)
    ).
