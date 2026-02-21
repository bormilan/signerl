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
    add_signature_element/1,
    sign/1,
    sign_from_file/1,
    sign_with_chain_leaf_rsa/1,
    sign_with_self_signed_rsa/1,
    sign_with_self_signed_ecdsa/1,
    sign_deterministic/1,
    sign_uses_input_prolog_binary/1,
    sign_uses_input_prolog_file/1,
    sign_missing_prolog_binary_returns_error/1,
    sign_invalid_prolog_file_returns_error/1,
    verify_missing_prolog_binary_returns_error/1,
    verify_invalid_prolog_file_returns_error/1,
    verify_fails_on_modified_message/1,
    verify_fails_with_wrong_key/1,
    verify_fails_with_wrong_ecdsa_key/1
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
            add_signature_element,
            sign,
            sign_from_file,
            sign_with_chain_leaf_rsa,
            sign_with_self_signed_rsa,
            sign_with_self_signed_ecdsa,
            sign_deterministic,
            sign_uses_input_prolog_binary,
            sign_uses_input_prolog_file,
            sign_missing_prolog_binary_returns_error,
            sign_invalid_prolog_file_returns_error,
            verify_missing_prolog_binary_returns_error,
            verify_invalid_prolog_file_returns_error,
            verify_fails_on_modified_message,
            verify_fails_with_wrong_key,
            verify_fails_with_wrong_ecdsa_key
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

add_signature_element(_Config) ->
    Path = "test/examples/books.xml",
    Message = signerl_xml:parse_file(Path),
    {_, _, SignedMessageContent} = signerl_signature:add_signature_element(Message),
    ?assertEqual(
        true,
        lists:member({'ds:Signature', [], []}, SignedMessageContent)
    ).

sign_from_file(_) ->
    KeyPath = signerl_utils:file_path("priv/key.pem"),
    MessagePath = signerl_utils:file_path("test/examples/books.xml"),

    Digest = signerl:sign(MessagePath, sha256, KeyPath),
    ?assertEqual(true, signerl:verify(MessagePath, sha256, Digest, KeyPath)).

sign(_Config) ->
    {ok, KeyRaw} = file:read_file(signerl_utils:file_path("priv/key.pem")),
    [KeyDer] = public_key:pem_decode(KeyRaw),
    Key = public_key:pem_entry_decode(KeyDer),

    Path = "test/examples/books.xml",
    {ok, RawMessage} = file:read_file(signerl_utils:file_path(Path)),

    Digest = signerl:sign(RawMessage, sha256, Key),
    ?assertEqual(true, signerl:verify(RawMessage, sha256, Digest, Key)).

sign_with_chain_leaf_rsa(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),

    Key = signerl_cert_helpers:leaf_key(),
    CertPath = signerl_cert_helpers:leaf_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    Digest = signerl:sign(RawMessage, sha256, Key),
    ?assertEqual(true, signerl:verify(RawMessage, sha256, Digest, PublicKey)).

sign_with_self_signed_rsa(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),

    Key = signerl_cert_helpers:signer_rsa_key(),
    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    Digest = signerl:sign(RawMessage, sha256, Key),
    ?assertEqual(true, signerl:verify(RawMessage, sha256, Digest, PublicKey)).

sign_with_self_signed_ecdsa(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),

    Key = signerl_cert_helpers:signer_ecdsa_key(),
    CertPath = signerl_cert_helpers:signer_ecdsa_cert_path(),
    PublicKey = test_helpers:ecdsa_public_key_from_cert(CertPath),

    Digest = signerl:sign(RawMessage, sha256, Key),
    ?assertEqual(true, signerl:verify(RawMessage, sha256, Digest, PublicKey)).

sign_deterministic(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),

    Key = signerl_cert_helpers:signer_rsa_key(),

    Digest1 = signerl:sign(RawMessage, sha256, Key),
    Digest2 = signerl:sign(RawMessage, sha256, Key),
    ?assertEqual(Digest1, Digest2).

sign_uses_input_prolog_binary(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/books_custom_prolog.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),

    Key = signerl_cert_helpers:signer_rsa_key(),
    ParsedMessage = signerl_xml:parse_binary(RawMessage),
    Prolog = ["<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"],
    ExpectedSignable = signerl_xml:export(Prolog, ParsedMessage),
    ExpectedDigest = public_key:sign(ExpectedSignable, sha256, Key),

    Digest = signerl:sign(RawMessage, sha256, Key),
    ?assertEqual(ExpectedDigest, Digest).

sign_uses_input_prolog_file(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/books_custom_prolog.xml"),

    Key = signerl_cert_helpers:signer_rsa_key(),
    {ok, RawMessage} = file:read_file(MessagePath),
    ParsedMessage = signerl_xml:parse_binary(RawMessage),
    Prolog = ["<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"],
    ExpectedSignable = signerl_xml:export(Prolog, ParsedMessage),
    ExpectedDigest = public_key:sign(ExpectedSignable, sha256, Key),

    Digest = signerl:sign(MessagePath, sha256, Key),
    ?assertEqual(ExpectedDigest, Digest).

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
    ValidPath = signerl_utils:file_path("test/examples/books.xml"),
    MissingPath = signerl_utils:file_path("test/examples/books_no_prolog.xml"),
    {ok, ValidRawMessage} = file:read_file(ValidPath),
    {ok, MissingRawMessage} = file:read_file(MissingPath),

    SignKey = signerl_cert_helpers:signer_rsa_key(),
    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),
    Digest = signerl:sign(ValidRawMessage, sha256, SignKey),

    ?assertEqual(
        {error, invalid_prolog}, signerl:verify(MissingRawMessage, sha256, Digest, PublicKey)
    ).

verify_invalid_prolog_file_returns_error(_Config) ->
    ValidPath = signerl_utils:file_path("test/examples/books.xml"),
    InvalidPath = signerl_utils:file_path("test/examples/books_invalid_prolog.xml"),
    {ok, ValidRawMessage} = file:read_file(ValidPath),

    SignKey = signerl_cert_helpers:signer_rsa_key(),
    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),
    Digest = signerl:sign(ValidRawMessage, sha256, SignKey),

    ?assertEqual({error, invalid_prolog}, signerl:verify(InvalidPath, sha256, Digest, PublicKey)).

verify_fails_on_modified_message(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),

    Key = signerl_cert_helpers:signer_rsa_key(),
    CertPath = signerl_cert_helpers:signer_rsa_cert_path(),
    PublicKey = test_helpers:rsa_public_key_from_cert(CertPath),

    Digest = signerl:sign(RawMessage, sha256, Key),
    % Change actual content to avoid being normalized away by XML parsing.
    Modified = binary:replace(RawMessage, <<"Gatsby">>, <<"Gatzby">>, []),
    ?assertEqual(false, signerl:verify(Modified, sha256, Digest, PublicKey)).

verify_fails_with_wrong_key(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),

    SignKey = signerl_cert_helpers:signer_rsa_key(),
    WrongCertPath = signerl_cert_helpers:leaf_cert_path(),
    WrongPublicKey = test_helpers:rsa_public_key_from_cert(WrongCertPath),

    Digest = signerl:sign(RawMessage, sha256, SignKey),
    ?assertEqual(false, signerl:verify(RawMessage, sha256, Digest, WrongPublicKey)).

verify_fails_with_wrong_ecdsa_key(_Config) ->
    MessagePath = signerl_utils:file_path("test/examples/books.xml"),
    {ok, RawMessage} = file:read_file(MessagePath),

    SignKey = signerl_cert_helpers:signer_ecdsa_key(),
    WrongCertPath = signerl_cert_helpers:leaf_cert_path(),
    WrongPublicKey = test_helpers:rsa_public_key_from_cert(WrongCertPath),

    Digest = signerl:sign(RawMessage, sha256, SignKey),
    ?assertEqual(false, signerl:verify(RawMessage, sha256, Digest, WrongPublicKey)).
