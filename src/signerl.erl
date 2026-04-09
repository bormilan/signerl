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
        {ok, ParsedMessage} ?= signerl_xml:parse_binary(Message),
        {ok, SignatureElement} ?=
            signerl_signature:build_signature_element(ParsedMessage, Hash, Key),
        SignedMessage = signerl_xml:add_new_element(SignatureElement, ParsedMessage),
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
        {ok, ParsedMessage} ?= signerl_xml:parse_binary(SignedMessage),
        {ok, SignatureData} ?= signerl_verify:extract_signature_data(ParsedMessage),
        {ok, SignatureBytes} ?= maps:find(signature_bytes, SignatureData),
        {ok, SignedInfoElement} ?= maps:find(signed_info_element, SignatureData),
        true ?= signerl_verify:verify_reference_digests(SignatureData, Hash),
        SignedInfoBytes = signerl_c14n:canonicalize(SignedInfoElement),
        public_key:verify(SignedInfoBytes, Hash, SignatureBytes, Key)
    else
        false ->
            false;
        {error, Reason} ->
            {error, Reason}
    end.
