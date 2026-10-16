-module(signerl_api_SUITE).

-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").
-compile([export_all, nowarn_export_all]).
-include("signerl_dsig.hrl").

suite() ->
    [{timetrap, {seconds, 30}}].

all() ->
    [
        {group, sign_group},
        {group, verify_fixture_error_group},
        {group, verify_tamper_group},
        {group, keyinfo_group},
        {group, interop_smoke_group}
    ].

groups() ->
    [
        {sign_group, [], [
            sign,
            sign_with_chain_leaf_rsa,
            sign_with_self_signed_rsa,
            sign_with_self_signed_ecdsa,
            sign_deterministic,
            sign_with_controlled_time_files_and_certificate,
            sign_rejects_invalid_controlled_time,
            sign_utf8_binary_and_file,
            sign_preserves_content,
            processing_instructions_are_rejected,
            complete_document_accepts_trailing_misc,
            complete_document_rejects_trailing_content,
            complete_document_file_boundary,
            dtd_is_rejected_by_public_apis,
            dtd_file_input_is_rejected,
            reject_unsupported_encoding,
            reject_invalid_utf8,
            relative_namespace_returns_invalid_xml,
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
            verify_extracts_no_keyinfo_when_absent,
            sign_with_certificate_includes_signing_certificate_v2,
            sign_without_certificate_omits_signing_certificate_v2,
            sign_with_certificate_extracts_cert_digest,
            verify_fails_with_tampered_cert_digest,
            verify_succeeds_with_cert_v2_but_no_keyinfo_cert,
            verify_fails_with_mismatched_cert_digest_method
        ]},
        {interop_smoke_group, [], [
            verify_independent_c14n11_signature,
            verify_independent_exc_c14n_signature,
            verify_inherited_c14n11_signature,
            verify_inherited_exc_c14n_signature,
            verify_namespace_alias_and_default_signatures,
            sign_with_ancestor_namespace_context,
            c14n_idempotent_after_sign
        ]}
    ].

init_per_group(sign_group, Config) ->
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),
    RsaKey = signerl_cert_helpers:signer_rsa_key(),
    EcdsaKey = signerl_cert_helpers:signer_ecdsa_key(),
    LeafKey = signerl_cert_helpers:leaf_key(),
    RsaPublicKey = signerl_cert_helpers:rsa_public_key_from_cert(
        signerl_cert_helpers:signer_rsa_cert_path()
    ),
    EcdsaPublicKey = signerl_cert_helpers:ecdsa_public_key_from_cert(
        signerl_cert_helpers:signer_ecdsa_cert_path()
    ),
    LeafPublicKey = signerl_cert_helpers:rsa_public_key_from_cert(
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
init_per_group(Group, Config) when
    Group =:= verify_fixture_error_group; Group =:= interop_smoke_group
->
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),
    RsaKey = signerl_cert_helpers:signer_rsa_key(),
    RsaPublicKey = signerl_cert_helpers:rsa_public_key_from_cert(
        signerl_cert_helpers:signer_rsa_cert_path()
    ),
    [{raw_message, RawMessage}, {rsa_key, RsaKey}, {rsa_public_key, RsaPublicKey} | Config];
init_per_group(verify_tamper_group, Config) ->
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),
    RsaKey = signerl_cert_helpers:signer_rsa_key(),
    EcdsaKey = signerl_cert_helpers:signer_ecdsa_key(),
    RsaPublicKey = signerl_cert_helpers:rsa_public_key_from_cert(
        signerl_cert_helpers:signer_rsa_cert_path()
    ),
    EcdsaPublicKey = signerl_cert_helpers:ecdsa_public_key_from_cert(
        signerl_cert_helpers:signer_ecdsa_cert_path()
    ),
    WrongPublicKey = signerl_cert_helpers:rsa_public_key_from_cert(
        signerl_cert_helpers:leaf_cert_path()
    ),
    [
        {raw_message, RawMessage},
        {rsa_key, RsaKey},
        {ecdsa_key, EcdsaKey},
        {rsa_public_key, RsaPublicKey},
        {ecdsa_public_key, EcdsaPublicKey},
        {wrong_public_key, WrongPublicKey}
        | Config
    ];
init_per_group(keyinfo_group, Config) ->
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),
    RsaKey = signerl_cert_helpers:signer_rsa_key(),
    EcdsaKey = signerl_cert_helpers:signer_ecdsa_key(),
    RsaCertDer = signerl_cert_helpers:cert_der(signerl_cert_helpers:signer_rsa_cert_path()),
    EcdsaCertDer = signerl_cert_helpers:cert_der(signerl_cert_helpers:signer_ecdsa_cert_path()),
    RsaPublicKey = signerl_cert_helpers:rsa_public_key(RsaCertDer),
    EcdsaPublicKey = signerl_cert_helpers:ecdsa_public_key(EcdsaCertDer),
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
init_per_group(_, Config) ->
    Config.

end_per_group(_, _Config) ->
    ok.

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

    PublicKey = ?config(rsa_public_key, Config),
    Time = <<"2000-02-29T03:04:05Z">>,
    SignedMessage1 = signerl:sign(RawMessage, sha256, Key, undefined, Time),
    SignedMessage2 = signerl:sign(RawMessage, sha256, Key, undefined, Time),
    ?assertEqual(SignedMessage1, SignedMessage2),
    test_helpers:parse_verified_message(SignedMessage1, PublicKey),
    Changed = signerl:sign(RawMessage, sha256, Key, undefined, <<"2000-02-29T03:04:06Z">>),
    ?assertNotEqual(SignedMessage1, Changed),
    test_helpers:parse_verified_message(Changed, PublicKey).

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
    test_helpers:parse_verified_message(SignedMessage, PublicKey),
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

verify_returns_error_with_unsupported_hash(Config) ->
    PublicKey = ?config(rsa_public_key, Config),
    RsaKey = ?config(rsa_key, Config),
    RawMessage = ?config(raw_message, Config),
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
    RawMessage = ?config(raw_message, Config),
    SignedMessage = signerl:sign(RawMessage, sha256, RsaKey),
    ?assertMatch(
        {error, {file_error, enoent}}, signerl:verify(SignedMessage, sha256, "nonexistent_key.pem")
    ).

verify_returns_error_with_invalid_pem_key_file(Config) ->
    RsaKey = ?config(rsa_key, Config),
    RawMessage = ?config(raw_message, Config),
    SignedMessage = signerl:sign(RawMessage, sha256, RsaKey),
    InvalidPemPath = signerl_utils:file_path("test/examples/base/books.xml"),
    ?assertEqual({error, invalid_pem}, signerl:verify(SignedMessage, sha256, InvalidPemPath)).

verify_returns_false_with_wrong_signature_value(Config) ->
    RawMessage = ?config(raw_message, Config),
    Key = ?config(rsa_key, Config),
    PublicKey = ?config(rsa_public_key, Config),

    SignedMessage = signerl:sign(RawMessage, sha256, Key),
    ParsedSignedMessage = test_helpers:parse_verified_message(SignedMessage, PublicKey),
    {ok, SignatureData} = signerl_verify:extract_signature_data(ParsedSignedMessage),
    SignatureBytes = maps:get(signature_bytes, SignatureData),
    <<FirstByte, Rest/binary>> = SignatureBytes,
    CorruptedSignatureBytes = <<((FirstByte + 1) band 16#FF), Rest/binary>>,
    SignatureValue = base64:encode(SignatureBytes),
    CorruptedSignatureValue = base64:encode(CorruptedSignatureBytes),
    Corrupted = test_helpers:replace_once(SignedMessage, SignatureValue, CorruptedSignatureValue),
    ?assertEqual(false, signerl:verify(Corrupted, sha256, PublicKey)).

verify_fails_on_modified_message(Config) ->
    RawMessage = ?config(raw_message, Config),
    Key = ?config(rsa_key, Config),
    PublicKey = ?config(rsa_public_key, Config),

    SignedMessage = signerl:sign(RawMessage, sha256, Key),
    test_helpers:parse_verified_message(SignedMessage, PublicKey),
    % Change actual content to avoid being normalized away by XML parsing.
    Modified = test_helpers:replace_once(SignedMessage, <<"Gatsby">>, <<"Gatzby">>),
    ?assertEqual(false, signerl:verify(Modified, sha256, PublicKey)).

verify_fails_on_modified_signing_time(Config) ->
    RawMessage = ?config(raw_message, Config),
    Key = ?config(rsa_key, Config),
    PublicKey = ?config(rsa_public_key, Config),

    SignedMessage = signerl:sign(RawMessage, sha256, Key),
    ParsedSignedMessage = test_helpers:parse_verified_message(SignedMessage, PublicKey),
    {ok, #{signed_properties := #{signing_time := SigningTime}}} =
        signerl_verify:extract_signature_data(ParsedSignedMessage),
    Modified = test_helpers:replace_once(SignedMessage, SigningTime, <<"2000-01-01T00:00:00Z">>),
    ?assertEqual(false, signerl:verify(Modified, sha256, PublicKey)).

verify_fails_with_wrong_keys(Config) ->
    RawMessage = ?config(raw_message, Config),
    SignKey = ?config(rsa_key, Config),
    WrongPublicKey = ?config(wrong_public_key, Config),
    EcdsaKey = ?config(ecdsa_key, Config),

    RsaSignedMessage = signerl:sign(RawMessage, sha256, SignKey),
    test_helpers:parse_verified_message(RsaSignedMessage, ?config(rsa_public_key, Config)),
    ?assertEqual(false, signerl:verify(RsaSignedMessage, sha256, WrongPublicKey)),
    EcdsaSignedMessage = signerl:sign(RawMessage, sha256, EcdsaKey),
    test_helpers:parse_verified_message(EcdsaSignedMessage, ?config(ecdsa_public_key, Config)),
    % Wrong key type (RSA key against ECDSA signature) must fail verification.
    ?assertEqual(false, signerl:verify(EcdsaSignedMessage, sha256, WrongPublicKey)).

sign_with_certificate_includes_keyinfo(Config) ->
    RawMessage = ?config(raw_message, Config),
    RsaKey = ?config(rsa_key, Config),
    RsaCertDer = ?config(rsa_cert_der, Config),
    SignedMessage = signerl:sign(RawMessage, sha256, RsaKey, RsaCertDer),
    {ok, Parsed} = xmlan:parse_binary(SignedMessage),
    ?assertMatch(
        {ok, {<<"ds:KeyInfo">>, _, _}},
        xmlan:find_path([<<"ds:Signature">>, <<"ds:KeyInfo">>], Parsed)
    ),
    ?assertMatch(
        {ok, {<<"ds:X509Certificate">>, _, [_]}},
        xmlan:find_path(
            [<<"ds:Signature">>, <<"ds:KeyInfo">>, <<"ds:X509Data">>, <<"ds:X509Certificate">>],
            Parsed
        )
    ).

sign_without_certificate_omits_keyinfo(Config) ->
    RawMessage = ?config(raw_message, Config),
    RsaKey = ?config(rsa_key, Config),
    SignedMessage = signerl:sign(RawMessage, sha256, RsaKey),
    {ok, Parsed} = xmlan:parse_binary(SignedMessage),
    ?assertEqual(
        {error, not_found},
        xmlan:find_path([<<"ds:Signature">>, <<"ds:KeyInfo">>], Parsed)
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

verify_extracts_certificate_from_keyinfo(Config) ->
    RawMessage = ?config(raw_message, Config),
    RsaKey = ?config(rsa_key, Config),
    RsaCertDer = ?config(rsa_cert_der, Config),
    SignedMessage = signerl:sign(RawMessage, sha256, RsaKey, RsaCertDer),
    {ok, Parsed} = xmlan:parse_binary(SignedMessage),
    {ok, #{key_info := KeyInfo}} = signerl_verify:extract_signature_data(Parsed),
    ?assertMatch(#{x509_certificate := RsaCertDer}, KeyInfo).

verify_extracts_no_keyinfo_when_absent(Config) ->
    RawMessage = ?config(raw_message, Config),
    RsaKey = ?config(rsa_key, Config),
    SignedMessage = signerl:sign(RawMessage, sha256, RsaKey),
    {ok, Parsed} = xmlan:parse_binary(SignedMessage),
    {ok, #{key_info := KeyInfo}} = signerl_verify:extract_signature_data(Parsed),
    ?assertEqual(undefined, KeyInfo).

sign_with_certificate_includes_signing_certificate_v2(Config) ->
    RawMessage = ?config(raw_message, Config),
    RsaKey = ?config(rsa_key, Config),
    RsaCertDer = ?config(rsa_cert_der, Config),
    SignedMessage = signerl:sign(RawMessage, sha256, RsaKey, RsaCertDer),
    {ok, Parsed} = xmlan:parse_binary(SignedMessage),
    ?assertMatch(
        {ok, {<<"xades:SigningCertificateV2">>, _, _}},
        xmlan:find_path(signing_certificate_v2_path(), Parsed)
    ).

sign_without_certificate_omits_signing_certificate_v2(Config) ->
    RawMessage = ?config(raw_message, Config),
    RsaKey = ?config(rsa_key, Config),
    SignedMessage = signerl:sign(RawMessage, sha256, RsaKey),
    {ok, Parsed} = xmlan:parse_binary(SignedMessage),
    ?assertEqual(
        {error, not_found},
        xmlan:find_path(signing_certificate_v2_path(), Parsed)
    ).

sign_with_certificate_extracts_cert_digest(Config) ->
    RawMessage = ?config(raw_message, Config),
    RsaKey = ?config(rsa_key, Config),
    RsaCertDer = ?config(rsa_cert_der, Config),
    SignedMessage = signerl:sign(RawMessage, sha256, RsaKey, RsaCertDer),
    {ok, Parsed} = xmlan:parse_binary(SignedMessage),
    {ok, #{signed_properties := SignedProps}} = signerl_verify:extract_signature_data(Parsed),
    #{signing_certificate_v2 := CertV2} = SignedProps,
    ExpectedDigest = crypto:hash(sha256, RsaCertDer),
    ?assertEqual(ExpectedDigest, maps:get(digest_value, CertV2)),
    ?assertEqual("http://www.w3.org/2001/04/xmlenc#sha256", maps:get(digest_method, CertV2)),
    ?assert(maps:is_key(issuer_serial_v2, CertV2)).

verify_fails_with_tampered_cert_digest(Config) ->
    RawMessage = ?config(raw_message, Config),
    RsaKey = ?config(rsa_key, Config),
    RsaCertDer = ?config(rsa_cert_der, Config),
    RsaPublicKey = ?config(rsa_public_key, Config),
    SignedMessage = signerl:sign(RawMessage, sha256, RsaKey, RsaCertDer),
    test_helpers:parse_verified_message(SignedMessage, RsaPublicKey),
    %% Tamper with the cert digest by replacing the certificate in KeyInfo
    %% with a different one. The cert digest in SignedProperties won't match.
    EcdsaCertDer = ?config(ecdsa_cert_der, Config),
    TamperedMessage = tamper_keyinfo_certificate(SignedMessage, EcdsaCertDer),
    ?assertNotEqual(SignedMessage, TamperedMessage),
    ?assertEqual(
        {error, cert_digest_mismatch},
        signerl:verify(TamperedMessage, sha256, RsaPublicKey)
    ).

verify_succeeds_with_cert_v2_but_no_keyinfo_cert(Config) ->
    RawMessage = ?config(raw_message, Config),
    RsaKey = ?config(rsa_key, Config),
    RsaCertDer = ?config(rsa_cert_der, Config),
    RsaPublicKey = ?config(rsa_public_key, Config),
    SignedMessage = signerl:sign(RawMessage, sha256, RsaKey, RsaCertDer),
    test_helpers:parse_verified_message(SignedMessage, RsaPublicKey),
    %% Remove the X509Certificate element from KeyInfo while keeping
    %% SigningCertificateV2 — verify should still succeed
    StrippedMessage = strip_keyinfo_certificate(SignedMessage),
    ?assertNotEqual(SignedMessage, StrippedMessage),
    ?assertEqual(true, signerl:verify(StrippedMessage, sha256, RsaPublicKey)).

verify_fails_with_mismatched_cert_digest_method(Config) ->
    RawMessage = ?config(raw_message, Config),
    RsaKey = ?config(rsa_key, Config),
    RsaCertDer = ?config(rsa_cert_der, Config),
    RsaPublicKey = ?config(rsa_public_key, Config),
    SignedMessage = signerl:sign(RawMessage, sha256, RsaKey, RsaCertDer),
    test_helpers:parse_verified_message(SignedMessage, RsaPublicKey),
    %% Tamper with the DigestMethod URI inside SigningCertificateV2
    TamperedMessage = tamper_cert_digest_method(SignedMessage),
    ?assertNotEqual(SignedMessage, TamperedMessage),
    ?assertEqual(
        {error, cert_digest_mismatch},
        signerl:verify(TamperedMessage, sha256, RsaPublicKey)
    ).

verify_independent_c14n11_signature(_Config) ->
    verify_independent_signature("c14n11.xml", ?DSIG_C14N11_ALGO_URI).

verify_independent_exc_c14n_signature(_Config) ->
    verify_independent_signature("exclusive.xml", ?DSIG_EXC_C14N_ALGO_URI).

verify_inherited_c14n11_signature(_Config) ->
    verify_inherited_signature("c14n11.xml").

verify_inherited_exc_c14n_signature(_Config) ->
    verify_inherited_signature("exclusive.xml").

verify_inherited_signature(FileName) ->
    FixtureDir = signerl_utils:file_path("test/examples/independent"),
    {ok, Original} = file:read_file(filename:join(FixtureDir, FileName)),
    {ok, PublicKey} = signerl_utils:load_key_from_file(filename:join(FixtureDir, "rsa-public.pem")),
    test_helpers:parse_verified_message(Original, PublicKey),
    WithoutSignedInfoDecl = test_helpers:replace_once(
        Original,
        <<"<ds:SignedInfo xmlns:ds=\"", ?DSIG_NAMESPACE_URI, "\"">>,
        <<"<ds:SignedInfo">>
    ),
    Inherited = test_helpers:replace_once(
        WithoutSignedInfoDecl,
        <<"<xades:SignedProperties xmlns:ds=\"", ?DSIG_NAMESPACE_URI, "\" xmlns:xades=\"",
            ?XADES_NAMESPACE_URI, "\"">>,
        <<"<xades:SignedProperties">>
    ),
    %% The digests and RSA signature are still the independent xmlsec1 values.
    test_helpers:parse_verified_message(Inherited, PublicKey).

verify_namespace_alias_and_default_signatures(Config) ->
    Key = ?config(rsa_key, Config),
    PublicKey = ?config(rsa_public_key, Config),
    lists:foreach(
        fun(Mode) ->
            Signed = namespace_signature_fixture(Mode, Key),
            test_helpers:parse_verified_message(Signed, PublicKey),
            ChangedAmount = test_helpers:replace_once(Signed, <<"42.00">>, <<"43.00">>),
            ?assertEqual(false, signerl:verify(ChangedAmount, sha256, PublicKey)),
            {Ds, _, Declaration, _, _} = namespace_fixture_names(Mode),
            WrongDeclaration = binary:replace(
                Declaration, <<?DSIG_NAMESPACE_URI>>, <<"urn:application:signature">>
            ),
            ChangedNamespace = test_helpers:replace_once(
                Signed,
                <<"<", Ds/binary, "Signature", Declaration/binary>>,
                <<"<", Ds/binary, "Signature", WrongDeclaration/binary>>
            ),
            ?assertEqual(
                {error, missing_signature}, signerl:verify(ChangedNamespace, sha256, PublicKey)
            )
        end,
        [prefixed, default]
    ).

sign_with_ancestor_namespace_context(Config) ->
    Key = ?config(rsa_key, Config),
    PublicKey = ?config(rsa_public_key, Config),
    Cert = signerl_cert_helpers:cert_der(signerl_cert_helpers:signer_rsa_cert_path()),
    Raw = <<
        "<?xml version='1.0'?><invoice xmlns=\"urn:invoice\" "
        "xmlns:unused=\"urn:unused\" xmlns:ds=\"urn:application:ds\" "
        "xmlns:xades=\"urn:application:xades\"><ds:record xades:status=\"draft\">"
        "<amount>42.00</amount></ds:record></invoice>"
    >>,
    {ok, Original} = xmlan:parse_binary(Raw),
    Signed = signerl:sign(Raw, sha256, Key, Cert),
    Parsed = test_helpers:parse_verified_message(Signed, PublicKey),
    ?assertEqual(Original, signerl_c14n:remove_signature_elements(Parsed)),
    {ok, SignatureData} = signerl_verify:extract_signature_data(Parsed),
    #{signature_bytes := SignatureBytes, signature_element := SignatureElement} = SignatureData,
    {ok, SignedInfo} = xmlan:find_path([<<"ds:SignedInfo">>], SignatureElement),
    ExpectedSignedInfo = fragment_with_bindings(SignedInfo, [
        {<<"xmlns">>, "urn:invoice"},
        {<<"xmlns:unused">>, "urn:unused"},
        {<<"xmlns:ds">>, ?DSIG_NAMESPACE_URI},
        {<<"xmlns:xades">>, "urn:application:xades"}
    ]),
    SignedInfoBytes = xmlan_c14n:canonicalize(ExpectedSignedInfo),
    ?assertEqual(
        SignedInfoBytes, xmlan_c14n:canonicalize(maps:get(signed_info_element, SignatureData))
    ),
    ?assertEqual(true, public_key:verify(SignedInfoBytes, sha256, SignatureBytes, PublicKey)),
    {ok, SignedProperties} = xmlan:find_path(
        [<<"ds:Object">>, <<"xades:QualifyingProperties">>, <<"xades:SignedProperties">>],
        SignatureElement
    ),
    ExpectedSignedProperties = fragment_with_bindings(SignedProperties, [
        {<<"xmlns">>, "urn:invoice"},
        {<<"xmlns:unused">>, "urn:unused"},
        {<<"xmlns:ds">>, ?DSIG_NAMESPACE_URI},
        {<<"xmlns:xades">>, ?XADES_NAMESPACE_URI}
    ]),
    SignedPropertiesBytes = xmlan_c14n:canonicalize(ExpectedSignedProperties),
    #{references := #{signed_properties := #{digest_value := SignedPropertiesDigest}}} =
        SignatureData,
    ?assertEqual(crypto:hash(sha256, SignedPropertiesBytes), SignedPropertiesDigest),
    {ok, ContextualProperties} = signerl_xades_xml:find_signed_properties_element(SignatureElement),
    ?assertEqual(SignedPropertiesBytes, xmlan_c14n:canonicalize(ContextualProperties)).

fragment_with_bindings({Name, Attrs, Children}, Bindings) ->
    ContextAttrs = lists:foldl(
        fun({Key, _} = Binding, Acc) -> lists:keystore(Key, 1, Acc, Binding) end,
        Attrs,
        Bindings
    ),
    {Name, ContextAttrs, Children}.

%% A fixed profile with hand-supplied canonical XML. SignErl does not compute
%% these reference digests, canonical bytes, or signature values.
namespace_signature_fixture(Mode, Key) ->
    {Ds, Xades, SignatureDecl, PropertiesDecl, PropertiesContext} = namespace_fixture_names(Mode),
    Message = <<"<invoice Id=\"invoice-1\"><amount currency=\"EUR\">42.00</amount></invoice>">>,
    PropertiesContent =
        <<"<", Xades/binary, "SignedSignatureProperties><", Xades/binary,
            "SigningTime>2026-01-01T00:00:00Z</", Xades/binary, "SigningTime></", Xades/binary,
            "SignedSignatureProperties>">>,
    Properties =
        <<"<", Xades/binary, "SignedProperties Id=\"SignedProperties-1\">",
            PropertiesContent/binary, "</", Xades/binary, "SignedProperties>">>,
    CanonicalProperties =
        <<"<", Xades/binary, "SignedProperties", PropertiesContext/binary,
            " Id=\"SignedProperties-1\">", PropertiesContent/binary, "</", Xades/binary,
            "SignedProperties>">>,
    MessageDigest = base64:encode(crypto:hash(sha256, Message)),
    PropertiesDigest = base64:encode(crypto:hash(sha256, CanonicalProperties)),
    SignedInfoContent =
        <<"<", Ds/binary, "CanonicalizationMethod Algorithm=\"", ?DSIG_C14N11_ALGO_URI, "\"></",
            Ds/binary, "CanonicalizationMethod><", Ds/binary, "SignatureMethod Algorithm=\"",
            ?DSIG_SIG_RSA_SHA256_URI, "\"></", Ds/binary, "SignatureMethod><", Ds/binary,
            "Reference URI=\"\"><", Ds/binary, "Transforms><", Ds/binary, "Transform Algorithm=\"",
            ?DSIG_ENVELOPED_SIGNATURE_TRANSFORM_URI, "\"></", Ds/binary, "Transform></", Ds/binary,
            "Transforms><", Ds/binary, "DigestMethod Algorithm=\"", ?DSIG_DIGEST_SHA256_URI,
            "\"></", Ds/binary, "DigestMethod><", Ds/binary, "DigestValue>", MessageDigest/binary,
            "</", Ds/binary, "DigestValue></", Ds/binary, "Reference><", Ds/binary,
            "Reference Type=\"", ?XADES_SIGNED_PROPERTIES_TYPE_URI,
            "\" URI=\"#SignedProperties-1\"><", Ds/binary, "DigestMethod Algorithm=\"",
            ?DSIG_DIGEST_SHA256_URI, "\"></", Ds/binary, "DigestMethod><", Ds/binary,
            "DigestValue>", PropertiesDigest/binary, "</", Ds/binary, "DigestValue></", Ds/binary,
            "Reference>">>,
    CanonicalSignedInfo =
        <<"<", Ds/binary, "SignedInfo", SignatureDecl/binary, ">", SignedInfoContent/binary, "</",
            Ds/binary, "SignedInfo>">>,
    SignatureValue = base64:encode(public_key:sign(CanonicalSignedInfo, sha256, Key)),
    <<"<?xml version='1.0'?><invoice Id=\"invoice-1\"><amount currency=\"EUR\">42.00</amount><",
        Ds/binary, "Signature", SignatureDecl/binary, " Id=\"Signature-1\"><", Ds/binary,
        "SignedInfo>", SignedInfoContent/binary, "</", Ds/binary, "SignedInfo><", Ds/binary,
        "SignatureValue>", SignatureValue/binary, "</", Ds/binary, "SignatureValue><", Ds/binary,
        "Object><", Xades/binary, "QualifyingProperties", PropertiesDecl/binary,
        " Target=\"#Signature-1\">", Properties/binary, "</", Xades/binary,
        "QualifyingProperties></", Ds/binary, "Object></", Ds/binary, "Signature></invoice>">>.

namespace_fixture_names(prefixed) ->
    {<<"sig:">>, <<"proof:">>, <<" xmlns:sig=\"", ?DSIG_NAMESPACE_URI, "\"">>,
        <<" xmlns:proof=\"", ?XADES_NAMESPACE_URI, "\"">>,
        <<" xmlns:proof=\"", ?XADES_NAMESPACE_URI, "\" xmlns:sig=\"", ?DSIG_NAMESPACE_URI, "\"">>};
namespace_fixture_names(default) ->
    {<<>>, <<>>, <<" xmlns=\"", ?DSIG_NAMESPACE_URI, "\"">>,
        <<" xmlns=\"", ?XADES_NAMESPACE_URI, "\"">>, <<" xmlns=\"", ?XADES_NAMESPACE_URI, "\"">>}.

c14n_idempotent_after_sign(Config) ->
    RawMessage = ?config(raw_message, Config),
    RsaKey = ?config(rsa_key, Config),
    SignedMessage = signerl:sign(RawMessage, sha256, RsaKey),
    {ok, ParsedSigned} = xmlan:parse_binary(SignedMessage),
    {ok, SignedInfoElement} = xmlan:find_path(
        [?DSIG_NAME(<<"Signature">>), ?DSIG_NAME(<<"SignedInfo">>)], ParsedSigned
    ),
    C14N1 = xmlan_c14n:canonicalize(SignedInfoElement),
    {ok, ReParsed} = xmlan:parse_binary(C14N1),
    C14N2 = xmlan_c14n:canonicalize(ReParsed),
    ?assertEqual(C14N1, C14N2).

%% Workflow helpers

signing_certificate_v2_path() ->
    [
        <<"ds:Signature">>,
        <<"ds:Object">>,
        <<"xades:QualifyingProperties">>,
        <<"xades:SignedProperties">>,
        <<"xades:SignedSignatureProperties">>,
        <<"xades:SigningCertificateV2">>
    ].

tamper_keyinfo_certificate(SignedMessage, NewCertDer) ->
    NewCertB64 = binary_to_list(base64:encode(NewCertDer)),
    {ok, Parsed} = xmlan:parse_binary(SignedMessage),
    Tampered = replace_x509_certificate(Parsed, NewCertB64),
    ?assertNotEqual(Parsed, Tampered),
    xmlan:export(<<"<?xml version=\"1.0\" encoding=\"UTF-8\"?>">>, Tampered).

replace_x509_certificate({<<"ds:X509Certificate">>, Attrs, _}, NewCertB64) ->
    {<<"ds:X509Certificate">>, Attrs, [NewCertB64]};
replace_x509_certificate({Tag, Attrs, Content}, NewCertB64) when is_list(Content) ->
    {Tag, Attrs, [replace_x509_certificate(Child, NewCertB64) || Child <- Content]};
replace_x509_certificate(Other, _NewCertB64) ->
    Other.

strip_keyinfo_certificate(SignedMessage) ->
    {ok, Parsed} = xmlan:parse_binary(SignedMessage),
    Stripped = remove_x509_data(Parsed),
    ?assertNotEqual(Parsed, Stripped),
    xmlan:export(<<"<?xml version=\"1.0\" encoding=\"UTF-8\"?>">>, Stripped).

remove_x509_data({<<"ds:X509Data">>, _Attrs, _Content}) ->
    removed;
remove_x509_data({Tag, Attrs, Content}) when is_list(Content) ->
    Filtered = lists:filtermap(
        fun(Child) ->
            case remove_x509_data(Child) of
                removed -> false;
                Transformed -> {true, Transformed}
            end
        end,
        Content
    ),
    {Tag, Attrs, Filtered};
remove_x509_data(Other) ->
    Other.

tamper_cert_digest_method(SignedMessage) ->
    {ok, Parsed} = xmlan:parse_binary(SignedMessage),
    Tampered = replace_cert_digest_method(Parsed),
    ?assertNotEqual(Parsed, Tampered),
    xmlan:export(<<"<?xml version=\"1.0\" encoding=\"UTF-8\"?>">>, Tampered).

replace_cert_digest_method({<<"xades:SigningCertificateV2">>, Attrs, Content}) ->
    {<<"xades:SigningCertificateV2">>, Attrs, replace_cert_digest_method_inner(Content)};
replace_cert_digest_method({Tag, Attrs, Content}) when is_list(Content) ->
    {Tag, Attrs, [replace_cert_digest_method(Child) || Child <- Content]};
replace_cert_digest_method(Other) ->
    Other.

replace_cert_digest_method_inner([{<<"xades:Cert">>, CAttrs, CContent}]) ->
    [{<<"xades:Cert">>, CAttrs, replace_digest_method_in_cert(CContent)}];
replace_cert_digest_method_inner(Other) ->
    Other.

replace_digest_method_in_cert([]) ->
    [];
replace_digest_method_in_cert([{<<"xades:CertDigest">>, DAttrs, DContent} | Rest]) ->
    [{<<"xades:CertDigest">>, DAttrs, replace_digest_method_elem(DContent)} | Rest];
replace_digest_method_in_cert([H | T]) ->
    [H | replace_digest_method_in_cert(T)].

replace_digest_method_elem([]) ->
    [];
replace_digest_method_elem([{<<"ds:DigestMethod">>, _, DMContent} | Rest]) ->
    [
        {<<"ds:DigestMethod">>, [{<<"Algorithm">>, "http://www.w3.org/2001/04/xmlenc#sha512"}],
            DMContent}
        | Rest
    ];
replace_digest_method_elem([H | T]) ->
    [H | replace_digest_method_elem(T)].

verify_independent_signature(FileName, Algorithm) ->
    FixtureDir = signerl_utils:file_path("test/examples/independent"),
    {ok, SignedMessage} = file:read_file(filename:join(FixtureDir, FileName)),
    {ok, PublicKey} = signerl_utils:load_key_from_file(filename:join(FixtureDir, "rsa-public.pem")),
    Parsed = test_helpers:parse_verified_message(SignedMessage, PublicKey),
    {ok, SignatureData} = signerl_verify:extract_signature_data(Parsed),
    #{references := #{c14n_algorithm := ActualAlgorithm}} = SignatureData,
    ?assertEqual(Algorithm, ActualAlgorithm),
    ?assertEqual(true, signerl_verify:verify_reference_digests(SignatureData, sha256)),
    ChangedAmount = test_helpers:replace_once(SignedMessage, <<"42.00">>, <<"43.00">>),
    ?assertEqual(false, signerl:verify(ChangedAmount, sha256, PublicKey)),
    ChangedTime = test_helpers:replace_once(
        SignedMessage, <<"2026-01-01T00:00:00Z">>, <<"2000-01-01T00:00:00Z">>
    ),
    ?assertEqual(false, signerl:verify(ChangedTime, sha256, PublicKey)).

sign_utf8_binary_and_file(Config) ->
    Key = ?config(rsa_key, Config),
    PublicKey = ?config(rsa_public_key, Config),
    Path = signerl_utils:file_path("test/examples/c14n/utf8.xml"),
    {ok, Raw} = file:read_file(Path),
    {ok, ExpectedTree} = xmlan:parse_binary(Raw),
    Cert = signerl_cert_helpers:cert_der(signerl_cert_helpers:signer_rsa_cert_path()),
    DefaultEncoding = test_helpers:replace_once(Raw, <<" encoding=\"UTF-8\"">>, <<>>),
    lists:foreach(
        fun(Signed) ->
            ?assert(is_binary(Signed)),
            ?assertEqual(true, signerl:verify(Signed, sha256, PublicKey)),
            {ok, Parsed} = xmlan:parse_binary(Signed),
            ?assertEqual(ExpectedTree, signerl_c14n:remove_signature_elements(Parsed)),
            Tampered = test_helpers:replace_once(Signed, <<">café"/utf8>>, <<">cafè"/utf8>>),
            ?assertEqual(false, signerl:verify(Tampered, sha256, PublicKey))
        end,
        [
            signerl:sign(Raw, sha256, Key),
            signerl:sign(Path, sha256, Key),
            signerl:sign(Raw, sha256, Key, Cert),
            signerl:sign(Path, sha256, Key, Cert),
            signerl:sign(DefaultEncoding, sha256, Key)
        ]
    ),
    Signed = signerl:sign(Raw, sha256, Key),
    OutPath = filename:join(?config(priv_dir, Config), "signed-utf8.xml"),
    ok = file:write_file(OutPath, Signed),
    ?assertEqual(true, signerl:verify(OutPath, sha256, PublicKey)),
    NoDeclaration = test_helpers:replace_once(
        Signed, <<"<?xml version=\"1.0\" encoding=\"UTF-8\"?>">>, <<>>
    ),
    ?assertEqual(true, signerl:verify(NoDeclaration, sha256, PublicKey)),
    ?assertEqual(true, signerl:verify(<<239, 187, 191, Signed/binary>>, sha256, PublicKey)).

reject_unsupported_encoding(Config) ->
    Key = ?config(rsa_key, Config),
    PublicKey = ?config(rsa_public_key, Config),
    Raw = ?config(raw_message, Config),
    Signed = signerl:sign(Raw, sha256, Key),
    ?assertEqual(true, signerl:verify(Signed, sha256, PublicKey)),
    lists:foreach(
        fun(Encoding) ->
            InvalidInput = test_helpers:replace_once(Raw, <<"UTF-8">>, Encoding),
            ?assertEqual({error, invalid_prolog}, signerl:sign(InvalidInput, sha256, Key)),
            InvalidSigned = test_helpers:replace_once(Signed, <<"UTF-8">>, Encoding),
            ?assertEqual({error, invalid_xml}, signerl:verify(InvalidSigned, sha256, PublicKey))
        end,
        [<<"ISO-8859-1">>, <<"UTF-16">>, <<"UTF-32">>]
    ).

reject_invalid_utf8(Config) ->
    Key = ?config(rsa_key, Config),
    PublicKey = ?config(rsa_public_key, Config),
    Raw = <<"<?xml version=\"1.0\" encoding=\"UTF-8\"?><root>valid</root>">>,
    Signed = signerl:sign(Raw, sha256, Key),
    ?assertEqual(true, signerl:verify(Signed, sha256, PublicKey)),
    lists:foreach(
        fun(Bytes) ->
            InvalidInput = test_helpers:replace_once(
                Raw, <<">valid<">>, <<">", Bytes/binary, "<">>
            ),
            ?assertEqual({error, invalid_xml}, signerl:sign(InvalidInput, sha256, Key)),
            InvalidSigned = test_helpers:replace_once(
                Signed, <<">valid<">>, <<">", Bytes/binary, "<">>
            ),
            ?assertEqual({error, invalid_xml}, signerl:verify(InvalidSigned, sha256, PublicKey))
        end,
        [<<16#80>>, <<16#C0, 16#AF>>, <<16#ED, 16#A0, 16#80>>, <<16#F0, 16#9F>>]
    ).

sign_preserves_content(Config) ->
    Key = ?config(rsa_key, Config),
    PublicKey = ?config(rsa_public_key, Config),
    Path = signerl_utils:file_path("test/examples/c14n/preserved_content.xml"),
    {ok, Raw} = file:read_file(Path),
    {ok, Original} = xmlan:parse_binary(Raw),
    Signed = signerl:sign(Raw, sha256, Key),
    ?assertEqual(true, signerl:verify(Signed, sha256, PublicKey)),
    {ok, Parsed} = xmlan:parse_binary(Signed),
    ?assertEqual(Original, signerl_c14n:remove_signature_elements(Parsed)),
    FileSigned = signerl:sign(Path, sha256, Key),
    ?assertEqual(true, signerl:verify(FileSigned, sha256, PublicKey)),
    lists:foreach(
        fun({Before, After}) ->
            Changed = test_helpers:replace_once(Signed, Before, After),
            ?assertEqual(false, signerl:verify(Changed, sha256, PublicKey))
        end,
        [
            {<<"<a/> <b/>">>, <<"<a/><b/>">>},
            {<<"  before <em>">>, <<" before <em>">>},
            {<<"tab=\"x&#x9;y\"">>, <<"tab=\"x y\"">>},
            {<<"lf=\"x&#xA;y\"">>, <<"lf=\"x&#xD;y\"">>},
            {<<">t&#xD;t<">>, <<">t\nt<">>}
        ]
    ).

processing_instructions_are_rejected(Config) ->
    Key = ?config(rsa_key, Config),
    PublicKey = ?config(rsa_public_key, Config),
    Raw = <<"<?xml version='1.0'?><root><a/></root>">>,
    Signed = signerl:sign(Raw, sha256, Key),
    ?assertEqual(true, signerl:verify(Signed, sha256, PublicKey)),
    lists:foreach(
        fun({Before, After}) ->
            Input = test_helpers:replace_once(Raw, Before, After),
            ?assertEqual({error, invalid_xml}, signerl:sign(Input, sha256, Key)),
            Changed = test_helpers:replace_once(Signed, Before, After),
            ?assertEqual({error, invalid_xml}, signerl:verify(Changed, sha256, PublicKey))
        end,
        [
            {<<"<root>">>, <<"<?report preserved?><root>">>},
            {<<"<a/>">>, <<"<a/><?report preserved?>">>},
            {<<"</root>">>, <<"</root><?report preserved?>">>}
        ]
    ).

complete_document_accepts_trailing_misc(Config) ->
    Key = ?config(rsa_key, Config),
    PublicKey = ?config(rsa_public_key, Config),
    Raw = <<"<?xml version='1.0'?><root><value>content</value></root>">>,
    Signed = signerl:sign(Raw, sha256, Key),
    ?assertEqual(true, signerl:verify(Signed, sha256, PublicKey)),
    lists:foreach(
        fun(Tail) ->
            ?assertEqual(true, signerl:verify(<<Signed/binary, Tail/binary>>, sha256, PublicKey)),
            SignedWithTail = signerl:sign(<<Raw/binary, Tail/binary>>, sha256, Key),
            ?assertEqual(true, signerl:verify(SignedWithTail, sha256, PublicKey))
        end,
        [
            <<" \t\r\n">>,
            <<"<!-- trailing comment -->">>,
            <<"\n<!-- <extra/> <?report ignored?> -->\t<!-- ő 東京 -->\r\n"/utf8>>
        ]
    ).

complete_document_rejects_trailing_content(Config) ->
    Key = ?config(rsa_key, Config),
    PublicKey = ?config(rsa_public_key, Config),
    Raw = <<"<?xml version='1.0'?><root><value>content</value></root>">>,
    Signed = signerl:sign(Raw, sha256, Key),
    ?assertEqual(true, signerl:verify(Signed, sha256, PublicKey)),
    lists:foreach(
        fun({Name, Tail}) ->
            ct:log("Checking trailing ~s", [Name]),
            ?assertEqual(
                {error, invalid_xml}, signerl:sign(<<Raw/binary, Tail/binary>>, sha256, Key)
            ),
            ?assertEqual(
                {error, invalid_xml},
                signerl:verify(<<Signed/binary, Tail/binary>>, sha256, PublicKey)
            )
        end,
        [
            {"second root", <<"<extra/>">>},
            {"plain text", <<"not XML">>},
            {"declaration", <<"<?xml version='1.0'?><extra/>">>},
            {"garbage after comment", <<"\n<!-- fine -->not XML">>},
            {"unfinished comment", <<"<!-- unfinished">>},
            {"invalid comment", <<"<!-- invalid -- separator -->">>},
            {"character reference", <<"&#x20;">>},
            {"incomplete markup", <<"<">>}
        ]
    ).

complete_document_file_boundary(Config) ->
    Key = ?config(rsa_key, Config),
    PublicKey = ?config(rsa_public_key, Config),
    Raw = <<"<?xml version='1.0'?><root/>\n<!-- allowed -->">>,
    InputPath = filename:join(?config(priv_dir, Config), "complete-input.xml"),
    SignedPath = filename:join(?config(priv_dir, Config), "complete-signed.xml"),
    ok = file:write_file(InputPath, Raw),
    ?assertEqual({<<"root">>, [], []}, xmlan:parse_file(InputPath)),
    Signed = signerl:sign(InputPath, sha256, Key),
    ok = file:write_file(SignedPath, <<Signed/binary, " \t<!-- allowed -->\n">>),
    ?assertEqual(true, signerl:verify(SignedPath, sha256, PublicKey)),
    ok = file:write_file(InputPath, <<Raw/binary, "<extra/>">>),
    ?assertException(error, _, xmlan:parse_file(InputPath)),
    ?assertEqual({error, invalid_xml}, signerl:sign(InputPath, sha256, Key)),
    ok = file:write_file(SignedPath, <<Signed/binary, "<extra/>">>),
    ?assertEqual({error, invalid_xml}, signerl:verify(SignedPath, sha256, PublicKey)).

dtd_is_rejected_by_public_apis(Config) ->
    Key = ?config(rsa_key, Config),
    PublicKey = ?config(rsa_public_key, Config),
    Prolog = <<"<?xml version='1.0'?>">>,
    Raw = <<Prolog/binary, "<root>content</root>">>,
    Signed = signerl:sign(Raw, sha256, Key),
    ?assertEqual(true, signerl:verify(Signed, sha256, PublicKey)),
    lists:foreach(
        fun(Dtd) ->
            ?assertEqual(
                {error, invalid_xml},
                signerl:sign(<<Prolog/binary, Dtd/binary, "<root>content</root>">>, sha256, Key)
            ),
            WithDtd = binary:replace(Signed, Prolog, <<Prolog/binary, Dtd/binary>>),
            ?assertNotEqual(Signed, WithDtd),
            ?assertEqual({error, invalid_xml}, signerl:verify(WithDtd, sha256, PublicKey))
        end,
        [
            <<"<!DOCTYPE root>">>,
            <<"<!DOCTYPE root []>">>,
            <<"<!DOCTYPE root [<!ENTITY value 'unused'>]>">>
        ]
    ).

dtd_file_input_is_rejected(Config) ->
    Key = ?config(rsa_key, Config),
    PublicKey = ?config(rsa_public_key, Config),
    Prolog = <<"<?xml version='1.0'?>">>,
    Raw = <<Prolog/binary, "<root/>">>,
    Signed = signerl:sign(Raw, sha256, Key),
    Path = filename:join(?config(priv_dir, Config), "dtd-input.xml"),
    ok = file:write_file(Path, Signed),
    ?assertEqual(true, signerl:verify(Path, sha256, PublicKey)),
    WithDtd = binary:replace(Signed, Prolog, <<Prolog/binary, "<!DOCTYPE root>">>),
    ?assertNotEqual(Signed, WithDtd),
    ok = file:write_file(Path, WithDtd),
    ?assertEqual({error, invalid_xml}, signerl:verify(Path, sha256, PublicKey)),
    ok = file:write_file(Path, <<Prolog/binary, "<!DOCTYPE root><root/>">>),
    ?assertEqual({error, invalid_xml}, signerl:sign(Path, sha256, Key)).

sign_with_controlled_time_files_and_certificate(Config) ->
    RawMessage = ?config(raw_message, Config),
    Key = ?config(rsa_key, Config),
    PublicKey = ?config(rsa_public_key, Config),
    MessagePath = signerl_utils:file_path("test/examples/base/books.xml"),
    KeyPath = signerl_cert_helpers:signer_rsa_key_path(),
    Cert = signerl_cert_helpers:cert_der(signerl_cert_helpers:signer_rsa_cert_path()),
    Time = <<"2024-02-29T00:00:00Z">>,
    Signed = signerl:sign(RawMessage, sha256, Key, Cert, Time),
    ?assertEqual(Signed, signerl:sign(MessagePath, sha256, KeyPath, Cert, Time)),
    ?assertEqual(Signed, signerl:sign(RawMessage, sha256, KeyPath, Cert, Time)),
    Parsed = test_helpers:parse_verified_message(Signed, PublicKey),
    {ok, #{signed_properties := #{signing_time := Time}, key_info := #{x509_certificate := Cert}}} =
        signerl_verify:extract_signature_data(Parsed),
    EcdsaKey = ?config(ecdsa_key, Config),
    EcdsaPublicKey = ?config(ecdsa_public_key, Config),
    EcdsaSigned = signerl:sign(RawMessage, sha256, EcdsaKey, undefined, Time),
    test_helpers:parse_verified_message(EcdsaSigned, EcdsaPublicKey).

sign_rejects_invalid_controlled_time(Config) ->
    Message = ?config(raw_message, Config),
    Key = ?config(rsa_key, Config),
    lists:foreach(
        fun(Time) ->
            ?assertEqual(
                {error, invalid_signing_time}, signerl:sign(Message, sha256, Key, undefined, Time)
            )
        end,
        [
            <<"2026-02-31T12:00:00Z">>,
            <<"2026-01-01T12:00:00+00:00">>,
            <<"2026-01-01T12:00:00.5Z">>,
            undefined
        ]
    ),
    ?assertEqual(
        {error, invalid_signing_time},
        signerl_signature:build_signature_element(
            {<<"root">>, [], []},
            sha256,
            Key,
            undefined,
            <<"1900-02-29T12:00:00Z">>
        )
    ),
    Signed = signerl:sign(Message, sha256, Key, undefined, <<"2026-02-28T12:00:00Z">>),
    InvalidDate = test_helpers:replace_once(
        Signed,
        <<"2026-02-28T12:00:00Z">>,
        <<"2026-02-31T12:00:00Z">>
    ),
    ?assertEqual(
        {error, invalid_signing_time},
        signerl:verify(InvalidDate, sha256, ?config(rsa_public_key, Config))
    ).

relative_namespace_returns_invalid_xml(Config) ->
    Key = ?config(rsa_key, Config),
    PublicKey = ?config(rsa_public_key, Config),
    Raw = <<"<?xml version='1.0'?><root xmlns:p='relative'><p:child/></root>">>,
    ?assertEqual({error, invalid_xml}, signerl:sign(Raw, sha256, Key)),
    ?assertEqual({error, invalid_xml}, signerl:verify(Raw, sha256, PublicKey)).
