-module(signerl).

-export([sign/1, validate/1]).

-spec sign(Message) -> SignedMessage when
    Message :: signerl_xml:simplified_xml(),
    SignedMessage :: signerl_xml:simplified_xml().
sign(Message) ->
    SignatureElement = construct_signature(),
    signerl_xml:add_new_element(SignatureElement, Message).

-spec construct_signature() -> signerl_xml:simplified_xml().
construct_signature() ->
    {'ds:Signature', [], []}.

-spec validate(SignedMessage) -> Result when
    SignedMessage :: signerl_xml:simplified_xml(),
    Result :: boolean().
validate({_, _, Content}) ->
    lists:member({'ds:Signature', [], []}, Content).
