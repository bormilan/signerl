-module(signerl).
-feature(maybe_expr, enable).

-export([sign/3, verify/3]).

sign(Message, Hash, FilePath) when is_list(FilePath) ->
    sign(
        Message,
        Hash,
        signerl_utils:load_key_from_file(FilePath)
    );
sign(FilePath, Hash, Key) when is_list(FilePath) ->
    {ok, RawMessage} = file:read_file(FilePath),
    sign(
        RawMessage,
        Hash,
        Key
    );
sign(Message, Hash, Key) ->
    maybe
        {ok, Prolog} ?= signerl_xml:parse_prolog(Message),
        ParsedMessage = signerl_xml:parse_binary(Message),
        SignableMessage = signerl_xml:export(Prolog, ParsedMessage),
        SignatureBytes = public_key:sign(SignableMessage, Hash, Key),
        SignedMessage = signerl_signature:add_signature_element(ParsedMessage, SignatureBytes),
        signerl_xml:export(Prolog, SignedMessage)
    else
        {error, Reason} ->
            {error, Reason}
    end.

verify(SignedMessage, Hash, FilePath) when is_list(FilePath) ->
    {ok, KeyRaw} = file:read_file(FilePath),
    [KeyDer] = public_key:pem_decode(KeyRaw),
    Key = public_key:pem_entry_decode(KeyDer),
    verify(SignedMessage, Hash, Key);
verify(FilePath, Hash, Key) when is_list(FilePath) ->
    {ok, RawMessage} = file:read_file(FilePath),
    verify(
        RawMessage,
        Hash,
        Key
    );
verify(SignedMessage, Hash, Key) ->
    maybe
        {ok, Prolog} ?= signerl_xml:parse_prolog(SignedMessage),
        ParsedMessage = signerl_xml:parse_binary(SignedMessage),
        {ok, SignatureBytes, UnsignedMessage} ?= signerl_verify:extract_signature(ParsedMessage),
        MessageWithoutSignature = signerl_xml:export(Prolog, UnsignedMessage),
        public_key:verify(MessageWithoutSignature, Hash, SignatureBytes, Key)
    else
        {error, Reason} ->
            {error, Reason}
    end.
