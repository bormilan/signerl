-module(signerl_signature).

-define(DEFAULT_SIGNING_TIME, <<"2026-01-01T00:00:00Z">>).

-export([add_signature_element/2, add_signature_element/3]).

-spec add_signature_element(Message, SignatureBytes) -> SignedMessage when
    Message :: {atom(), [{atom(), string() | number()}], [any()]},
    SignatureBytes :: binary(),
    SignedMessage :: {atom(), [{atom(), string() | number()}], [any()]}.
add_signature_element(Message, SignatureBytes) ->
    add_signature_element(Message, SignatureBytes, ?DEFAULT_SIGNING_TIME).

-spec add_signature_element(Message, SignatureBytes, SigningTime) -> SignedMessage when
    Message :: {atom(), [{atom(), string() | number()}], [any()]},
    SignatureBytes :: binary(),
    SigningTime :: binary(),
    SignedMessage :: {atom(), [{atom(), string() | number()}], [any()]}.
add_signature_element(Message, SignatureBytes, SigningTime) ->
    SignatureElement = construct_signature(SignatureBytes, SigningTime),
    signerl_xml:add_new_element(SignatureElement, Message).

-spec construct_signature(SignatureBytes, SigningTime) ->
    {atom(), [{atom(), string() | number()}], [any()]}
when
    SignatureBytes :: binary(),
    SigningTime :: binary().
construct_signature(SignatureBytes, SigningTime) ->
    SignatureValue = base64:encode(SignatureBytes),
    {'ds:Signature', [], [
        {'ds:SignatureValue', [], [binary_to_list(SignatureValue)]},
        {'ds:Object', [], [
            {'xades:QualifyingProperties', [], [
                {'xades:SignedProperties', [], [
                    {'xades:SignedSignatureProperties', [], [
                        {'xades:SigningTime', [], [binary_to_list(SigningTime)]}
                    ]}
                ]}
            ]}
        ]}
    ]}.
