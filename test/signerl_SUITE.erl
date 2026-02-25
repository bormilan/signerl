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
            add_signature_element_extract_binary_and_rejects_empty,
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
            verify_returns_error_with_non_text_signature_value,
            verify_returns_error_without_object,
            verify_returns_error_without_qualifying_properties,
            verify_returns_error_without_signed_properties,
            verify_returns_error_without_signed_signature_properties,
            verify_returns_error_without_signing_time,
            verify_returns_error_with_invalid_signing_time,
            verify_returns_error_with_self_closing_signing_time,
            verify_returns_error_with_non_text_signing_time,
            verify_returns_false_with_wrong_signature_value,
            verify_fails_on_modified_message,
            verify_fails_on_modified_signing_time,
            verify_fails_with_wrong_keys
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
    SignatureBytes = <<1, 2, 3>>,
    SignedMessage = signerl_signature:add_signature_element(Message, SignatureBytes),
    {_, _, SignedMessageContent} = SignedMessage,
    ?assertEqual(
        true,
        lists:member(
            {'ds:Signature', [], [
                {'ds:SignatureValue', [], ["AQID"]},
                signed_properties("2026-01-01T00:00:00Z")
            ]},
            SignedMessageContent
        )
    ).

add_signature_element_inserts_signed_properties(_Config) ->
    Message = signerl_xml:parse_file("test/examples/base/books.xml"),
    SignatureBytes = <<1, 2, 3>>,
    SignedMessage = signerl_signature:add_signature_element(Message, SignatureBytes),
    SignedMessageBin = signerl_xml:export(
        ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"], SignedMessage
    ),
    ?assertMatch({_, _}, binary:match(SignedMessageBin, <<"<ds:Object>">>)),
    ?assertMatch({_, _}, binary:match(SignedMessageBin, <<"<xades:QualifyingProperties>">>)),
    ?assertMatch({_, _}, binary:match(SignedMessageBin, <<"<xades:SignedProperties>">>)),
    ?assertMatch({_, _}, binary:match(SignedMessageBin, <<"<xades:SigningTime>">>)),
    ?assertMatch({_, _}, binary:match(SignedMessageBin, <<"2026-01-01T00:00:00Z">>)).

add_signature_element_extracts_signature_value(_Config) ->
    Message = signerl_xml:parse_file("test/examples/base/books.xml"),
    SignatureBytes = <<1, 2, 3>>,
    SignedMessage = signerl_signature:add_signature_element(Message, SignatureBytes),
    ?assertEqual(
        {ok, SignatureBytes, Message, #{signing_time => <<"2026-01-01T00:00:00Z">>}},
        signerl_verify:extract_signature(SignedMessage)
    ),
    ok.

add_signature_element_extract_binary_and_rejects_empty(_Config) ->
    Message = signerl_xml:parse_file("test/examples/base/books.xml"),
    {Tag, Attrs, Content} = Message,
    SignatureBytes = <<1, 2, 3>>,
    BinarySignatureValueMessage = {
        Tag,
        Attrs,
        Content ++
            [
                {'ds:Signature', [], [
                    {'ds:SignatureValue', [], [<<"AQID">>]},
                    signed_properties("2026-01-01T00:00:00Z")
                ]}
            ]
    },
    ?assertEqual(
        {ok, SignatureBytes, Message, #{signing_time => <<"2026-01-01T00:00:00Z">>}},
        signerl_verify:extract_signature(BinarySignatureValueMessage)
    ),
    BinarySigningTimeMessage = {
        Tag,
        Attrs,
        Content ++
            [
                {'ds:Signature', [], [
                    {'ds:SignatureValue', [], [<<"AQID">>]},
                    signed_properties(<<"2026-01-01T00:00:00Z">>)
                ]}
            ]
    },
    ?assertEqual(
        {ok, SignatureBytes, Message, #{signing_time => <<"2026-01-01T00:00:00Z">>}},
        signerl_verify:extract_signature(BinarySigningTimeMessage)
    ),
    EmptyStringSignatureValueMessage = {
        Tag,
        Attrs,
        Content ++
            [
                {'ds:Signature', [], [
                    {'ds:SignatureValue', [], [""]},
                    signed_properties("2026-01-01T00:00:00Z")
                ]}
            ]
    },
    ?assertEqual(
        {error, invalid_signature},
        signerl_verify:extract_signature(EmptyStringSignatureValueMessage)
    ),
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

    ?assertEqual({error, invalid_prolog}, signerl:verify(MissingRawMessage, sha256, PublicKey)).

verify_invalid_prolog_file_returns_error(_Config) ->
    InvalidPath = signerl_utils:file_path("test/examples/prolog/books_invalid_prolog.xml"),

    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    ?assertEqual({error, invalid_prolog}, signerl:verify(InvalidPath, sha256, PublicKey)).

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

verify_returns_error_with_non_text_signature_value(_Config) ->
    Message = signerl_xml:parse_file("test/examples/base/books.xml"),
    {Tag, Attrs, Content} = Message,
    InvalidMessage = {
        Tag,
        Attrs,
        Content ++
            [
                {'ds:Signature', [], [
                    {'ds:SignatureValue', [], [{'invalid', [], []}]},
                    signed_properties("2026-01-01T00:00:00Z")
                ]}
            ]
    },
    ?assertEqual({error, invalid_signature}, signerl_verify:extract_signature(InvalidMessage)).

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

verify_returns_error_with_non_text_signing_time(_Config) ->
    Message = signerl_xml:parse_file("test/examples/base/books.xml"),
    {Tag, Attrs, Content} = Message,
    InvalidMessage = {
        Tag,
        Attrs,
        Content ++
            [
                {'ds:Signature', [], [
                    {'ds:SignatureValue', [], ["AQID"]},
                    signed_properties({'invalid', [], []})
                ]}
            ]
    },
    ?assertEqual({error, invalid_signature}, signerl_verify:extract_signature(InvalidMessage)),
    InvalidListMessage = {
        Tag,
        Attrs,
        Content ++
            [
                {'ds:Signature', [], [
                    {'ds:SignatureValue', [], ["AQID"]},
                    signed_properties([65, {invalid, [], []}])
                ]}
            ]
    },
    ?assertEqual({error, invalid_signature}, signerl_verify:extract_signature(InvalidListMessage)),
    InvalidIntegerMessage = {
        Tag,
        Attrs,
        Content ++
            [
                {'ds:Signature', [], [
                    {'ds:SignatureValue', [], ["AQID"]},
                    signed_properties(123)
                ]}
            ]
    },
    ?assertEqual(
        {error, invalid_signature}, signerl_verify:extract_signature(InvalidIntegerMessage)
    ).

verify_returns_false_with_wrong_signature_value(_Config) ->
    SignedPath = signerl_utils:file_path(
        "test/examples/signed_properties/books_signature_wrong_value.xml"
    ),

    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    ?assertEqual(false, signerl:verify(SignedPath, sha256, PublicKey)).

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
    Modified = binary:replace(
        SignedMessage, <<"2026-01-01T00:00:00Z">>, <<"2026-01-02T00:00:00Z">>, []
    ),
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

signed_properties(SigningTime) ->
    signed_properties_with_elements([{'xades:SigningTime', [], [SigningTime]}]).

signed_properties_with_elements(SignedSignaturePropertiesElements) ->
    {'ds:Object', [], [
        {'xades:QualifyingProperties', [], [
            {'xades:SignedProperties', [], [
                {'xades:SignedSignatureProperties', [], SignedSignaturePropertiesElements}
            ]}
        ]}
    ]}.
