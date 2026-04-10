-module(signerl_SUITE).

-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").
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
        {build_group, [], [
            add_signature_element_inserts_signature_value,
            add_signature_element_inserts_signed_properties,
            add_signature_element_extracts_signature_value,
            build_signature_element_rsa_and_ecdsa,
            build_signature_element_returns_error_with_invalid_hash_or_key
        ]},
        {sign_group, [], [
            sign,
            sign_with_chain_leaf_rsa,
            sign_with_self_signed_rsa,
            sign_with_self_signed_ecdsa,
            sign_deterministic,
            sign_uses_input_prolog_binary_and_file,
            sign_missing_prolog_binary_returns_error,
            sign_invalid_prolog_file_returns_error,
            sign_returns_error_with_unsupported_hash,
            sign_returns_error_with_unsupported_key,
            sign_returns_file_error_with_missing_message_file,
            sign_returns_file_error_with_missing_key_file,
            sign_returns_error_with_invalid_pem_key_file,
            sign4_returns_file_error_with_missing_message_file,
            sign4_returns_file_error_with_missing_key_file
        ]},
        {verify_fixture_error_group, [], [
            verify_missing_prolog_binary_returns_error,
            verify_invalid_prolog_file_returns_error,
            verify_returns_error_without_signature_element,
            verify_returns_error_without_signature_value,
            verify_returns_error_with_empty_signature_value,
            verify_returns_error_with_invalid_base64_signature_value,
            verify_returns_error_with_self_closing_signature_value,
            verify_returns_error_without_object,
            verify_returns_error_without_qualifying_properties,
            verify_returns_error_without_signed_properties,
            verify_returns_error_without_signed_signature_properties,
            verify_returns_error_without_signing_time,
            verify_returns_error_with_invalid_signing_time,
            verify_returns_error_with_self_closing_signing_time,
            verify_returns_error_with_unsupported_hash,
            verify_returns_file_error_with_missing_signed_message_file,
            verify_returns_file_error_with_missing_key_file,
            verify_returns_error_with_invalid_pem_key_file
        ]},
        {verify_signed_info_error_group, [], [
            verify_returns_error_with_non_text_signature_value_in_signedinfo,
            verify_returns_error_with_non_byte_list_signature_value_in_signedinfo,
            verify_returns_error_with_empty_binary_signature_value_in_signedinfo,
            verify_returns_error_without_signed_info,
            extract_signature_data_returns_error_with_missing_c14n,
            verify_reference_digests_returns_error_with_invalid_c14n_algorithm,
            verify_reference_digests_accepts_exc_c14n_algorithm,
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
            verify_reference_digests_returns_error_with_invalid_signature_data
        ]},
        {verify_tamper_group, [], [
            verify_returns_false_with_wrong_signature_value,
            verify_fails_on_modified_message,
            verify_fails_on_modified_signing_time,
            verify_fails_with_wrong_keys
        ]},
        {keyinfo_group, [], [
            sign_with_certificate_includes_keyinfo,
            sign_without_certificate_omits_keyinfo,
            sign_with_certificate_roundtrip_rsa,
            sign_with_certificate_roundtrip_ecdsa,
            sign_with_certificate_from_key_file,
            sign_with_certificate_from_message_file,
            verify_extracts_certificate_from_keyinfo,
            verify_extracts_no_keyinfo_when_absent
        ]},
        {interop_smoke_group, [], [
            c14n_idempotent_after_sign,
            is_signature_element_shared
        ]},
        {xml_utils_group, [], [
            export_fragment_returns_binary,
            to_file_writes_and_reads_back,
            parse_prolog_rejects_bom,
            single_text_returns_binary_and_list,
            single_text_returns_not_found
        ]}
    ].

all() ->
    [
        {group, build_group},
        {group, sign_group},
        {group, verify_fixture_error_group},
        {group, verify_signed_info_error_group},
        {group, verify_tamper_group},
        {group, keyinfo_group},
        {group, interop_smoke_group},
        {group, xml_utils_group},
        extract_signature_returns_error_without_signature_element_direct,
        xades_xml_returns_error_with_non_signature_input,
        c14n_mode_returns_exc_for_exc_c14n_algorithm,
        extract_x509_certificate_returns_undefined_for_invalid_cert
    ].

%%%%%%%%%%%%%%%%%%%%%%%
%%% GROUP INIT / END
%%%%%%%%%%%%%%%%%%%%%%%

init_per_group(build_group, Config) ->
    Message = signerl_xml:parse_file("test/examples/base/books.xml"),
    RsaKey = signerl_cert_helpers:signer_rsa_key(),
    EcdsaKey = signerl_cert_helpers:signer_ecdsa_key(),
    [{message, Message}, {rsa_key, RsaKey}, {ecdsa_key, EcdsaKey} | Config];
init_per_group(sign_group, Config) ->
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),
    RsaKey = signerl_cert_helpers:signer_rsa_key(),
    EcdsaKey = signerl_cert_helpers:signer_ecdsa_key(),
    LeafKey = signerl_cert_helpers:leaf_key(),
    RsaPublicKey = test_helpers:rsa_public_key_from_cert(
        signerl_cert_helpers:signer_rsa_cert_path()
    ),
    EcdsaPublicKey = test_helpers:ecdsa_public_key_from_cert(
        signerl_cert_helpers:signer_ecdsa_cert_path()
    ),
    LeafPublicKey = test_helpers:rsa_public_key_from_cert(
        signerl_cert_helpers:leaf_cert_path()
    ),
    [
        {message_path, MessagePath},
        {raw_message, RawMessage},
        {rsa_key, RsaKey},
        {ecdsa_key, EcdsaKey},
        {leaf_key, LeafKey},
        {rsa_public_key, RsaPublicKey},
        {ecdsa_public_key, EcdsaPublicKey},
        {leaf_public_key, LeafPublicKey}
        | Config
    ];
init_per_group(verify_fixture_error_group, Config) ->
    RsaKey = signerl_cert_helpers:signer_rsa_key(),
    RsaPublicKey = test_helpers:rsa_public_key_from_cert(
        signerl_cert_helpers:signer_rsa_cert_path()
    ),
    [{rsa_key, RsaKey}, {rsa_public_key, RsaPublicKey} | Config];
init_per_group(verify_signed_info_error_group, Config) ->
    SignatureData = compute_valid_signature_data(),
    [{signature_data, SignatureData} | Config];
init_per_group(verify_tamper_group, Config) ->
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),
    RsaKey = signerl_cert_helpers:signer_rsa_key(),
    EcdsaKey = signerl_cert_helpers:signer_ecdsa_key(),
    RsaPublicKey = test_helpers:rsa_public_key_from_cert(
        signerl_cert_helpers:signer_rsa_cert_path()
    ),
    WrongPublicKey = test_helpers:rsa_public_key_from_cert(
        signerl_cert_helpers:leaf_cert_path()
    ),
    [
        {raw_message, RawMessage},
        {rsa_key, RsaKey},
        {ecdsa_key, EcdsaKey},
        {rsa_public_key, RsaPublicKey},
        {wrong_public_key, WrongPublicKey}
        | Config
    ];
init_per_group(keyinfo_group, Config) ->
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),
    RsaKey = signerl_cert_helpers:signer_rsa_key(),
    EcdsaKey = signerl_cert_helpers:signer_ecdsa_key(),
    RsaCertDer = test_helpers:cert_der(signerl_cert_helpers:signer_rsa_cert_path()),
    EcdsaCertDer = test_helpers:cert_der(signerl_cert_helpers:signer_ecdsa_cert_path()),
    RsaPublicKey = test_helpers:rsa_public_key_from_cert(
        signerl_cert_helpers:signer_rsa_cert_path()
    ),
    EcdsaPublicKey = test_helpers:ecdsa_public_key_from_cert(
        signerl_cert_helpers:signer_ecdsa_cert_path()
    ),
    RsaKeyPath = signerl_cert_helpers:signer_rsa_key_path(),
    [
        {message_path, MessagePath},
        {raw_message, RawMessage},
        {rsa_key, RsaKey},
        {rsa_key_path, RsaKeyPath},
        {ecdsa_key, EcdsaKey},
        {rsa_cert_der, RsaCertDer},
        {ecdsa_cert_der, EcdsaCertDer},
        {rsa_public_key, RsaPublicKey},
        {ecdsa_public_key, EcdsaPublicKey}
        | Config
    ];
init_per_group(interop_smoke_group, Config) ->
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),
    RsaKey = signerl_cert_helpers:signer_rsa_key(),
    RsaPublicKey = test_helpers:rsa_public_key_from_cert(
        signerl_cert_helpers:signer_rsa_cert_path()
    ),
    [
        {raw_message, RawMessage},
        {rsa_key, RsaKey},
        {rsa_public_key, RsaPublicKey}
        | Config
    ];
init_per_group(_, Config) ->
    Config.

end_per_group(_, _Config) ->
    ok.

add_signature_element_inserts_signature_value(Config) ->
    Message = ?config(message, Config),
    Key = ?config(rsa_key, Config),
    {ok, SignatureElement} = signerl_signature:build_signature_element(
        Message, sha256, Key, undefined
    ),
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

add_signature_element_inserts_signed_properties(Config) ->
    Message = ?config(message, Config),
    Key = ?config(rsa_key, Config),
    {ok, SignatureElement} = signerl_signature:build_signature_element(
        Message, sha256, Key, undefined
    ),
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

add_signature_element_extracts_signature_value(Config) ->
    Message = ?config(message, Config),
    Key = ?config(rsa_key, Config),
    {ok, SignatureElement} = signerl_signature:build_signature_element(
        Message, sha256, Key, undefined
    ),
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

build_signature_element_rsa_and_ecdsa(Config) ->
    Message = ?config(message, Config),
    RsaKey = ?config(rsa_key, Config),
    EcdsaKey = ?config(ecdsa_key, Config),
    {ok, RsaSignature} = signerl_signature:build_signature_element(
        Message, sha256, RsaKey, undefined
    ),
    {ok, EcdsaSignature} = signerl_signature:build_signature_element(
        Message, sha256, EcdsaKey, undefined
    ),

    assert_has_signed_info(RsaSignature),
    assert_has_signed_info(EcdsaSignature).

build_signature_element_returns_error_with_invalid_hash_or_key(Config) ->
    Message = ?config(message, Config),
    RsaKey = ?config(rsa_key, Config),
    ?assertEqual(
        {error, unsupported_hash},
        signerl_signature:build_signature_element(Message, sha512, RsaKey, undefined)
    ),
    ?assertEqual(
        {error, unsupported_key},
        signerl_signature:build_signature_element(Message, sha256, invalid_key, undefined)
    ),
    ?assertEqual(
        {error, unsupported_key},
        signerl_signature:build_signature_element(Message, sha256, {unsupported}, undefined)
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

sign_with_chain_leaf_rsa(Config) ->
    RawMessage = ?config(raw_message, Config),
    Key = ?config(leaf_key, Config),
    PublicKey = ?config(leaf_public_key, Config),

    SignedMessage = signerl:sign(RawMessage, sha256, Key),
    ?assertEqual(true, signerl:verify(SignedMessage, sha256, PublicKey)).

sign_with_self_signed_rsa(Config) ->
    RawMessage = ?config(raw_message, Config),
    Key = ?config(rsa_key, Config),
    PublicKey = ?config(rsa_public_key, Config),

    SignedMessage = signerl:sign(RawMessage, sha256, Key),
    ?assertEqual(true, signerl:verify(SignedMessage, sha256, PublicKey)).

sign_with_self_signed_ecdsa(Config) ->
    RawMessage = ?config(raw_message, Config),
    Key = ?config(ecdsa_key, Config),
    PublicKey = ?config(ecdsa_public_key, Config),

    SignedMessage = signerl:sign(RawMessage, sha256, Key),
    ?assertEqual(true, signerl:verify(SignedMessage, sha256, PublicKey)).

sign_deterministic(Config) ->
    RawMessage = ?config(raw_message, Config),
    Key = ?config(rsa_key, Config),

    SignedMessage1 = signerl:sign(RawMessage, sha256, Key),
    SignedMessage2 = signerl:sign(RawMessage, sha256, Key),
    ?assertEqual(SignedMessage1, SignedMessage2).

sign_uses_input_prolog_binary_and_file(Config) ->
    Key = ?config(rsa_key, Config),
    PublicKey = ?config(rsa_public_key, Config),
    MessagePath = signerl_utils:file_path("test/examples/prolog/books_custom_prolog.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),

    SignedMessage = signerl:sign(RawMessage, sha256, Key),
    ?assertMatch({_, _}, binary:match(SignedMessage, <<"standalone=\"yes\"">>)),
    ?assertEqual(true, signerl:verify(SignedMessage, sha256, PublicKey)),
    SignedMessageFromFile = signerl:sign(MessagePath, sha256, Key),
    ?assertMatch({_, _}, binary:match(SignedMessageFromFile, <<"standalone=\"yes\"">>)),
    ?assertEqual(true, signerl:verify(SignedMessageFromFile, sha256, PublicKey)).

sign_missing_prolog_binary_returns_error(Config) ->
    Key = ?config(rsa_key, Config),
    MessagePath = signerl_utils:file_path("test/examples/prolog/books_no_prolog.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),

    ?assertEqual({error, invalid_prolog}, signerl:sign(RawMessage, sha256, Key)).

sign_invalid_prolog_file_returns_error(Config) ->
    Key = ?config(rsa_key, Config),
    MessagePath = signerl_utils:file_path("test/examples/prolog/books_invalid_prolog.xml"),

    ?assertEqual({error, invalid_prolog}, signerl:sign(MessagePath, sha256, Key)).

sign_returns_error_with_unsupported_hash(Config) ->
    RawMessage = ?config(raw_message, Config),
    Key = ?config(rsa_key, Config),
    ?assertEqual({error, unsupported_hash}, signerl:sign(RawMessage, sha512, Key)).

sign_returns_error_with_unsupported_key(Config) ->
    RawMessage = ?config(raw_message, Config),
    ?assertEqual({error, unsupported_key}, signerl:sign(RawMessage, sha256, invalid_key)).

sign_returns_file_error_with_missing_message_file(Config) ->
    RsaKey = ?config(rsa_key, Config),
    ?assertMatch(
        {error, {file_error, enoent}}, signerl:sign("nonexistent_file.xml", sha256, RsaKey)
    ).

sign_returns_file_error_with_missing_key_file(Config) ->
    RawMessage = ?config(raw_message, Config),
    ?assertMatch(
        {error, {file_error, enoent}}, signerl:sign(RawMessage, sha256, "nonexistent_key.pem")
    ).

sign_returns_error_with_invalid_pem_key_file(Config) ->
    RawMessage = ?config(raw_message, Config),
    InvalidPemPath = signerl_utils:file_path("test/examples/base/books.xml"),
    ?assertEqual({error, invalid_pem}, signerl:sign(RawMessage, sha256, InvalidPemPath)).

sign4_returns_file_error_with_missing_message_file(Config) ->
    RsaKey = ?config(rsa_key, Config),
    ?assertMatch(
        {error, {file_error, enoent}},
        signerl:sign("nonexistent_file.xml", sha256, RsaKey, <<"cert">>)
    ).

sign4_returns_file_error_with_missing_key_file(Config) ->
    RawMessage = ?config(raw_message, Config),
    ?assertMatch(
        {error, {file_error, enoent}},
        signerl:sign(RawMessage, sha256, "nonexistent_key.pem", <<"cert">>)
    ).

verify_missing_prolog_binary_returns_error(Config) ->
    PublicKey = ?config(rsa_public_key, Config),
    MissingPath = signerl_utils:file_path("test/examples/prolog/books_no_prolog.xml"),
    {ok, MissingRawMessage} = file:read_file(MissingPath),

    ?assertEqual({error, missing_signature}, signerl:verify(MissingRawMessage, sha256, PublicKey)).

verify_invalid_prolog_file_returns_error(Config) ->
    PublicKey = ?config(rsa_public_key, Config),
    InvalidPath = signerl_utils:file_path("test/examples/prolog/books_invalid_prolog.xml"),

    ?assertEqual({error, invalid_xml}, signerl:verify(InvalidPath, sha256, PublicKey)).

verify_returns_error_without_signature_element(Config) ->
    RsaKey = ?config(rsa_key, Config),
    PublicKey = ?config(rsa_public_key, Config),
    UnsignedPath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(UnsignedPath),
    SignKey = RsaKey,

    ?assertEqual({error, missing_signature}, signerl:verify(UnsignedPath, sha256, PublicKey)),
    SignedMessage = signerl:sign(RawMessage, sha256, SignKey),
    DoubleSignedMessage = signerl:sign(SignedMessage, sha256, SignKey),
    ?assertEqual(
        {error, missing_signature}, signerl:verify(DoubleSignedMessage, sha256, PublicKey)
    ).

verify_returns_error_without_signature_value(Config) ->
    PublicKey = ?config(rsa_public_key, Config),
    SignedPath = signerl_utils:file_path(
        "test/examples/signed_properties/books_signature_no_value.xml"
    ),

    ?assertEqual({error, missing_signature_value}, signerl:verify(SignedPath, sha256, PublicKey)).

verify_returns_error_with_empty_signature_value(Config) ->
    PublicKey = ?config(rsa_public_key, Config),
    EmptyValuePath = signerl_utils:file_path(
        "test/examples/signed_properties/books_signature_empty_value.xml"
    ),

    ?assertEqual(
        {error, missing_signature_value}, signerl:verify(EmptyValuePath, sha256, PublicKey)
    ).

verify_returns_error_with_invalid_base64_signature_value(Config) ->
    PublicKey = ?config(rsa_public_key, Config),
    InvalidBase64Path = signerl_utils:file_path(
        "test/examples/signed_properties/books_signature_invalid_base64.xml"
    ),

    ?assertEqual({error, invalid_base64}, signerl:verify(InvalidBase64Path, sha256, PublicKey)).

verify_returns_error_with_self_closing_signature_value(Config) ->
    PublicKey = ?config(rsa_public_key, Config),
    SelfClosingValuePath = signerl_utils:file_path(
        "test/examples/signed_properties/books_signature_self_closing_value.xml"
    ),

    ?assertEqual(
        {error, missing_signature_value}, signerl:verify(SelfClosingValuePath, sha256, PublicKey)
    ).

verify_returns_error_with_non_text_signature_value_in_signedinfo(Config) ->
    SignatureData = ?config(signature_data, Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = replace_signature_value(SignatureElement, [{'invalid', [], []}]),
    Message = message_with_signature(BrokenSignature),
    ?assertEqual({error, invalid_base64}, signerl_verify:extract_signature_data(Message)).

verify_returns_error_with_non_byte_list_signature_value_in_signedinfo(Config) ->
    SignatureData = ?config(signature_data, Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = replace_signature_value(SignatureElement, [[65, {invalid, [], []}]]),
    Message = message_with_signature(BrokenSignature),
    ?assertEqual({error, invalid_base64}, signerl_verify:extract_signature_data(Message)).

verify_returns_error_with_empty_binary_signature_value_in_signedinfo(Config) ->
    SignatureData = ?config(signature_data, Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = replace_signature_value(SignatureElement, [<<>>]),
    Message = message_with_signature(BrokenSignature),
    ?assertEqual({error, invalid_base64}, signerl_verify:extract_signature_data(Message)).

verify_returns_error_without_object(Config) ->
    PublicKey = ?config(rsa_public_key, Config),
    MissingObjectPath = signerl_utils:file_path(
        "test/examples/signed_properties/books_signature_missing_object.xml"
    ),

    ?assertEqual({error, missing_element}, signerl:verify(MissingObjectPath, sha256, PublicKey)).

verify_returns_error_without_qualifying_properties(Config) ->
    PublicKey = ?config(rsa_public_key, Config),
    MissingQualifyingPropsPath = signerl_utils:file_path(
        "test/examples/signed_properties/books_signature_missing_qualifying_properties.xml"
    ),

    ?assertEqual(
        {error, missing_element}, signerl:verify(MissingQualifyingPropsPath, sha256, PublicKey)
    ).

verify_returns_error_without_signed_properties(Config) ->
    PublicKey = ?config(rsa_public_key, Config),
    MissingPropsPath = signerl_utils:file_path(
        "test/examples/signed_properties/books_signature_missing_signed_properties.xml"
    ),

    ?assertEqual({error, missing_element}, signerl:verify(MissingPropsPath, sha256, PublicKey)).

verify_returns_error_without_signed_signature_properties(Config) ->
    PublicKey = ?config(rsa_public_key, Config),
    MissingSignedSigPropsPath = signerl_utils:file_path(
        "test/examples/signed_properties/books_signature_missing_signed_signature_properties.xml"
    ),

    ?assertEqual(
        {error, missing_element}, signerl:verify(MissingSignedSigPropsPath, sha256, PublicKey)
    ).

verify_returns_error_without_signed_info(Config) ->
    SignatureData = ?config(signature_data, Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = remove_signed_info_from_signature(SignatureElement),
    Message = message_with_signature(BrokenSignature),
    ?assertEqual({error, missing_signed_info}, signerl_verify:extract_signature_data(Message)).

verify_returns_error_without_signing_time(Config) ->
    PublicKey = ?config(rsa_public_key, Config),
    MissingSigningTimePath = signerl_utils:file_path(
        "test/examples/signed_properties/books_signature_missing_signing_time.xml"
    ),

    ?assertEqual(
        {error, missing_signing_time}, signerl:verify(MissingSigningTimePath, sha256, PublicKey)
    ).

verify_returns_error_with_invalid_signing_time(Config) ->
    PublicKey = ?config(rsa_public_key, Config),
    InvalidSigningTimePath = signerl_utils:file_path(
        "test/examples/signed_properties/books_signature_invalid_signing_time.xml"
    ),

    ?assertEqual(
        {error, invalid_signing_time}, signerl:verify(InvalidSigningTimePath, sha256, PublicKey)
    ).

verify_returns_error_with_self_closing_signing_time(Config) ->
    PublicKey = ?config(rsa_public_key, Config),
    SelfClosingSigningTimePath = signerl_utils:file_path(
        "test/examples/signed_properties/books_signature_self_closing_signing_time.xml"
    ),

    ?assertEqual(
        {error, invalid_signing_time}, signerl:verify(SelfClosingSigningTimePath, sha256, PublicKey)
    ).

verify_returns_false_with_wrong_signature_value(Config) ->
    RawMessage = ?config(raw_message, Config),
    Key = ?config(rsa_key, Config),
    PublicKey = ?config(rsa_public_key, Config),

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

verify_fails_on_modified_message(Config) ->
    RawMessage = ?config(raw_message, Config),
    Key = ?config(rsa_key, Config),
    PublicKey = ?config(rsa_public_key, Config),

    SignedMessage = signerl:sign(RawMessage, sha256, Key),
    % Change actual content to avoid being normalized away by XML parsing.
    Modified = binary:replace(SignedMessage, <<"Gatsby">>, <<"Gatzby">>, []),
    ?assertEqual(false, signerl:verify(Modified, sha256, PublicKey)).

verify_fails_on_modified_signing_time(Config) ->
    RawMessage = ?config(raw_message, Config),
    Key = ?config(rsa_key, Config),
    PublicKey = ?config(rsa_public_key, Config),

    SignedMessage = signerl:sign(RawMessage, sha256, Key),
    {ok, ParsedSignedMessage} = signerl_xml:parse_binary(SignedMessage),
    {ok, #{signed_properties := #{signing_time := SigningTime}}} =
        signerl_verify:extract_signature_data(ParsedSignedMessage),
    Modified = binary:replace(SignedMessage, SigningTime, <<"2000-01-01T00:00:00Z">>, []),
    ?assertEqual(false, signerl:verify(Modified, sha256, PublicKey)).

verify_fails_with_wrong_keys(Config) ->
    RawMessage = ?config(raw_message, Config),
    SignKey = ?config(rsa_key, Config),
    WrongPublicKey = ?config(wrong_public_key, Config),
    EcdsaKey = ?config(ecdsa_key, Config),

    RsaSignedMessage = signerl:sign(RawMessage, sha256, SignKey),
    ?assertEqual(false, signerl:verify(RsaSignedMessage, sha256, WrongPublicKey)),
    EcdsaSignedMessage = signerl:sign(RawMessage, sha256, EcdsaKey),
    % Wrong key type (RSA key against ECDSA signature) must fail verification.
    ?assertEqual(false, signerl:verify(EcdsaSignedMessage, sha256, WrongPublicKey)).

verify_returns_error_with_unsupported_hash(Config) ->
    PublicKey = ?config(rsa_public_key, Config),
    RsaKey = ?config(rsa_key, Config),
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),
    SignedMessage = signerl:sign(RawMessage, sha256, RsaKey),
    ?assertEqual(
        {error, invalid_signature_structure}, signerl:verify(SignedMessage, sha512, PublicKey)
    ).

verify_returns_file_error_with_missing_signed_message_file(Config) ->
    PublicKey = ?config(rsa_public_key, Config),
    ?assertMatch(
        {error, {file_error, enoent}}, signerl:verify("nonexistent_signed.xml", sha256, PublicKey)
    ).

verify_returns_file_error_with_missing_key_file(Config) ->
    RsaKey = ?config(rsa_key, Config),
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),
    SignedMessage = signerl:sign(RawMessage, sha256, RsaKey),
    ?assertMatch(
        {error, {file_error, enoent}}, signerl:verify(SignedMessage, sha256, "nonexistent_key.pem")
    ).

verify_returns_error_with_invalid_pem_key_file(Config) ->
    RsaKey = ?config(rsa_key, Config),
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),
    SignedMessage = signerl:sign(RawMessage, sha256, RsaKey),
    InvalidPemPath = signerl_utils:file_path("test/examples/base/books.xml"),
    ?assertEqual({error, invalid_pem}, signerl:verify(SignedMessage, sha256, InvalidPemPath)).

extract_signature_returns_error_without_signature_element_direct(_Config) ->
    Message = signerl_xml:parse_file("test/examples/base/books.xml"),
    ?assertEqual({error, missing_signature}, signerl_verify:extract_signature_data(Message)).

extract_signature_data_returns_error_with_missing_c14n(Config) ->
    SignatureData = ?config(signature_data, Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = remove_c14n_from_signature(SignatureElement),
    Message = message_with_signature(BrokenSignature),
    ?assertEqual({error, invalid_signed_info}, signerl_verify:extract_signature_data(Message)).

verify_reference_digests_returns_error_with_invalid_c14n_algorithm(Config) ->
    SignatureData = ?config(signature_data, Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = replace_c14n_algorithm(SignatureElement, "invalid-c14n"),
    Message = message_with_signature(BrokenSignature),
    {ok, BrokenData} = signerl_verify:extract_signature_data(Message),
    ?assertEqual(
        {error, invalid_signature_structure},
        signerl_verify:verify_reference_digests(BrokenData, sha256)
    ).

verify_reference_digests_accepts_exc_c14n_algorithm(Config) ->
    %% Exc-C14N is a supported algorithm — verify_reference_digests should not error
    %% on the algorithm check (digests will mismatch since message was signed with c14n11).
    SignatureData = ?config(signature_data, Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    ExcSignature = replace_c14n_algorithm(
        SignatureElement, "http://www.w3.org/2001/10/xml-exc-c14n#"
    ),
    Message = message_with_signature(ExcSignature),
    {ok, ExcData} = signerl_verify:extract_signature_data(Message),
    Result = signerl_verify:verify_reference_digests(ExcData, sha256),
    %% Should return false (digest mismatch) not {error, ...} since exc_c14n is valid
    ?assertEqual(false, Result).

verify_reference_digests_returns_error_with_invalid_signature_method_algorithm(Config) ->
    SignatureData = ?config(signature_data, Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = replace_signature_method_algorithm(
        SignatureElement, "invalid-signature-method"
    ),
    Message = message_with_signature(BrokenSignature),
    {ok, BrokenData} = signerl_verify:extract_signature_data(Message),
    ?assertEqual(
        {error, invalid_signature_structure},
        signerl_verify:verify_reference_digests(BrokenData, sha256)
    ).

extract_signature_data_returns_error_with_missing_reference_uri(Config) ->
    SignatureData = ?config(signature_data, Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = remove_document_reference_uri(SignatureElement),
    Message = message_with_signature(BrokenSignature),
    ?assertEqual({error, invalid_signed_info}, signerl_verify:extract_signature_data(Message)).

extract_signature_data_returns_error_with_invalid_reference_payload(Config) ->
    SignatureData = ?config(signature_data, Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = remove_document_reference_digest_value(SignatureElement),
    Message = message_with_signature(BrokenSignature),
    ?assertEqual({error, invalid_signed_info}, signerl_verify:extract_signature_data(Message)).

verify_reference_digests_returns_error_with_missing_document_transforms(Config) ->
    SignatureData = ?config(signature_data, Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = remove_document_reference_transforms(SignatureElement),
    Message = message_with_signature(BrokenSignature),
    {ok, BrokenData} = signerl_verify:extract_signature_data(Message),
    ?assertEqual(
        {error, invalid_signature_structure},
        signerl_verify:verify_reference_digests(BrokenData, sha256)
    ).

verify_reference_digests_returns_error_with_invalid_document_transform_algorithm(Config) ->
    SignatureData = ?config(signature_data, Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature =
        replace_document_reference_transform_algorithm(SignatureElement, "invalid-transform"),
    Message = message_with_signature(BrokenSignature),
    {ok, BrokenData} = signerl_verify:extract_signature_data(Message),
    ?assertEqual(
        {error, invalid_signature_structure},
        signerl_verify:verify_reference_digests(BrokenData, sha256)
    ).

verify_reference_digests_returns_error_with_transform_without_algorithm(Config) ->
    SignatureData = ?config(signature_data, Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = replace_document_transforms(SignatureElement, [{'ds:Transform', [], []}]),
    Message = message_with_signature(BrokenSignature),
    ?assertEqual({error, invalid_signed_info}, signerl_verify:extract_signature_data(Message)).

verify_reference_digests_returns_error_with_invalid_transform_element(Config) ->
    SignatureData = ?config(signature_data, Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature =
        replace_document_transforms(SignatureElement, [{'ds:InvalidTransform', [], []}]),
    Message = message_with_signature(BrokenSignature),
    ?assertEqual({error, invalid_signed_info}, signerl_verify:extract_signature_data(Message)).

extract_signature_data_handles_duplicate_signed_properties_type_attribute(Config) ->
    SignatureData = ?config(signature_data, Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = duplicate_signed_properties_type_attr(SignatureElement),
    Message = message_with_signature(BrokenSignature),
    {ok, BrokenData} = signerl_verify:extract_signature_data(Message),
    ?assertEqual(
        false, signerl_verify:verify_reference_digests(BrokenData, sha256)
    ).

verify_reference_digests_returns_error_with_missing_signed_properties_element(Config) ->
    SignatureData = ?config(signature_data, Config),
    SignatureElement = maps:get(signature_element, SignatureData),
    BrokenSignature = remove_signed_properties_from_signature(SignatureElement),
    BrokenData = maps:put(signature_element, BrokenSignature, SignatureData),
    ?assertEqual(
        {error, invalid_signature_structure},
        signerl_verify:verify_reference_digests(BrokenData, sha256)
    ).

verify_reference_digests_returns_error_with_invalid_document_reference(Config) ->
    SignatureData = ?config(signature_data, Config),
    References = maps:get(references, SignatureData),
    DocumentReference = maps:get(document, References),
    BrokenDocumentReference = maps:put(uri, "invalid", DocumentReference),
    BrokenReferences = maps:put(document, BrokenDocumentReference, References),
    BrokenData = maps:put(references, BrokenReferences, SignatureData),
    ?assertEqual(
        {error, invalid_signature_structure},
        signerl_verify:verify_reference_digests(BrokenData, sha256)
    ).

verify_reference_digests_returns_error_with_invalid_signed_properties_reference(Config) ->
    SignatureData = ?config(signature_data, Config),
    References = maps:get(references, SignatureData),
    SignedPropertiesReference = maps:get(signed_properties, References),
    BrokenSignedPropertiesReference = maps:put(type, undefined, SignedPropertiesReference),
    BrokenReferences = maps:put(signed_properties, BrokenSignedPropertiesReference, References),
    BrokenData = maps:put(references, BrokenReferences, SignatureData),
    ?assertEqual(
        {error, invalid_signature_structure},
        signerl_verify:verify_reference_digests(BrokenData, sha256)
    ).

verify_reference_digests_returns_error_with_invalid_signature_data(_Config) ->
    ?assertEqual(
        {error, invalid_signature_structure}, signerl_verify:verify_reference_digests(#{}, sha256)
    ).

xades_xml_returns_error_with_non_signature_input(_Config) ->
    InvalidElement = {'root', [], []},
    ?assertEqual(
        {error, missing_element},
        signerl_xades_xml:find_signed_signature_properties(InvalidElement)
    ),
    ?assertEqual(
        {error, missing_element},
        signerl_xades_xml:find_signed_properties_element(InvalidElement)
    ).

%%%%%%%%%%%%%%%%%%%%%%%
%%% KEYINFO GROUP TESTS
%%%%%%%%%%%%%%%%%%%%%%%

sign_with_certificate_includes_keyinfo(Config) ->
    RawMessage = ?config(raw_message, Config),
    RsaKey = ?config(rsa_key, Config),
    RsaCertDer = ?config(rsa_cert_der, Config),
    SignedMessage = signerl:sign(RawMessage, sha256, RsaKey, RsaCertDer),
    {ok, Parsed} = signerl_xml:parse_binary(SignedMessage),
    ?assertMatch(
        {ok, {'ds:KeyInfo', _, _}},
        signerl_xml:find_path(['ds:Signature', 'ds:KeyInfo'], Parsed)
    ),
    ?assertMatch(
        {ok, {'ds:X509Certificate', _, [_]}},
        signerl_xml:find_path(
            ['ds:Signature', 'ds:KeyInfo', 'ds:X509Data', 'ds:X509Certificate'], Parsed
        )
    ).

sign_without_certificate_omits_keyinfo(Config) ->
    RawMessage = ?config(raw_message, Config),
    RsaKey = ?config(rsa_key, Config),
    SignedMessage = signerl:sign(RawMessage, sha256, RsaKey),
    {ok, Parsed} = signerl_xml:parse_binary(SignedMessage),
    ?assertEqual(
        {error, not_found},
        signerl_xml:find_path(['ds:Signature', 'ds:KeyInfo'], Parsed)
    ).

sign_with_certificate_roundtrip_rsa(Config) ->
    RawMessage = ?config(raw_message, Config),
    RsaKey = ?config(rsa_key, Config),
    RsaCertDer = ?config(rsa_cert_der, Config),
    RsaPublicKey = ?config(rsa_public_key, Config),
    SignedMessage = signerl:sign(RawMessage, sha256, RsaKey, RsaCertDer),
    ?assertEqual(true, signerl:verify(SignedMessage, sha256, RsaPublicKey)).

sign_with_certificate_roundtrip_ecdsa(Config) ->
    RawMessage = ?config(raw_message, Config),
    EcdsaKey = ?config(ecdsa_key, Config),
    EcdsaCertDer = ?config(ecdsa_cert_der, Config),
    EcdsaPublicKey = ?config(ecdsa_public_key, Config),
    SignedMessage = signerl:sign(RawMessage, sha256, EcdsaKey, EcdsaCertDer),
    ?assertEqual(true, signerl:verify(SignedMessage, sha256, EcdsaPublicKey)).

verify_extracts_certificate_from_keyinfo(Config) ->
    RawMessage = ?config(raw_message, Config),
    RsaKey = ?config(rsa_key, Config),
    RsaCertDer = ?config(rsa_cert_der, Config),
    SignedMessage = signerl:sign(RawMessage, sha256, RsaKey, RsaCertDer),
    {ok, Parsed} = signerl_xml:parse_binary(SignedMessage),
    {ok, #{key_info := KeyInfo}} = signerl_verify:extract_signature_data(Parsed),
    ?assertMatch(#{x509_certificate := RsaCertDer}, KeyInfo).

sign_with_certificate_from_key_file(Config) ->
    RawMessage = ?config(raw_message, Config),
    RsaKeyPath = ?config(rsa_key_path, Config),
    RsaCertDer = ?config(rsa_cert_der, Config),
    RsaPublicKey = ?config(rsa_public_key, Config),
    SignedMessage = signerl:sign(RawMessage, sha256, RsaKeyPath, RsaCertDer),
    ?assertEqual(true, signerl:verify(SignedMessage, sha256, RsaPublicKey)).

sign_with_certificate_from_message_file(Config) ->
    MessagePath = ?config(message_path, Config),
    RsaKey = ?config(rsa_key, Config),
    RsaCertDer = ?config(rsa_cert_der, Config),
    RsaPublicKey = ?config(rsa_public_key, Config),
    SignedMessage = signerl:sign(MessagePath, sha256, RsaKey, RsaCertDer),
    ?assertEqual(true, signerl:verify(SignedMessage, sha256, RsaPublicKey)).

verify_extracts_no_keyinfo_when_absent(Config) ->
    RawMessage = ?config(raw_message, Config),
    RsaKey = ?config(rsa_key, Config),
    SignedMessage = signerl:sign(RawMessage, sha256, RsaKey),
    {ok, Parsed} = signerl_xml:parse_binary(SignedMessage),
    {ok, #{key_info := KeyInfo}} = signerl_verify:extract_signature_data(Parsed),
    ?assertEqual(undefined, KeyInfo).

%%%%%%%%%%%%%%%%%%%%%%%
%%% INTEROP SMOKE GROUP TESTS
%%%%%%%%%%%%%%%%%%%%%%%

c14n_idempotent_after_sign(Config) ->
    RawMessage = ?config(raw_message, Config),
    RsaKey = ?config(rsa_key, Config),
    SignedMessage = signerl:sign(RawMessage, sha256, RsaKey),
    {ok, ParsedSigned} = signerl_xml:parse_binary(SignedMessage),
    {ok, SignedInfoElement} = signerl_xml:find_path(
        ['ds:Signature', 'ds:SignedInfo'], ParsedSigned
    ),
    C14N1 = signerl_c14n:canonicalize(SignedInfoElement),
    {ok, ReParsed} = signerl_xml:parse_binary(C14N1),
    C14N2 = signerl_c14n:canonicalize(ReParsed),
    ?assertEqual(C14N1, C14N2).

is_signature_element_shared(_Config) ->
    SigElement = {'ds:Signature', [], []},
    NonSigElement = {'ds:SignedInfo', [], []},
    ?assertEqual(true, signerl_xml:is_signature_element(SigElement)),
    ?assertEqual(false, signerl_xml:is_signature_element(NonSigElement)),
    ?assertEqual(false, signerl_xml:is_signature_element("text")).

compute_valid_signature_data() ->
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

c14n_mode_returns_exc_for_exc_c14n_algorithm(_Config) ->
    SigData = #{references => #{c14n_algorithm => "http://www.w3.org/2001/10/xml-exc-c14n#"}},
    ?assertEqual(exc_c14n, signerl_verify:c14n_mode(SigData)),
    SigDataC14N11 = #{references => #{c14n_algorithm => "http://www.w3.org/2006/12/xml-c14n11"}},
    ?assertEqual(c14n11, signerl_verify:c14n_mode(SigDataC14N11)).

extract_x509_certificate_returns_undefined_for_invalid_cert(_Config) ->
    %% Sign a message with certificate, then corrupt the cert to test error paths.
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),
    RsaKey = signerl_cert_helpers:signer_rsa_key(),
    RsaCertDer = test_helpers:cert_der(signerl_cert_helpers:signer_rsa_cert_path()),
    SignedMessage = signerl:sign(RawMessage, sha256, RsaKey, RsaCertDer),
    {ok, Parsed} = signerl_xml:parse_binary(SignedMessage),
    %% Test 1: Corrupt cert to invalid structure (multiple children → _ catch-all)
    CorruptedStructure = corrupt_x509_certificate(Parsed, [<<"binary">>, <<"extra">>]),
    {ok, #{key_info := KeyInfo1}} = signerl_verify:extract_signature_data(CorruptedStructure),
    ?assertEqual(undefined, KeyInfo1),
    %% Test 2: Corrupt cert to invalid base64 (single list child → decode error)
    CorruptedBase64 = corrupt_x509_certificate(Parsed, ["!!!not-base64!!!"]),
    {ok, #{key_info := KeyInfo2}} = signerl_verify:extract_signature_data(CorruptedBase64),
    ?assertEqual(undefined, KeyInfo2).

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

%% xml_utils_group tests

export_fragment_returns_binary(_Config) ->
    Element = {tag, [], ["content"]},
    Result = signerl_xml:export_fragment(Element),
    ?assert(is_binary(Result)),
    ?assertNotEqual(<<>>, Result).

to_file_writes_and_reads_back(Config) ->
    PrivDir = ?config(priv_dir, Config),
    OutPath = filename:join(PrivDir, "to_file_test.xml"),
    Prolog = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"],
    Root = signerl_xml:parse_file("test/examples/base/books.xml"),
    Binary = signerl_xml:export(Prolog, Root),
    ok = signerl_xml:to_file(OutPath, Binary),
    ReadBack = signerl_xml:parse_file(OutPath),
    ?assertEqual(Root, ReadBack).

parse_prolog_rejects_bom(_Config) ->
    Message = <<16#EF, 16#BB, 16#BF, "<?xml version=\"1.0\" encoding=\"UTF-8\"?><root/>">>,
    ?assertEqual({error, invalid_prolog}, signerl_xml:parse_prolog(Message)).

single_text_returns_binary_and_list(_Config) ->
    ?assertEqual({ok, <<"abc">>}, signerl_xml:single_text({tag, [], [<<"abc">>]})),
    ?assertEqual({ok, <<"abc">>}, signerl_xml:single_text({tag, [], ["abc"]})).

single_text_returns_not_found(_Config) ->
    ?assertEqual({error, not_found}, signerl_xml:single_text({tag, [], []})),
    ?assertEqual({error, not_found}, signerl_xml:single_text({tag, [], ["a", "b"]})).
