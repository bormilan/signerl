-module(signerl).
-feature(maybe_expr, enable).

-export([sign/3, sign/4, verify/3]).

-type hash() :: sha256 | sha384 | sha512.
-export_type([hash/0]).

-spec sign(Message, HashAlgorithm, Key) -> SignedMessage | {error, Reason} when
    Message :: binary() | string(),
    HashAlgorithm :: hash(),
    Key :: public_key:private_key() | string(),
    SignedMessage :: binary(),
    Reason :: atom() | {file_error, term()}.
sign(Message, HashAlgorithm, FilePath) when is_binary(Message), is_list(FilePath) ->
    case signerl_utils:load_key_from_file(FilePath) of
        {ok, Key} ->
            sign(Message, HashAlgorithm, Key);
        {error, _} = Err ->
            Err
    end;
sign(FilePath, HashAlgorithm, Key) when is_list(FilePath) ->
    case file:read_file(FilePath) of
        {ok, RawMessage} ->
            sign(RawMessage, HashAlgorithm, Key);
        {error, Reason} ->
            {error, {file_error, Reason}}
    end;
sign(Message, HashAlgorithm, Key) when is_binary(Message) ->
    sign_impl(Message, HashAlgorithm, Key, undefined).

-spec sign(Message, HashAlgorithm, Key, CertDer) -> SignedMessage | {error, Reason} when
    Message :: binary() | string(),
    HashAlgorithm :: hash(),
    Key :: public_key:private_key() | string(),
    CertDer :: binary(),
    SignedMessage :: binary(),
    Reason :: atom() | {file_error, term()}.
sign(Message, HashAlgorithm, FilePath, CertDer) when is_binary(Message), is_list(FilePath) ->
    case signerl_utils:load_key_from_file(FilePath) of
        {ok, Key} ->
            sign(Message, HashAlgorithm, Key, CertDer);
        {error, _} = Err ->
            Err
    end;
sign(FilePath, HashAlgorithm, Key, CertDer) when is_list(FilePath) ->
    case file:read_file(FilePath) of
        {ok, RawMessage} ->
            sign(RawMessage, HashAlgorithm, Key, CertDer);
        {error, Reason} ->
            {error, {file_error, Reason}}
    end;
sign(Message, HashAlgorithm, Key, CertDer) when is_binary(Message) ->
    sign_impl(Message, HashAlgorithm, Key, CertDer).

sign_impl(Message, HashAlgorithm, Key, CertDer) ->
    maybe
        {ok, Prolog} ?= signerl_xml:parse_prolog(Message),
        {ok, ParsedMessage} ?= signerl_xml:parse_binary(Message),
        {ok, SignatureElement} ?=
            signerl_signature:build_signature_element(ParsedMessage, HashAlgorithm, Key, CertDer),
        SignedMessage = signerl_xml:add_new_element(SignatureElement, ParsedMessage),
        signerl_xml:export(Prolog, SignedMessage)
    else
        {error, Reason} ->
            {error, Reason}
    end.

-spec verify(SignedMessage, HashAlgorithm, Key) -> boolean() | {error, Reason} when
    SignedMessage :: binary() | string(),
    HashAlgorithm :: hash(),
    Key :: public_key:public_key() | string(),
    Reason :: atom() | {file_error, term()}.
verify(SignedMessage, HashAlgorithm, FilePath) when is_binary(SignedMessage), is_list(FilePath) ->
    case signerl_utils:load_key_from_file(FilePath) of
        {ok, Key} ->
            verify(SignedMessage, HashAlgorithm, Key);
        {error, _} = Err ->
            Err
    end;
verify(FilePath, HashAlgorithm, Key) when is_list(FilePath) ->
    case file:read_file(FilePath) of
        {ok, RawMessage} ->
            verify(RawMessage, HashAlgorithm, Key);
        {error, Reason} ->
            {error, {file_error, Reason}}
    end;
verify(SignedMessage, HashAlgorithm, Key) when is_binary(SignedMessage) ->
    maybe
        {ok, ParsedMessage} ?= signerl_xml:parse_binary(SignedMessage),
        {ok, SignatureData} ?= signerl_verify:extract_signature_data(ParsedMessage),
        {ok, SignatureBytes} ?= maps:find(signature_bytes, SignatureData),
        {ok, SignedInfoElement} ?= maps:find(signed_info_element, SignatureData),
        true ?= signerl_verify:verify_reference_digests(SignatureData, HashAlgorithm),
        C14NMode = signerl_verify:c14n_mode(SignatureData),
        SignedInfoBytes = signerl_c14n:canonicalize(SignedInfoElement, C14NMode),
        public_key:verify(SignedInfoBytes, HashAlgorithm, SignatureBytes, Key)
    else
        false ->
            false;
        {error, Reason} ->
            {error, Reason}
    end.
