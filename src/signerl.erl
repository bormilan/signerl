-module(signerl).
-feature(maybe_expr, enable).

-export([sign/3, sign/4, sign/5, verify/3]).

-type hash() :: sha256.
-export_type([hash/0]).

-spec sign(Message, HashAlgorithm, Key) -> SignedMessage | {error, Reason} when
    Message :: binary() | string(),
    HashAlgorithm :: hash(),
    Key :: public_key:private_key() | string(),
    SignedMessage :: binary(),
    Reason :: atom() | {file_error, term()}.
sign(Message, HashAlgorithm, Key) ->
    sign(Message, HashAlgorithm, Key, undefined, signerl_utils:current_utc_timestamp()).

-spec sign(Message, HashAlgorithm, Key, CertDer) -> SignedMessage | {error, Reason} when
    Message :: binary() | string(),
    HashAlgorithm :: hash(),
    Key :: public_key:private_key() | string(),
    CertDer :: binary() | undefined,
    SignedMessage :: binary(),
    Reason :: atom() | {file_error, term()}.
sign(Message, HashAlgorithm, Key, CertDer) ->
    sign(Message, HashAlgorithm, Key, CertDer, signerl_utils:current_utc_timestamp()).

-spec sign(Message, HashAlgorithm, Key, CertDer, SigningTime) ->
    SignedMessage | {error, Reason}
when
    Message :: binary() | string(),
    HashAlgorithm :: hash(),
    Key :: public_key:private_key() | string(),
    CertDer :: binary() | undefined,
    SigningTime :: binary(),
    SignedMessage :: binary(),
    Reason :: atom() | {file_error, term()}.
sign(Message, HashAlgorithm, FilePath, CertDer, SigningTime) when
    is_binary(Message), is_list(FilePath)
->
    case signerl_utils:load_key_from_file(FilePath) of
        {ok, Key} -> sign(Message, HashAlgorithm, Key, CertDer, SigningTime);
        {error, _} = Err -> Err
    end;
sign(FilePath, HashAlgorithm, Key, CertDer, SigningTime) when is_list(FilePath) ->
    case file:read_file(FilePath) of
        {ok, RawMessage} -> sign(RawMessage, HashAlgorithm, Key, CertDer, SigningTime);
        {error, Reason} -> {error, {file_error, Reason}}
    end;
sign(Message, HashAlgorithm, Key, CertDer, SigningTime) when is_binary(Message) ->
    sign_impl(Message, HashAlgorithm, Key, CertDer, SigningTime).

sign_impl(Message, HashAlgorithm, Key, CertDer, SigningTime) ->
    maybe
        {ok, Prolog} ?= xmlan:parse_prolog(Message),
        {ok, ParsedMessage} ?= xmlan:parse_binary(Message),
        {ok, SignatureElement} ?=
            signerl_signature:build_signature_element(
                ParsedMessage, HashAlgorithm, Key, CertDer, SigningTime
            ),
        SignedMessage = xmlan:add_new_element(SignatureElement, ParsedMessage),
        xmlan:export(Prolog, SignedMessage)
    else
        {error, Reason} -> {error, Reason}
    end.

-spec verify(SignedMessage, HashAlgorithm, Key) -> boolean() | {error, Reason} when
    SignedMessage :: binary() | string(),
    HashAlgorithm :: hash(),
    Key :: public_key:public_key() | public_key:private_key() | string(),
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
        {ok, ParsedMessage} ?= xmlan:parse_binary(SignedMessage),
        {ok, SignatureData} ?= signerl_verify:extract_signature_data(ParsedMessage),
        true ?= signerl_verify:verify_reference_digests(SignatureData, HashAlgorithm),
        signerl_verify:verify_signature(SignatureData, HashAlgorithm, Key)
    else
        false ->
            false;
        {error, Reason} ->
            {error, Reason}
    end.
