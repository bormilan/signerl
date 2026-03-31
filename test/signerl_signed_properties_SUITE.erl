-module(signerl_signed_properties_SUITE).

-include_lib("eunit/include/eunit.hrl").
-compile([export_all, nowarn_export_all]).

suite() ->
    [{timetrap, {seconds, 30}}].

all() ->
    [
        extract_accepts_optional_signed_signature_properties,
        extract_ignores_unknown_signed_signature_properties,
        extract_accepts_binary_signing_time,
        extract_returns_error_with_non_byte_list_signing_time,
        extract_returns_error_with_non_text_signing_time,
        extract_returns_error_with_duplicate_signing_time_property,
        extract_returns_error_without_signing_time
    ].

extract_accepts_optional_signed_signature_properties(_Config) ->
    SignatureElement = test_helpers:signature_element([
        {'xades:SigningTime', [], ["2026-01-01T00:00:00Z"]},
        {'xades:SigningCertificate', [], []},
        {'xades:SigningCertificateV2', [], []},
        {'xades:SignaturePolicyIdentifier', [], []},
        {'xades:SignatureProductionPlace', [], []},
        {'xades:SignerRole', [], []}
    ]),
    ?assertEqual(
        {ok, #{
            signing_time => <<"2026-01-01T00:00:00Z">>,
            signing_certificate => valid,
            signing_certificate_v2 => valid,
            signature_policy_identifier => valid,
            signature_production_place => valid,
            signer_role => valid
        }},
        signerl_signed_properties:extract(SignatureElement)
    ).

extract_ignores_unknown_signed_signature_properties(_Config) ->
    SignatureElement = test_helpers:signature_element([
        {'xades:SigningTime', [], ["2026-01-01T00:00:00Z"]},
        {'xades:UnknownProperty', [], ["ignored"]}
    ]),
    ?assertEqual(
        {ok, #{signing_time => <<"2026-01-01T00:00:00Z">>}},
        signerl_signed_properties:extract(SignatureElement)
    ).

extract_accepts_binary_signing_time(_Config) ->
    SignatureElement = test_helpers:signature_element([
        {'xades:SigningTime', [], [<<"2026-01-01T00:00:00Z">>]}
    ]),
    ?assertEqual(
        {ok, #{signing_time => <<"2026-01-01T00:00:00Z">>}},
        signerl_signed_properties:extract(SignatureElement)
    ).

extract_returns_error_with_non_byte_list_signing_time(_Config) ->
    SignatureElement = test_helpers:signature_element([
        {'xades:SigningTime', [], [[65, {invalid, [], []}]]}
    ]),
    ?assertEqual({error, invalid_signature}, signerl_signed_properties:extract(SignatureElement)).

extract_returns_error_with_non_text_signing_time(_Config) ->
    SignatureElement = test_helpers:signature_element([
        {'xades:SigningTime', [], [123]}
    ]),
    ?assertEqual({error, invalid_signature}, signerl_signed_properties:extract(SignatureElement)).

extract_returns_error_with_duplicate_signing_time_property(_Config) ->
    SignatureElement = test_helpers:signature_element([
        {'xades:SigningTime', [], ["2026-01-01T00:00:00Z"]},
        {'xades:SigningTime', [], ["2026-01-01T00:00:00Z"]}
    ]),
    ?assertEqual({error, invalid_signature}, signerl_signed_properties:extract(SignatureElement)).

extract_returns_error_without_signing_time(_Config) ->
    SignatureElement = test_helpers:signature_element([{'xades:SignerRole', [], []}]),
    ?assertEqual({error, invalid_signature}, signerl_signed_properties:extract(SignatureElement)).
