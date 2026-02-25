-module(signerl_signature).

-export([add_signature_element/2]).

-spec add_signature_element(Message, SignatureBytes) -> SignedMessage when
    Message :: {atom(), [{atom(), string() | number()}], [any()]},
    SignatureBytes :: binary(),
    SignedMessage :: {atom(), [{atom(), string() | number()}], [any()]}.
add_signature_element(Message, SignatureBytes) ->
    SignatureElement = construct_signature(SignatureBytes),
    signerl_xml:add_new_element(SignatureElement, Message).

-spec construct_signature(SignatureBytes) -> {atom(), [{atom(), string() | number()}], [any()]} when
    SignatureBytes :: binary().
construct_signature(SignatureBytes) ->
    SignatureValue = base64:encode(SignatureBytes),
    {'ds:Signature', [], [{'ds:SignatureValue', [], [binary_to_list(SignatureValue)]}]}.
