-module(signerl_signature_test).

-include_lib("eunit/include/eunit.hrl").

build_test_() ->
    {setup, fun builder_fixture/0, fun(Config) ->
        [
            {"add_signature_element_inserts_signature_value",
                ?_test(add_signature_element_inserts_signature_value(Config))},
            {"add_signature_element_inserts_signed_properties",
                ?_test(add_signature_element_inserts_signed_properties(Config))},
            {"add_signature_element_extracts_signature_value",
                ?_test(add_signature_element_extracts_signature_value(Config))},
            {"build_signature_element_rsa_and_ecdsa",
                ?_test(build_signature_element_rsa_and_ecdsa(Config))},
            {"build_signature_element_returns_error_with_invalid_hash_or_key",
                ?_test(build_signature_element_returns_error_with_invalid_hash_or_key(Config))}
        ]
    end}.

add_signature_element_inserts_signature_value(Config) ->
    Message = proplists:get_value(message, Config),
    Key = proplists:get_value(rsa_key, Config),
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
    Message = proplists:get_value(message, Config),
    Key = proplists:get_value(rsa_key, Config),
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
    Message = proplists:get_value(message, Config),
    Key = proplists:get_value(rsa_key, Config),
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
    Message = proplists:get_value(message, Config),
    RsaKey = proplists:get_value(rsa_key, Config),
    EcdsaKey = proplists:get_value(ecdsa_key, Config),
    {ok, RsaSignature} = signerl_signature:build_signature_element(
        Message, sha256, RsaKey, undefined
    ),
    {ok, EcdsaSignature} = signerl_signature:build_signature_element(
        Message, sha256, EcdsaKey, undefined
    ),

    assert_has_signed_info(RsaSignature),
    assert_has_signed_info(EcdsaSignature).

build_signature_element_returns_error_with_invalid_hash_or_key(Config) ->
    Message = proplists:get_value(message, Config),
    RsaKey = proplists:get_value(rsa_key, Config),
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

%% Fixture setup and mutation helpers

builder_fixture() ->
    Message = signerl_xml:parse_file("test/examples/base/books.xml"),
    RsaKey = signerl_cert_helpers:signer_rsa_key(),
    EcdsaKey = signerl_cert_helpers:signer_ecdsa_key(),
    [{message, Message}, {rsa_key, RsaKey}, {ecdsa_key, EcdsaKey}].

assert_has_signed_info(SignatureElement) ->
    ?assertMatch(
        {ok, {'ds:SignedInfo', _, _}}, signerl_xml:find_path(['ds:SignedInfo'], SignatureElement)
    ).
