-module(signerl_dsig_utils).
-include("signerl_dsig.hrl").

-export([digest_base64/2, signature_method_uri_for_key/1]).

digest_base64(Hash, Payload) ->
    base64:encode(crypto:hash(Hash, Payload)).

signature_method_uri_for_key(Key) when is_tuple(Key), tuple_size(Key) > 0 ->
    case element(1, Key) of
        'RSAPrivateKey' -> {ok, ?DSIG_SIG_RSA_SHA256_URI};
        'ECPrivateKey' -> {ok, ?DSIG_SIG_ECDSA_SHA256_URI};
        _ -> error
    end;
signature_method_uri_for_key(_) ->
    error.
