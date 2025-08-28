-module(signerl).

-export([sign/1, verify/2]).

sign(Message) ->
    {ok, KeyRaw} = file:read_file(signerl_utils:file_path("key.pem")),
    [KeyDer] = public_key:pem_decode(KeyRaw),
    Key = public_key:pem_entry_decode(KeyDer),
    public_key:sign(Message, sha256, Key).

verify(Message, Digest) ->
    {ok, KeyRaw} = file:read_file(signerl_utils:file_path("key.pem")),
    [KeyDer] = public_key:pem_decode(KeyRaw),
    Key = public_key:pem_entry_decode(KeyDer),
    public_key:verify(Message, sha256, Digest, Key).
