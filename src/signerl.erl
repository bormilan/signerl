-module(signerl).

-export([sign/3, verify/4]).

sign(Message, Hash, FilePath) when is_list(FilePath) ->
    sign(
        Message,
        Hash,
        signerl_utils:load_key_from_file(FilePath)
    );
sign(FilePath, Hash, Key) when is_list(FilePath) ->
    sign(
        signerl_xml:parse_file(FilePath),
        Hash,
        Key
    );
sign(Message, Hash, Key) ->
    %TODO: adding the signature element to it
    % SignedMessage = signerl_signature:add_signature_element(Message)

    % HACK: should take from the message
    Prolog = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"],

    SignableMessage = signerl_xml:export(Prolog, Message),
    public_key:sign(SignableMessage, Hash, Key).

verify(Message, Hash, Digest, FilePath) when is_list(FilePath) ->
    {ok, KeyRaw} = file:read_file(FilePath),
    [KeyDer] = public_key:pem_decode(KeyRaw),
    Key = public_key:pem_entry_decode(KeyDer),
    verify(Message, Hash, Digest, Key);
verify(FilePath, Hash, Digest, Key) when is_list(FilePath) ->
    verify(
        signerl_xml:parse_file(FilePath),
        Hash,
        Digest,
        Key
    );
verify(Message, Hash, Digest, Key) ->
    % HACK: should take from the message
    Prolog = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"],

    SignableMessage = signerl_xml:export(Prolog, Message),
    public_key:verify(SignableMessage, Hash, Digest, Key).
