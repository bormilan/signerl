-module(signerl).
-feature(maybe_expr, enable).

-export([sign/3, verify/4]).

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
        {ok, SignableMessage} ?= signerl_utils:signable_message(Message),
        public_key:sign(SignableMessage, Hash, Key)
    else
        {error, Reason} ->
            {error, Reason}
    end.

verify(Message, Hash, Digest, FilePath) when is_list(FilePath) ->
    {ok, KeyRaw} = file:read_file(FilePath),
    [KeyDer] = public_key:pem_decode(KeyRaw),
    Key = public_key:pem_entry_decode(KeyDer),
    verify(Message, Hash, Digest, Key);
verify(FilePath, Hash, Digest, Key) when is_list(FilePath) ->
    {ok, RawMessage} = file:read_file(FilePath),
    verify(
        RawMessage,
        Hash,
        Digest,
        Key
    );
verify(Message, Hash, Digest, Key) ->
    maybe
        {ok, SignableMessage} ?= signerl_utils:signable_message(Message),
        public_key:verify(SignableMessage, Hash, Digest, Key)
    else
        {error, Reason} ->
            {error, Reason}
    end.
