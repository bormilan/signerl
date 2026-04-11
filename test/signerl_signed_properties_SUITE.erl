-module(signerl_signed_properties_SUITE).

-include_lib("eunit/include/eunit.hrl").
-compile([export_all, nowarn_export_all]).

suite() ->
    [{timetrap, {seconds, 30}}].

all() ->
    [
        extract_accepts_optional_signed_signature_properties,
        extract_accepts_signing_certificate_v2_with_issuer_serial,
        extract_accepts_signing_certificate_v2_without_issuer_serial,
        extract_returns_error_with_empty_signing_certificate_v2,
        extract_returns_error_with_missing_cert_digest,
        extract_returns_error_with_invalid_digest_value,
        extract_returns_error_with_duplicate_signing_certificate_v2,
        extract_returns_error_with_missing_digest_method,
        extract_accepts_binary_digest_value,
        extract_returns_error_with_non_byte_list_digest_value,
        extract_returns_error_with_non_text_digest_value,
        extract_returns_error_with_empty_binary_digest_value,
        extract_returns_error_with_invalid_base64_digest_value,
        extract_ignores_invalid_base64_issuer_serial_v2,
        extract_ignores_unknown_signed_signature_properties,
        extract_accepts_binary_signing_time,
        extract_returns_error_with_non_byte_list_signing_time,
        extract_returns_error_with_non_text_signing_time,
        extract_returns_error_with_duplicate_signing_time_property,
        extract_returns_error_without_signing_time
    ].

valid_signing_certificate_v2_element() ->
    DigestB64 = binary_to_list(base64:encode(crypto:hash(sha256, <<"test-cert-der">>))),
    IssuerSerialB64 = binary_to_list(base64:encode(<<"fake-issuer-serial">>)),
    cert_v2_with_issuer(DigestB64, IssuerSerialB64).

valid_signing_certificate_v2_no_issuer() ->
    DigestB64 = binary_to_list(base64:encode(crypto:hash(sha256, <<"test-cert-der">>))),
    {'xades:SigningCertificateV2', [], [
        {'xades:Cert', [], [cert_digest_element(DigestB64)]}
    ]}.

cert_digest_element(DigestB64) ->
    {'xades:CertDigest', [], [
        {'ds:DigestMethod', [{'Algorithm', "http://www.w3.org/2001/04/xmlenc#sha256"}], []},
        {'ds:DigestValue', [], [DigestB64]}
    ]}.

cert_v2_with_issuer(DigestB64, IssuerSerialB64) ->
    {'xades:SigningCertificateV2', [], [
        {'xades:Cert', [], [
            cert_digest_element(DigestB64),
            {'xades:IssuerSerialV2', [], [IssuerSerialB64]}
        ]}
    ]}.

signature_with_cert_v2(CertV2) ->
    test_helpers:signature_element([
        {'xades:SigningTime', [], ["2026-01-01T00:00:00Z"]},
        CertV2
    ]).

extract_accepts_optional_signed_signature_properties(_Config) ->
    CertV2 = valid_signing_certificate_v2_element(),
    ExpectedDigest = crypto:hash(sha256, <<"test-cert-der">>),
    ExpectedIssuerSerial = <<"fake-issuer-serial">>,
    SignatureElement = test_helpers:signature_element([
        {'xades:SigningTime', [], ["2026-01-01T00:00:00Z"]},
        {'xades:SigningCertificate', [], []},
        CertV2,
        {'xades:SignaturePolicyIdentifier', [], []},
        {'xades:SignatureProductionPlace', [], []},
        {'xades:SignerRole', [], []}
    ]),
    ?assertEqual(
        {ok, #{
            signing_time => <<"2026-01-01T00:00:00Z">>,
            signing_certificate => present,
            signing_certificate_v2 => #{
                digest_method => "http://www.w3.org/2001/04/xmlenc#sha256",
                digest_value => ExpectedDigest,
                issuer_serial_v2 => ExpectedIssuerSerial
            },
            signature_policy_identifier => present,
            signature_production_place => present,
            signer_role => present
        }},
        signerl_signed_properties:extract(SignatureElement)
    ).

extract_accepts_signing_certificate_v2_with_issuer_serial(_Config) ->
    CertV2 = valid_signing_certificate_v2_element(),
    ExpectedDigest = crypto:hash(sha256, <<"test-cert-der">>),
    ExpectedIssuerSerial = <<"fake-issuer-serial">>,
    SignatureElement = signature_with_cert_v2(CertV2),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    ?assertEqual(
        #{
            digest_method => "http://www.w3.org/2001/04/xmlenc#sha256",
            digest_value => ExpectedDigest,
            issuer_serial_v2 => ExpectedIssuerSerial
        },
        maps:get(signing_certificate_v2, Props)
    ).

extract_accepts_signing_certificate_v2_without_issuer_serial(_Config) ->
    CertV2 = valid_signing_certificate_v2_no_issuer(),
    ExpectedDigest = crypto:hash(sha256, <<"test-cert-der">>),
    SignatureElement = signature_with_cert_v2(CertV2),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    ?assertEqual(
        #{
            digest_method => "http://www.w3.org/2001/04/xmlenc#sha256",
            digest_value => ExpectedDigest
        },
        maps:get(signing_certificate_v2, Props)
    ).

extract_returns_error_with_empty_signing_certificate_v2(_Config) ->
    SignatureElement = test_helpers:signature_element([
        {'xades:SigningTime', [], ["2026-01-01T00:00:00Z"]},
        {'xades:SigningCertificateV2', [], []}
    ]),
    ?assertEqual(
        {error, invalid_signing_certificate_v2},
        signerl_signed_properties:extract(SignatureElement)
    ).

extract_returns_error_with_missing_cert_digest(_Config) ->
    SignatureElement = test_helpers:signature_element([
        {'xades:SigningTime', [], ["2026-01-01T00:00:00Z"]},
        {'xades:SigningCertificateV2', [], [
            {'xades:Cert', [], [
                {'xades:IssuerSerialV2', [], ["AQID"]}
            ]}
        ]}
    ]),
    ?assertEqual(
        {error, invalid_signing_certificate_v2},
        signerl_signed_properties:extract(SignatureElement)
    ).

extract_returns_error_with_invalid_digest_value(_Config) ->
    SignatureElement = test_helpers:signature_element([
        {'xades:SigningTime', [], ["2026-01-01T00:00:00Z"]},
        {'xades:SigningCertificateV2', [], [
            {'xades:Cert', [], [
                {'xades:CertDigest', [], [
                    {'ds:DigestMethod', [{'Algorithm', "http://www.w3.org/2001/04/xmlenc#sha256"}],
                        []},
                    {'ds:DigestValue', [], []}
                ]}
            ]}
        ]}
    ]),
    ?assertEqual(
        {error, invalid_signing_certificate_v2},
        signerl_signed_properties:extract(SignatureElement)
    ).

extract_returns_error_with_duplicate_signing_certificate_v2(_Config) ->
    CertV2 = valid_signing_certificate_v2_element(),
    SignatureElement = test_helpers:signature_element([
        {'xades:SigningTime', [], ["2026-01-01T00:00:00Z"]},
        CertV2,
        CertV2
    ]),
    ?assertEqual(
        {error, duplicate_property},
        signerl_signed_properties:extract(SignatureElement)
    ).

extract_returns_error_with_missing_digest_method(_Config) ->
    DigestB64 = binary_to_list(base64:encode(crypto:hash(sha256, <<"test">>))),
    SignatureElement = test_helpers:signature_element([
        {'xades:SigningTime', [], ["2026-01-01T00:00:00Z"]},
        {'xades:SigningCertificateV2', [], [
            {'xades:Cert', [], [
                {'xades:CertDigest', [], [
                    {'ds:DigestValue', [], [DigestB64]}
                ]}
            ]}
        ]}
    ]),
    ?assertEqual(
        {error, invalid_signing_certificate_v2},
        signerl_signed_properties:extract(SignatureElement)
    ).

extract_accepts_binary_digest_value(_Config) ->
    DigestB64 = base64:encode(crypto:hash(sha256, <<"test">>)),
    IssuerSerialB64 = base64:encode(<<"fake-issuer-serial">>),
    CertV2Element = cert_v2_with_issuer(DigestB64, IssuerSerialB64),
    SignatureElement = signature_with_cert_v2(CertV2Element),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    CertV2Props = maps:get(signing_certificate_v2, Props),
    ?assertEqual(crypto:hash(sha256, <<"test">>), maps:get(digest_value, CertV2Props)),
    ?assertEqual(<<"fake-issuer-serial">>, maps:get(issuer_serial_v2, CertV2Props)).

extract_returns_error_with_non_byte_list_digest_value(_Config) ->
    SignatureElement = test_helpers:signature_element([
        {'xades:SigningTime', [], ["2026-01-01T00:00:00Z"]},
        {'xades:SigningCertificateV2', [], [
            {'xades:Cert', [], [
                {'xades:CertDigest', [], [
                    {'ds:DigestMethod', [{'Algorithm', "http://www.w3.org/2001/04/xmlenc#sha256"}],
                        []},
                    {'ds:DigestValue', [], [[65, {invalid}]]}
                ]}
            ]}
        ]}
    ]),
    ?assertEqual(
        {error, invalid_signing_certificate_v2},
        signerl_signed_properties:extract(SignatureElement)
    ).

extract_returns_error_with_non_text_digest_value(_Config) ->
    SignatureElement = test_helpers:signature_element([
        {'xades:SigningTime', [], ["2026-01-01T00:00:00Z"]},
        {'xades:SigningCertificateV2', [], [
            {'xades:Cert', [], [
                {'xades:CertDigest', [], [
                    {'ds:DigestMethod', [{'Algorithm', "http://www.w3.org/2001/04/xmlenc#sha256"}],
                        []},
                    {'ds:DigestValue', [], [12345]}
                ]}
            ]}
        ]}
    ]),
    ?assertEqual(
        {error, invalid_signing_certificate_v2},
        signerl_signed_properties:extract(SignatureElement)
    ).

extract_returns_error_with_empty_binary_digest_value(_Config) ->
    SignatureElement = test_helpers:signature_element([
        {'xades:SigningTime', [], ["2026-01-01T00:00:00Z"]},
        {'xades:SigningCertificateV2', [], [
            {'xades:Cert', [], [
                {'xades:CertDigest', [], [
                    {'ds:DigestMethod', [{'Algorithm', "http://www.w3.org/2001/04/xmlenc#sha256"}],
                        []},
                    {'ds:DigestValue', [], [<<>>]}
                ]}
            ]}
        ]}
    ]),
    ?assertEqual(
        {error, invalid_signing_certificate_v2},
        signerl_signed_properties:extract(SignatureElement)
    ).

extract_returns_error_with_invalid_base64_digest_value(_Config) ->
    SignatureElement = test_helpers:signature_element([
        {'xades:SigningTime', [], ["2026-01-01T00:00:00Z"]},
        {'xades:SigningCertificateV2', [], [
            {'xades:Cert', [], [
                {'xades:CertDigest', [], [
                    {'ds:DigestMethod', [{'Algorithm', "http://www.w3.org/2001/04/xmlenc#sha256"}],
                        []},
                    {'ds:DigestValue', [], ["not valid base64!!!"]}
                ]}
            ]}
        ]}
    ]),
    ?assertEqual(
        {error, invalid_signing_certificate_v2},
        signerl_signed_properties:extract(SignatureElement)
    ).

extract_ignores_invalid_base64_issuer_serial_v2(_Config) ->
    DigestB64 = binary_to_list(base64:encode(crypto:hash(sha256, <<"test">>))),
    CertV2 =
        {'xades:SigningCertificateV2', [], [
            {'xades:Cert', [], [
                cert_digest_element(DigestB64),
                {'xades:IssuerSerialV2', [], ["not valid base64!!!"]}
            ]}
        ]},
    SignatureElement = signature_with_cert_v2(CertV2),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    CertV2Props = maps:get(signing_certificate_v2, Props),
    ?assertNot(maps:is_key(issuer_serial_v2, CertV2Props)).

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
    ?assertEqual(
        {error, invalid_signing_time}, signerl_signed_properties:extract(SignatureElement)
    ).

extract_returns_error_with_non_text_signing_time(_Config) ->
    SignatureElement = test_helpers:signature_element([
        {'xades:SigningTime', [], [123]}
    ]),
    ?assertEqual(
        {error, invalid_signing_time}, signerl_signed_properties:extract(SignatureElement)
    ).

extract_returns_error_with_duplicate_signing_time_property(_Config) ->
    SignatureElement = test_helpers:signature_element([
        {'xades:SigningTime', [], ["2026-01-01T00:00:00Z"]},
        {'xades:SigningTime', [], ["2026-01-01T00:00:00Z"]}
    ]),
    ?assertEqual({error, duplicate_property}, signerl_signed_properties:extract(SignatureElement)).

extract_returns_error_without_signing_time(_Config) ->
    SignatureElement = test_helpers:signature_element([{'xades:SignerRole', [], []}]),
    ?assertEqual(
        {error, missing_signing_time}, signerl_signed_properties:extract(SignatureElement)
    ).
