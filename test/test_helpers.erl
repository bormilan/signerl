-module(test_helpers).

-export([
    signature_element/1,
    signature_element/2,
    parse_verified_message/2,
    replace_once/3
]).

-include_lib("eunit/include/eunit.hrl").

%% Minimal extraction fixtures, not cryptographically valid signatures.
signature_element(SignedSignaturePropertiesElements) ->
    signature_with_properties([
        {<<"xades:SignedSignatureProperties">>, [], SignedSignaturePropertiesElements}
    ]).

signature_element(SignedSignaturePropertiesElements, SignedDataObjectPropertiesElements) ->
    signature_with_properties([
        {<<"xades:SignedSignatureProperties">>, [], SignedSignaturePropertiesElements},
        {<<"xades:SignedDataObjectProperties">>, [], SignedDataObjectPropertiesElements}
    ]).

signature_with_properties(Properties) ->
    {<<"ds:Signature">>, [], [
        {<<"ds:SignatureValue">>, [], ["AQID"]},
        {<<"ds:Object">>, [], [
            {<<"xades:QualifyingProperties">>, [], [
                {<<"xades:SignedProperties">>, [], Properties}
            ]}
        ]}
    ]}.

parse_verified_message(SignedMessage, PublicKey) ->
    ?assertEqual(true, signerl:verify(SignedMessage, sha256, PublicKey)),
    {ok, Parsed} = signerl_xml:parse_binary(SignedMessage),
    %% Verification accepts XML without a declaration, as do the reconstruction tests.
    Rebuilt = signerl_xml:export([], Parsed),
    ?assertEqual(true, signerl:verify(Rebuilt, sha256, PublicKey)),
    Parsed.

replace_once(Message, Before, After) ->
    ?assertMatch([_], binary:matches(Message, Before)),
    Replaced = binary:replace(Message, Before, After),
    ?assertNotEqual(Message, Replaced),
    Replaced.
