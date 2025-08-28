-module(signerl_signature).

-export([add_signature_element/1]).

-spec add_signature_element(Message) -> SignedMessage when
    Message :: signerl_xml:simplified_xml(),
    SignedMessage :: signerl_xml:simplified_xml().
add_signature_element(Message) ->
    SignatureElement = construct_signature(),
    signerl_xml:add_new_element(SignatureElement, Message).

-spec construct_signature() -> signerl_xml:simplified_xml().
construct_signature() ->
    {'ds:Signature', [], []}.
