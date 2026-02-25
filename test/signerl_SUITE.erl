-module(signerl_SUITE).

-include_lib("eunit/include/eunit.hrl").

-export([
    suite/0,
    init_per_suite/1,
    end_per_suite/1,
    init_per_group/2,
    init_per_testcase/2,
    end_per_testcase/2,
    end_per_group/2,
    groups/0,
    all/0
]).

-export([
    add_signature_element_inserts_signature_value/1,
    add_signature_element_extracts_signature_value/1,
    add_signature_element_extract_binary_and_rejects_empty/1,
    sign/1,
    sign_with_chain_leaf_rsa/1,
    sign_with_self_signed_rsa/1,
    sign_with_self_signed_ecdsa/1,
    sign_deterministic/1,
    sign_uses_input_prolog_binary_and_file/1,
    sign_missing_prolog_binary_returns_error/1,
    sign_invalid_prolog_file_returns_error/1,
    verify_missing_prolog_binary_returns_error/1,
    verify_invalid_prolog_file_returns_error/1,
    verify_returns_error_without_signature_element/1,
    verify_returns_error_without_signature_value/1,
    verify_returns_error_with_empty_signature_value/1,
    verify_returns_error_with_invalid_base64_signature_value/1,
    verify_returns_error_with_self_closing_signature_value/1,
    verify_returns_false_with_wrong_signature_value/1,
    verify_fails_on_modified_message/1,
    verify_fails_with_wrong_keys/1
]).

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
            verify_returns_false_with_wrong_signature_value,
            verify_fails_on_modified_message,
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
    Path = "test/examples/books.xml",
    Message = signerl_xml:parse_file(Path),
    SignatureBytes = <<1, 2, 3>>,
    SignedMessage = signerl_signature:add_signature_element(Message, SignatureBytes),
    {_, _, SignedMessageContent} = SignedMessage,
    ?assertEqual(
        true,
        lists:member(
            {'ds:Signature', [], [{'ds:SignatureValue', [], ["AQID"]}]}, SignedMessageContent
        )
    ).

add_signature_element_extracts_signature_value(_Config) ->
    Message = signerl_xml:parse_file("test/examples/books.xml"),
    SignatureBytes = <<1, 2, 3>>,
    SignedMessage = signerl_signature:add_signature_element(Message, SignatureBytes),
    ?assertEqual({ok, SignatureBytes, Message}, signerl_verify:extract_signature(SignedMessage)),
    ok.

add_signature_element_extract_binary_and_rejects_empty(_Config) ->
    Message = signerl_xml:parse_file("test/examples/books.xml"),
    {Tag, Attrs, Content} = Message,
    SignatureBytes = <<1, 2, 3>>,
    BinarySignatureValueMessage = {
        Tag,
        Attrs,
        Content ++ [{'ds:Signature', [], [{'ds:SignatureValue', [], [<<"AQID">>]}]}]
    },
    ?assertEqual(
        {ok, SignatureBytes, Message},
        signerl_verify:extract_signature(BinarySignatureValueMessage)
    ),
    EmptyStringSignatureValueMessage = {
        Tag,
        Attrs,
        Content ++ [{'ds:Signature', [], [{'ds:SignatureValue', [], [""]}]}]
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

    Path = "test/examples/books.xml",
    {ok, RawMessage} = file:read_file(signerl_utils:file_path(Path)),

    SignedMessage = signerl:sign(RawMessage, sha256, Key),
    SignedMessageFromFile = signerl:sign(signerl_utils:file_path(Path), sha256, KeyPath),
    ?assertEqual(true, signerl:verify(SignedMessage, sha256, Key)),
    ?assertEqual(true, signerl:verify(SignedMessageFromFile, sha256, KeyPath)).

sign_with_chain_leaf_rsa(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),

    Key = signerl_cert_helpers:leaf_key(),
    CertPath = signerl_cert_helpers:leaf_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    SignedMessage = signerl:sign(RawMessage, sha256, Key),
    ?assertEqual(true, signerl:verify(SignedMessage, sha256, PublicKey)).

sign_with_self_signed_rsa(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),

    Key = signerl_cert_helpers:signer_rsa_key(),
    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    SignedMessage = signerl:sign(RawMessage, sha256, Key),
    ?assertEqual(true, signerl:verify(SignedMessage, sha256, PublicKey)).

sign_with_self_signed_ecdsa(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),

    Key = signerl_cert_helpers:signer_ecdsa_key(),
    CertPath = signerl_cert_helpers:signer_ecdsa_cert_path(),
    PublicKey = test_helpers:ecdsa_public_key_from_cert(CertPath),

    SignedMessage = signerl:sign(RawMessage, sha256, Key),
    ?assertEqual(true, signerl:verify(SignedMessage, sha256, PublicKey)).

sign_deterministic(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),

    Key = signerl_cert_helpers:signer_rsa_key(),

    SignedMessage1 = signerl:sign(RawMessage, sha256, Key),
    SignedMessage2 = signerl:sign(RawMessage, sha256, Key),
    ?assertEqual(SignedMessage1, SignedMessage2).

sign_uses_input_prolog_binary_and_file(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/books_custom_prolog.xml"),
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
    MessagePath = signerl_utils:file_path("test/examples/books_no_prolog.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),
    Key = signerl_cert_helpers:signer_rsa_key(),

    ?assertEqual({error, invalid_prolog}, signerl:sign(RawMessage, sha256, Key)).

sign_invalid_prolog_file_returns_error(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/books_invalid_prolog.xml"),
    Key = signerl_cert_helpers:signer_rsa_key(),

    ?assertEqual({error, invalid_prolog}, signerl:sign(MessagePath, sha256, Key)).

verify_missing_prolog_binary_returns_error(_Config) ->
    MissingPath = signerl_utils:file_path("test/examples/books_no_prolog.xml"),
    {ok, MissingRawMessage} = file:read_file(MissingPath),

    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    ?assertEqual({error, invalid_prolog}, signerl:verify(MissingRawMessage, sha256, PublicKey)).

verify_invalid_prolog_file_returns_error(_Config) ->
    InvalidPath = signerl_utils:file_path("test/examples/books_invalid_prolog.xml"),

    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    ?assertEqual({error, invalid_prolog}, signerl:verify(InvalidPath, sha256, PublicKey)).

verify_returns_error_without_signature_element(_Config) ->
    UnsignedPath = signerl_utils:file_path("test/examples/books.xml"),
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
    SignedPath = signerl_utils:file_path("test/examples/books_signature_no_value.xml"),

    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    ?assertEqual({error, invalid_signature}, signerl:verify(SignedPath, sha256, PublicKey)).

verify_returns_error_with_empty_signature_value(_Config) ->
    EmptyValuePath = signerl_utils:file_path("test/examples/books_signature_empty_value.xml"),

    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    ?assertEqual({error, invalid_signature}, signerl:verify(EmptyValuePath, sha256, PublicKey)).

verify_returns_error_with_invalid_base64_signature_value(_Config) ->
    InvalidBase64Path = signerl_utils:file_path("test/examples/books_signature_invalid_base64.xml"),

    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    ?assertEqual({error, invalid_signature}, signerl:verify(InvalidBase64Path, sha256, PublicKey)).

verify_returns_error_with_self_closing_signature_value(_Config) ->
    SelfClosingValuePath = signerl_utils:file_path(
        "test/examples/books_signature_self_closing_value.xml"
    ),

    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    ?assertEqual(
        {error, invalid_signature}, signerl:verify(SelfClosingValuePath, sha256, PublicKey)
    ).

verify_returns_false_with_wrong_signature_value(_Config) ->
    SignedPath = signerl_utils:file_path("test/examples/books_signature_wrong_value.xml"),

    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    ?assertEqual(false, signerl:verify(SignedPath, sha256, PublicKey)).

verify_fails_on_modified_message(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),

    Key = signerl_cert_helpers:signer_rsa_key(),
    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    SignedMessage = signerl:sign(RawMessage, sha256, Key),
    % Change actual content to avoid being normalized away by XML parsing.
    Modified = binary:replace(SignedMessage, <<"Gatsby">>, <<"Gatzby">>, []),
    ?assertEqual(false, signerl:verify(Modified, sha256, PublicKey)).

verify_fails_with_wrong_keys(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/books.xml"),
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
