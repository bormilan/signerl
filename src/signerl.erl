-module(signerl).
-feature(maybe_expr, enable).

-export([sign/3, sign/4, verify/3]).

-type hash() :: sha256 | sha384 | sha512.
-export_type([hash/0]).

-spec sign(Message, Hash, Key) -> SignedMessage | {error, Reason} when
    Message :: binary() | string(),
    Hash :: hash(),
    Key :: public_key:private_key() | string(),
    SignedMessage :: binary(),
    Reason :: atom() | {file_error, term()}.
sign(Message, Hash, FilePath) when is_binary(Message), is_list(FilePath) ->
    case signerl_utils:load_key_from_file(FilePath) of
        {ok, Key} ->
            sign(Message, Hash, Key);
        {error, _} = Err ->
            Err
    end;
sign(FilePath, Hash, Key) when is_list(FilePath) ->
    case file:read_file(FilePath) of
        {ok, RawMessage} ->
            sign(RawMessage, Hash, Key);
        {error, Reason} ->
            {error, {file_error, Reason}}
    end;
sign(Message, Hash, Key) when is_binary(Message) ->
    sign_impl(Message, Hash, Key, undefined).

-spec sign(Message, Hash, Key, CertDer) -> SignedMessage | {error, Reason} when
    Message :: binary() | string(),
    Hash :: hash(),
    Key :: public_key:private_key() | string(),
    CertDer :: binary(),
    SignedMessage :: binary(),
    Reason :: atom() | {file_error, term()}.
sign(Message, Hash, FilePath, CertDer) when is_binary(Message), is_list(FilePath) ->
    case signerl_utils:load_key_from_file(FilePath) of
        {ok, Key} ->
            sign(Message, Hash, Key, CertDer);
        {error, _} = Err ->
            Err
    end;
sign(FilePath, Hash, Key, CertDer) when is_list(FilePath) ->
    case file:read_file(FilePath) of
        {ok, RawMessage} ->
            sign(RawMessage, Hash, Key, CertDer);
        {error, Reason} ->
            {error, {file_error, Reason}}
    end;
sign(Message, Hash, Key, CertDer) when is_binary(Message) ->
    sign_impl(Message, Hash, Key, CertDer).

sign_impl(Message, Hash, Key, CertDer) ->
    maybe
        {ok, Prolog} ?= signerl_xml:parse_prolog(Message),
        {ok, ParsedMessage} ?= signerl_xml:parse_binary(Message),
        {ok, SignatureElement} ?=
            signerl_signature:build_signature_element(ParsedMessage, Hash, Key, CertDer),
        SignedMessage = signerl_xml:add_new_element(SignatureElement, ParsedMessage),
        signerl_xml:export(Prolog, SignedMessage)
    else
        {error, Reason} ->
            {error, Reason}
    end.

-spec verify(SignedMessage, Hash, Key) -> boolean() | {error, Reason} when
    SignedMessage :: binary() | string(),
    Hash :: hash(),
    Key :: public_key:public_key() | string(),
    Reason :: atom() | {file_error, term()}.
verify(SignedMessage, Hash, FilePath) when is_binary(SignedMessage), is_list(FilePath) ->
    case signerl_utils:load_key_from_file(FilePath) of
        {ok, Key} ->
            verify(SignedMessage, Hash, Key);
        {error, _} = Err ->
            Err
    end;
verify(FilePath, Hash, Key) when is_list(FilePath) ->
    case file:read_file(FilePath) of
        {ok, RawMessage} ->
            verify(RawMessage, Hash, Key);
        {error, Reason} ->
            {error, {file_error, Reason}}
    end;
verify(SignedMessage, Hash, Key) when is_binary(SignedMessage) ->
    maybe
        {ok, ParsedMessage} ?= signerl_xml:parse_binary(SignedMessage),
        {ok, SignatureData} ?= signerl_verify:extract_signature_data(ParsedMessage),
        {ok, SignatureBytes} ?= maps:find(signature_bytes, SignatureData),
        {ok, SignedInfoElement} ?= maps:find(signed_info_element, SignatureData),
        true ?= signerl_verify:verify_reference_digests(SignatureData, Hash),
        C14NMode = signerl_verify:c14n_mode(SignatureData),
        SignedInfoBytes = signerl_c14n:canonicalize(SignedInfoElement, C14NMode),
        public_key:verify(SignedInfoBytes, Hash, SignatureBytes, Key)
    else
        false ->
            false;
        {error, Reason} ->
            {error, Reason}
    end.
