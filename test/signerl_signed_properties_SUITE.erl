-module(signerl_signed_properties_SUITE).

-include_lib("eunit/include/eunit.hrl").
-compile([export_all, nowarn_export_all]).

suite() ->
    [{timetrap, {seconds, 30}}].

all() ->
    [
        {group, signing_time_group},
        {group, signing_certificate_v2_group},
        {group, signature_policy_group},
        {group, production_place_group},
        {group, signer_role_group},
        {group, data_object_format_group},
        {group, commitment_type_group},
        {group, general_group}
    ].

groups() ->
    [
        {signing_time_group, [], [
            extract_accepts_binary_signing_time,
            extract_returns_error_with_non_byte_list_signing_time,
            extract_returns_error_with_non_text_signing_time,
            extract_returns_error_with_duplicate_signing_time_property,
            extract_returns_error_without_signing_time
        ]},
        {signing_certificate_v2_group, [], [
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
            extract_ignores_invalid_base64_issuer_serial_v2
        ]},
        {signature_policy_group, [], [
            extract_accepts_implied_policy,
            extract_accepts_explicit_policy_with_digest,
            extract_accepts_explicit_policy_with_description,
            extract_accepts_explicit_policy_with_binary_identifier,
            extract_returns_error_with_empty_policy_identifier,
            extract_returns_error_with_missing_policy_id,
            extract_returns_error_with_missing_policy_hash,
            extract_returns_error_with_malformed_policy_hash,
            extract_returns_error_with_missing_policy_identifier_text,
            extract_returns_error_with_non_text_policy_identifier,
            extract_ignores_non_text_policy_description,
            extract_accepts_binary_policy_description,
            extract_returns_error_with_duplicate_policy
        ]},
        {production_place_group, [], [
            extract_accepts_full_production_place,
            extract_accepts_partial_production_place,
            extract_accepts_empty_production_place,
            extract_accepts_binary_production_place,
            extract_skips_non_text_place_fields,
            extract_skips_non_byte_list_place_fields,
            extract_skips_unknown_place_elements,
            extract_returns_error_with_duplicate_production_place
        ]},
        {signer_role_group, [], [
            extract_accepts_claimed_roles,
            extract_accepts_certified_roles,
            extract_accepts_both_role_types,
            extract_skips_non_text_role_items,
            extract_skips_non_matching_role_items,
            extract_returns_error_with_empty_signer_role,
            extract_returns_error_with_duplicate_signer_role
        ]},
        {data_object_format_group, [], [
            extract_accepts_data_object_format_with_mime_type,
            extract_accepts_data_object_format_minimal,
            extract_accepts_multiple_data_object_formats,
            extract_returns_error_with_missing_object_reference,
            extract_accepts_data_object_format_with_all_fields,
            extract_skips_non_text_format_fields,
            extract_ignores_unknown_data_object_elements
        ]},
        {commitment_type_group, [], [
            extract_accepts_commitment_type_with_all_scope,
            extract_accepts_commitment_type_with_references,
            extract_accepts_commitment_type_minimal,
            extract_accepts_multiple_commitment_types,
            extract_returns_error_with_missing_commitment_type_id,
            extract_returns_error_with_missing_commitment_identifier_text
        ]},
        {general_group, [], [
            extract_accepts_all_optional_properties,
            extract_ignores_unknown_signed_signature_properties,
            extract_returns_error_with_invalid_signature_element,
            extract_ignores_unknown_data_object_property_types,
            extract_ignores_non_tuple_data_object_elements,
            extract_returns_error_with_non_byte_list_policy_identifier,
            find_data_obj_props_returns_error_for_non_signature
        ]}
    ].

%%--- Helpers ---

signing_time_element() ->
    {'xades:SigningTime', [], ["2026-01-01T00:00:00Z"]}.

sig_element(SigProps) ->
    test_helpers:signature_element([signing_time_element() | SigProps]).

sig_element_with_data_obj(SigProps, DataObjProps) ->
    test_helpers:signature_element(
        [signing_time_element() | SigProps], DataObjProps
    ).

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
    {'xades:CertDigest', [], digest_elements(DigestB64)}.

cert_v2_with_issuer(DigestB64, IssuerSerialB64) ->
    {'xades:SigningCertificateV2', [], [
        {'xades:Cert', [], [
            cert_digest_element(DigestB64),
            {'xades:IssuerSerialV2', [], [IssuerSerialB64]}
        ]}
    ]}.

signature_with_cert_v2(CertV2) ->
    sig_element([CertV2]).

implied_policy_element() ->
    {'xades:SignaturePolicyIdentifier', [], [
        {'xades:SignaturePolicyImplied', [], []}
    ]}.

explicit_policy_element() ->
    explicit_policy_element([]).

explicit_policy_element(ExtraIdContent) ->
    HashB64 = binary_to_list(base64:encode(crypto:hash(sha256, <<"policy-doc">>))),
    {'xades:SignaturePolicyIdentifier', [], [
        {'xades:SignaturePolicyId', [], [
            {'xades:SigPolicyId', [], [
                {'xades:Identifier', [], ["http://example.com/policy/v1"]}
                | ExtraIdContent
            ]},
            policy_hash_element(HashB64)
        ]}
    ]}.

policy_element_with_id(IdentifierContent) ->
    HashB64 = binary_to_list(base64:encode(<<"hash">>)),
    {'xades:SignaturePolicyIdentifier', [], [
        {'xades:SignaturePolicyId', [], [
            {'xades:SigPolicyId', [], [
                {'xades:Identifier', [], IdentifierContent}
            ]},
            policy_hash_element(HashB64)
        ]}
    ]}.

policy_hash_element(HashB64) ->
    {'xades:SigPolicyHash', [], digest_elements(HashB64)}.

digest_elements(B64Value) ->
    [
        {'ds:DigestMethod', [{'Algorithm', "http://www.w3.org/2001/04/xmlenc#sha256"}], []},
        {'ds:DigestValue', [], [B64Value]}
    ].

policy_id_element(Identifier) ->
    {'xades:SigPolicyId', [], [
        {'xades:Identifier', [], [Identifier]}
    ]}.

production_place_element(Fields) ->
    Children = lists:filtermap(
        fun
            ({city, V}) -> {true, {'xades:City', [], [V]}};
            ({state, V}) -> {true, {'xades:StateOrProvince', [], [V]}};
            ({postal, V}) -> {true, {'xades:PostalCode', [], [V]}};
            ({country, V}) -> {true, {'xades:CountryName', [], [V]}}
        end,
        Fields
    ),
    {'xades:SignatureProductionPlace', [], Children}.

signer_role_element(Claimed, Certified) ->
    ClaimedPart =
        case Claimed of
            [] ->
                [];
            _ ->
                [{'xades:ClaimedRoles', [], [{'xades:ClaimedRole', [], [R]} || R <- Claimed]}]
        end,
    CertifiedPart =
        case Certified of
            [] ->
                [];
            _ ->
                [{'xades:CertifiedRoles', [], [{'xades:CertifiedRole', [], [R]} || R <- Certified]}]
        end,
    {'xades:SignerRole', [], ClaimedPart ++ CertifiedPart}.

data_object_format_element(ObjectRef, Fields) ->
    Children = lists:filtermap(
        fun
            ({mime_type, V}) -> {true, {'xades:MimeType', [], [V]}};
            ({description, V}) -> {true, {'xades:Description', [], [V]}};
            ({encoding, V}) -> {true, {'xades:Encoding', [], [V]}}
        end,
        Fields
    ),
    {'xades:DataObjectFormat', [{'ObjectReference', ObjectRef}], Children}.

commitment_type_element(Identifier, Scope) ->
    IdElement =
        {'xades:CommitmentTypeId', [], [
            {'xades:Identifier', [], [Identifier]}
        ]},
    ScopeElements =
        case Scope of
            all -> [{'xades:AllSignedDataObjects', [], []}];
            {references, Refs} -> [{'xades:ObjectReference', [], [R]} || R <- Refs];
            none -> []
        end,
    {'xades:CommitmentTypeIndication', [], [IdElement | ScopeElements]}.

%%--- SigningTime tests ---

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
    SignatureElement = test_helpers:signature_element([]),
    ?assertEqual(
        {error, missing_signing_time}, signerl_signed_properties:extract(SignatureElement)
    ).

%%--- SigningCertificateV2 tests ---

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
    SignatureElement = sig_element([
        {'xades:SigningCertificateV2', [], []}
    ]),
    ?assertEqual(
        {error, invalid_signing_certificate_v2},
        signerl_signed_properties:extract(SignatureElement)
    ).

extract_returns_error_with_missing_cert_digest(_Config) ->
    SignatureElement = sig_element([
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
    SignatureElement = sig_element([
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
    SignatureElement = sig_element([CertV2, CertV2]),
    ?assertEqual(
        {error, duplicate_property},
        signerl_signed_properties:extract(SignatureElement)
    ).

extract_returns_error_with_missing_digest_method(_Config) ->
    DigestB64 = binary_to_list(base64:encode(crypto:hash(sha256, <<"test">>))),
    SignatureElement = sig_element([
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
    SignatureElement = sig_element([
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
    SignatureElement = sig_element([
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
    SignatureElement = sig_element([
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
    SignatureElement = sig_element([
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

%%--- SignaturePolicyIdentifier tests ---

extract_accepts_implied_policy(_Config) ->
    SignatureElement = sig_element([implied_policy_element()]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    ?assertEqual(#{type => implied}, maps:get(signature_policy_identifier, Props)).

extract_accepts_explicit_policy_with_digest(_Config) ->
    SignatureElement = sig_element([explicit_policy_element()]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    Policy = maps:get(signature_policy_identifier, Props),
    ?assertEqual(explicit, maps:get(type, Policy)),
    ?assertEqual(<<"http://example.com/policy/v1">>, maps:get(identifier, Policy)),
    ?assertEqual("http://www.w3.org/2001/04/xmlenc#sha256", maps:get(digest_method, Policy)),
    ExpectedHash = crypto:hash(sha256, <<"policy-doc">>),
    ?assertEqual(ExpectedHash, maps:get(digest_value, Policy)).

extract_accepts_explicit_policy_with_description(_Config) ->
    PolicyElement = explicit_policy_element([
        {'xades:Description', [], ["Human-readable policy"]}
    ]),
    SignatureElement = sig_element([PolicyElement]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    Policy = maps:get(signature_policy_identifier, Props),
    ?assertEqual(<<"Human-readable policy">>, maps:get(description, Policy)).

extract_accepts_explicit_policy_with_binary_identifier(_Config) ->
    PolicyElement = policy_element_with_id([<<"http://example.com/bin-policy">>]),
    SignatureElement = sig_element([PolicyElement]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    Policy = maps:get(signature_policy_identifier, Props),
    ?assertEqual(<<"http://example.com/bin-policy">>, maps:get(identifier, Policy)).

extract_returns_error_with_empty_policy_identifier(_Config) ->
    SignatureElement = sig_element([
        {'xades:SignaturePolicyIdentifier', [], []}
    ]),
    ?assertEqual(
        {error, invalid_signature_policy_identifier},
        signerl_signed_properties:extract(SignatureElement)
    ).

extract_returns_error_with_missing_policy_id(_Config) ->
    HashB64 = binary_to_list(base64:encode(<<"hash">>)),
    SignatureElement = sig_element([
        {'xades:SignaturePolicyIdentifier', [], [
            {'xades:SignaturePolicyId', [], [
                policy_hash_element(HashB64)
            ]}
        ]}
    ]),
    ?assertEqual(
        {error, invalid_signature_policy_identifier},
        signerl_signed_properties:extract(SignatureElement)
    ).

extract_returns_error_with_missing_policy_hash(_Config) ->
    SignatureElement = sig_element([
        {'xades:SignaturePolicyIdentifier', [], [
            {'xades:SignaturePolicyId', [], [
                policy_id_element("http://example.com/policy")
            ]}
        ]}
    ]),
    ?assertEqual(
        {error, invalid_signature_policy_identifier},
        signerl_signed_properties:extract(SignatureElement)
    ).

extract_returns_error_with_missing_policy_identifier_text(_Config) ->
    SignatureElement = sig_element([policy_element_with_id([])]),
    ?assertEqual(
        {error, invalid_signature_policy_identifier},
        signerl_signed_properties:extract(SignatureElement)
    ).

extract_returns_error_with_non_text_policy_identifier(_Config) ->
    SignatureElement = sig_element([policy_element_with_id([12345])]),
    ?assertEqual(
        {error, invalid_signature_policy_identifier},
        signerl_signed_properties:extract(SignatureElement)
    ).

extract_ignores_non_text_policy_description(_Config) ->
    PolicyElement = explicit_policy_element([
        {'xades:Description', [], [12345]}
    ]),
    SignatureElement = sig_element([PolicyElement]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    Policy = maps:get(signature_policy_identifier, Props),
    ?assertNot(maps:is_key(description, Policy)).

extract_accepts_binary_policy_description(_Config) ->
    PolicyElement = explicit_policy_element([
        {'xades:Description', [], [<<"Binary description">>]}
    ]),
    SignatureElement = sig_element([PolicyElement]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    Policy = maps:get(signature_policy_identifier, Props),
    ?assertEqual(<<"Binary description">>, maps:get(description, Policy)).

extract_returns_error_with_malformed_policy_hash(_Config) ->
    SignatureElement = sig_element([
        {'xades:SignaturePolicyIdentifier', [], [
            {'xades:SignaturePolicyId', [], [
                policy_id_element("http://example.com/policy"),
                {'xades:SigPolicyHash', [], [
                    {'ds:DigestValue', [], ["aGFzaA=="]}
                ]}
            ]}
        ]}
    ]),
    ?assertEqual(
        {error, invalid_signature_policy_identifier},
        signerl_signed_properties:extract(SignatureElement)
    ).

extract_returns_error_with_duplicate_policy(_Config) ->
    SignatureElement = sig_element([
        implied_policy_element(),
        implied_policy_element()
    ]),
    ?assertEqual(
        {error, duplicate_property},
        signerl_signed_properties:extract(SignatureElement)
    ).

%%--- SignatureProductionPlace tests ---

extract_accepts_full_production_place(_Config) ->
    Place = production_place_element([
        {city, "Budapest"}, {state, "Budapest"}, {postal, "1234"}, {country, "HU"}
    ]),
    SignatureElement = sig_element([Place]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    ?assertEqual(
        #{
            city => <<"Budapest">>,
            state_or_province => <<"Budapest">>,
            postal_code => <<"1234">>,
            country_name => <<"HU">>
        },
        maps:get(signature_production_place, Props)
    ).

extract_accepts_partial_production_place(_Config) ->
    Place = production_place_element([{city, "Berlin"}, {country, "DE"}]),
    SignatureElement = sig_element([Place]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    ?assertEqual(
        #{city => <<"Berlin">>, country_name => <<"DE">>},
        maps:get(signature_production_place, Props)
    ).

extract_accepts_empty_production_place(_Config) ->
    Place = production_place_element([]),
    SignatureElement = sig_element([Place]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    ?assertEqual(#{}, maps:get(signature_production_place, Props)).

extract_accepts_binary_production_place(_Config) ->
    Place =
        {'xades:SignatureProductionPlace', [], [
            {'xades:City', [], [<<"Wien">>]},
            {'xades:CountryName', [], [<<"AT">>]}
        ]},
    SignatureElement = sig_element([Place]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    ?assertEqual(
        #{city => <<"Wien">>, country_name => <<"AT">>},
        maps:get(signature_production_place, Props)
    ).

extract_skips_non_text_place_fields(_Config) ->
    Place =
        {'xades:SignatureProductionPlace', [], [
            {'xades:City', [], ["Budapest"]},
            {'xades:PostalCode', [], [12345]},
            {'xades:CountryName', [], [[65, {invalid}]]}
        ]},
    SignatureElement = sig_element([Place]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    ?assertEqual(#{city => <<"Budapest">>}, maps:get(signature_production_place, Props)).

extract_skips_non_byte_list_place_fields(_Config) ->
    Place =
        {'xades:SignatureProductionPlace', [], [
            {'xades:City', [], [[65, {invalid}]]},
            {'xades:StateOrProvince', [], [42]}
        ]},
    SignatureElement = sig_element([Place]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    ?assertEqual(#{}, maps:get(signature_production_place, Props)).

extract_skips_unknown_place_elements(_Config) ->
    Place =
        {'xades:SignatureProductionPlace', [], [
            {'xades:City', [], ["Vienna"]},
            {'xades:UnknownField', [], ["ignored"]},
            "text node ignored"
        ]},
    SignatureElement = sig_element([Place]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    ?assertEqual(#{city => <<"Vienna">>}, maps:get(signature_production_place, Props)).

extract_returns_error_with_duplicate_production_place(_Config) ->
    Place = production_place_element([{city, "A"}]),
    SignatureElement = sig_element([Place, Place]),
    ?assertEqual(
        {error, duplicate_property},
        signerl_signed_properties:extract(SignatureElement)
    ).

%%--- SignerRole tests ---

extract_accepts_claimed_roles(_Config) ->
    Role = signer_role_element(["Manager", "Developer"], []),
    SignatureElement = sig_element([Role]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    ?assertEqual(
        #{claimed_roles => [<<"Manager">>, <<"Developer">>]},
        maps:get(signer_role, Props)
    ).

extract_accepts_certified_roles(_Config) ->
    Role = signer_role_element([], ["cert-data-1"]),
    SignatureElement = sig_element([Role]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    ?assertEqual(
        #{certified_roles => [<<"cert-data-1">>]},
        maps:get(signer_role, Props)
    ).

extract_accepts_both_role_types(_Config) ->
    Role = signer_role_element(["Manager"], ["cert-data"]),
    SignatureElement = sig_element([Role]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    ?assertEqual(
        #{claimed_roles => [<<"Manager">>], certified_roles => [<<"cert-data">>]},
        maps:get(signer_role, Props)
    ).

extract_skips_non_text_role_items(_Config) ->
    Role =
        {'xades:SignerRole', [], [
            {'xades:ClaimedRoles', [], [
                {'xades:ClaimedRole', [], ["Valid"]},
                {'xades:ClaimedRole', [], [12345]},
                {'xades:ClaimedRole', [], [[65, {invalid}]]}
            ]}
        ]},
    SignatureElement = sig_element([Role]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    ?assertEqual(#{claimed_roles => [<<"Valid">>]}, maps:get(signer_role, Props)).

extract_skips_non_matching_role_items(_Config) ->
    Role =
        {'xades:SignerRole', [], [
            {'xades:ClaimedRoles', [], [
                {'xades:ClaimedRole', [], ["Admin"]},
                {'xades:UnknownElement', [], ["ignored"]}
            ]}
        ]},
    SignatureElement = sig_element([Role]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    ?assertEqual(#{claimed_roles => [<<"Admin">>]}, maps:get(signer_role, Props)).

extract_returns_error_with_empty_signer_role(_Config) ->
    SignatureElement = sig_element([
        {'xades:SignerRole', [], []}
    ]),
    ?assertEqual(
        {error, invalid_signer_role},
        signerl_signed_properties:extract(SignatureElement)
    ).

extract_returns_error_with_duplicate_signer_role(_Config) ->
    Role = signer_role_element(["Admin"], []),
    SignatureElement = sig_element([Role, Role]),
    ?assertEqual(
        {error, duplicate_property},
        signerl_signed_properties:extract(SignatureElement)
    ).

%%--- DataObjectFormat tests ---

extract_accepts_data_object_format_with_mime_type(_Config) ->
    Format = data_object_format_element("#Ref-1", [{mime_type, "application/xml"}]),
    SignatureElement = sig_element_with_data_obj([], [Format]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    ?assertEqual(
        [#{object_reference => "#Ref-1", mime_type => <<"application/xml">>}],
        maps:get(data_object_formats, Props)
    ).

extract_accepts_data_object_format_minimal(_Config) ->
    Format = data_object_format_element("#Ref-1", []),
    SignatureElement = sig_element_with_data_obj([], [Format]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    ?assertEqual(
        [#{object_reference => "#Ref-1"}],
        maps:get(data_object_formats, Props)
    ).

extract_accepts_multiple_data_object_formats(_Config) ->
    Format1 = data_object_format_element("#Ref-1", [{mime_type, "application/xml"}]),
    Format2 = data_object_format_element("#Ref-2", [{mime_type, "text/plain"}]),
    SignatureElement = sig_element_with_data_obj([], [Format1, Format2]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    ?assertEqual(2, length(maps:get(data_object_formats, Props))).

extract_returns_error_with_missing_object_reference(_Config) ->
    Format =
        {'xades:DataObjectFormat', [], [
            {'xades:MimeType', [], ["text/plain"]}
        ]},
    SignatureElement = sig_element_with_data_obj([], [Format]),
    ?assertEqual(
        {error, invalid_data_object_format},
        signerl_signed_properties:extract(SignatureElement)
    ).

extract_accepts_data_object_format_with_all_fields(_Config) ->
    Format = data_object_format_element("#Ref-1", [
        {description, "Invoice"}, {mime_type, "application/xml"}, {encoding, "UTF-8"}
    ]),
    SignatureElement = sig_element_with_data_obj([], [Format]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    [F] = maps:get(data_object_formats, Props),
    ?assertEqual(<<"Invoice">>, maps:get(description, F)),
    ?assertEqual(<<"application/xml">>, maps:get(mime_type, F)),
    ?assertEqual(<<"UTF-8">>, maps:get(encoding, F)).

extract_skips_non_text_format_fields(_Config) ->
    Format =
        {'xades:DataObjectFormat', [{'ObjectReference', "#Ref-1"}], [
            {'xades:MimeType', [], [12345]},
            {'xades:Description', [], [[65, {invalid}]]},
            {'xades:Encoding', [], ["UTF-8"]}
        ]},
    SignatureElement = sig_element_with_data_obj([], [Format]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    [F] = maps:get(data_object_formats, Props),
    ?assertEqual(<<"UTF-8">>, maps:get(encoding, F)),
    ?assertNot(maps:is_key(mime_type, F)),
    ?assertNot(maps:is_key(description, F)).

extract_ignores_unknown_data_object_elements(_Config) ->
    Format =
        {'xades:DataObjectFormat', [{'ObjectReference', "#Ref-1"}], [
            {'xades:MimeType', [], ["text/plain"]},
            {'xades:UnknownChild', [], ["ignored"]}
        ]},
    SignatureElement = sig_element_with_data_obj([], [Format]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    [F] = maps:get(data_object_formats, Props),
    ?assertEqual(<<"text/plain">>, maps:get(mime_type, F)).

%%--- CommitmentTypeIndication tests ---

extract_accepts_commitment_type_with_all_scope(_Config) ->
    Commitment = commitment_type_element(
        "http://uri.etsi.org/01903/v1.2.2#ProofOfOrigin", all
    ),
    SignatureElement = sig_element_with_data_obj([], [Commitment]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    [C] = maps:get(commitment_type_indications, Props),
    ?assertEqual(<<"http://uri.etsi.org/01903/v1.2.2#ProofOfOrigin">>, maps:get(identifier, C)),
    ?assertEqual(all, maps:get(scope, C)).

extract_accepts_commitment_type_with_references(_Config) ->
    Commitment = commitment_type_element(
        "http://uri.etsi.org/01903/v1.2.2#ProofOfApproval",
        {references, ["#Ref-1", "#Ref-2"]}
    ),
    SignatureElement = sig_element_with_data_obj([], [Commitment]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    [C] = maps:get(commitment_type_indications, Props),
    ?assertEqual({references, ["#Ref-1", "#Ref-2"]}, maps:get(scope, C)).

extract_accepts_commitment_type_minimal(_Config) ->
    Commitment = commitment_type_element(
        "http://uri.etsi.org/01903/v1.2.2#ProofOfOrigin", none
    ),
    SignatureElement = sig_element_with_data_obj([], [Commitment]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    [C] = maps:get(commitment_type_indications, Props),
    ?assertEqual(<<"http://uri.etsi.org/01903/v1.2.2#ProofOfOrigin">>, maps:get(identifier, C)),
    ?assertNot(maps:is_key(scope, C)).

extract_accepts_multiple_commitment_types(_Config) ->
    C1 = commitment_type_element("http://example.com/origin", all),
    C2 = commitment_type_element("http://example.com/approval", none),
    SignatureElement = sig_element_with_data_obj([], [C1, C2]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    ?assertEqual(2, length(maps:get(commitment_type_indications, Props))).

extract_returns_error_with_missing_commitment_type_id(_Config) ->
    Commitment =
        {'xades:CommitmentTypeIndication', [], [
            {'xades:AllSignedDataObjects', [], []}
        ]},
    SignatureElement = sig_element_with_data_obj([], [Commitment]),
    ?assertEqual(
        {error, invalid_commitment_type_indication},
        signerl_signed_properties:extract(SignatureElement)
    ).

extract_returns_error_with_missing_commitment_identifier_text(_Config) ->
    Commitment =
        {'xades:CommitmentTypeIndication', [], [
            {'xades:CommitmentTypeId', [], [
                {'xades:Identifier', [], []}
            ]}
        ]},
    SignatureElement = sig_element_with_data_obj([], [Commitment]),
    ?assertEqual(
        {error, invalid_commitment_type_indication},
        signerl_signed_properties:extract(SignatureElement)
    ).

%%--- General tests ---

extract_accepts_all_optional_properties(_Config) ->
    CertV2 = valid_signing_certificate_v2_element(),
    Policy = implied_policy_element(),
    Place = production_place_element([{city, "Budapest"}, {country, "HU"}]),
    Role = signer_role_element(["Manager"], []),
    Format = data_object_format_element("#Ref-1", [{mime_type, "application/xml"}]),
    Commitment = commitment_type_element("http://example.com/origin", all),
    SignatureElement = test_helpers:signature_element(
        [
            signing_time_element(),
            {'xades:SigningCertificate', [], []},
            CertV2,
            Policy,
            Place,
            Role
        ],
        [Format, Commitment]
    ),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    ?assertEqual(<<"2026-01-01T00:00:00Z">>, maps:get(signing_time, Props)),
    ?assertEqual(present, maps:get(signing_certificate, Props)),
    ?assert(maps:is_key(signing_certificate_v2, Props)),
    ?assertEqual(#{type => implied}, maps:get(signature_policy_identifier, Props)),
    ?assertEqual(
        #{city => <<"Budapest">>, country_name => <<"HU">>},
        maps:get(signature_production_place, Props)
    ),
    ?assertEqual(#{claimed_roles => [<<"Manager">>]}, maps:get(signer_role, Props)),
    ?assertEqual(1, length(maps:get(data_object_formats, Props))),
    ?assertEqual(1, length(maps:get(commitment_type_indications, Props))).

extract_ignores_unknown_signed_signature_properties(_Config) ->
    SignatureElement = test_helpers:signature_element([
        {'xades:SigningTime', [], ["2026-01-01T00:00:00Z"]},
        {'xades:UnknownProperty', [], ["ignored"]}
    ]),
    ?assertEqual(
        {ok, #{signing_time => <<"2026-01-01T00:00:00Z">>}},
        signerl_signed_properties:extract(SignatureElement)
    ).

extract_returns_error_with_invalid_signature_element(_Config) ->
    ?assertEqual(
        {error, missing_element},
        signerl_signed_properties:extract({not_a_signature, [], []})
    ).

extract_ignores_unknown_data_object_property_types(_Config) ->
    UnknownElement = {'xades:FutureProperty', [], ["value"]},
    Format = data_object_format_element("#Ref-1", [{mime_type, "text/plain"}]),
    SignatureElement = sig_element_with_data_obj([], [UnknownElement, Format]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    ?assertEqual(1, length(maps:get(data_object_formats, Props))).

extract_ignores_non_tuple_data_object_elements(_Config) ->
    Format = data_object_format_element("#Ref-1", [{mime_type, "text/plain"}]),
    SignatureElement = sig_element_with_data_obj([], ["text node", Format]),
    {ok, Props} = signerl_signed_properties:extract(SignatureElement),
    ?assertEqual(1, length(maps:get(data_object_formats, Props))).

extract_returns_error_with_non_byte_list_policy_identifier(_Config) ->
    SignatureElement = sig_element([policy_element_with_id([[65, {invalid}]])]),
    ?assertEqual(
        {error, invalid_signature_policy_identifier},
        signerl_signed_properties:extract(SignatureElement)
    ).

find_data_obj_props_returns_error_for_non_signature(_Config) ->
    ?assertEqual(
        {error, missing_element},
        signerl_xades_xml:find_signed_data_object_properties(not_a_tuple)
    ).
