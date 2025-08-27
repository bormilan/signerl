-module(signerl).

-export([add_signature_element/1, validate/1]).
-export([sign/1, verify/2]).

-spec add_signature_element(Message) -> SignedMessage when
    Message :: signerl_xml:simplified_xml(),
    SignedMessage :: signerl_xml:simplified_xml().
add_signature_element(Message) ->
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

sign(Message) ->
    % TODO: need to convert the message to binary
    {ok, KeyRaw} = file:read_file("/Users/milanbor/projects/signerl/key.pem"),
    [KeyDer] = public_key:pem_decode(KeyRaw),
    Key = public_key:pem_entry_decode(KeyDer),
    public_key:sign(Message, sha256, Key).

verify(Message, Digest) ->
    {ok, KeyRaw} = file:read_file("/Users/milanbor/projects/signerl/key.pem"),
    [KeyDer] = public_key:pem_decode(KeyRaw),
    Key = public_key:pem_entry_decode(KeyDer),
    public_key:verify(Message, sha256, Digest, Key).
