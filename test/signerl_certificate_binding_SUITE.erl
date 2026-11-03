-module(signerl_certificate_binding_SUITE).

-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").
-include("signerl_dsig.hrl").
-compile([export_all, nowarn_export_all]).

suite() -> [{timetrap, {seconds, 30}}].
all() ->
    [
        signing_key_binding,
        malformed_embedded_certificate,
        certificate_cardinality,
        certificate_container_content,
        one_sided_metadata,
        malformed_certificate_properties,
        certificate_metadata_values,
        verification_key_binding,
        certificate_less_arities,
        optional_issuer,
        certificate_namespaces,
        legacy_marker_is_not_binding,
        malformed_certificate_keys
    ].

init_per_suite(Config) ->
    Key = signerl_cert_helpers:signer_rsa_key(),
    Cert = signerl_cert_helpers:cert_der(signerl_cert_helpers:signer_rsa_cert_path()),
    Public = signerl_cert_helpers:rsa_public_key(Cert),
    Raw = <<"<?xml version='1.0'?><invoice><amount>42.00</amount></invoice>">>,
    Signed = signerl:sign(Raw, sha256, Key, Cert),
    Parsed = test_helpers:parse_verified_message(Signed, Public),
    [{key, Key}, {cert, Cert}, {public_key, Public}, {raw, Raw}, {parsed, Parsed} | Config].
end_per_suite(_Config) -> ok.

signing_key_binding(Config) ->
    Raw = ?config(raw, Config),
    Key = ?config(key, Config),
    Cert = ?config(cert, Config),
    EcKey = signerl_cert_helpers:signer_ecdsa_key(),
    EcCert = signerl_cert_helpers:cert_der(signerl_cert_helpers:signer_ecdsa_cert_path()),
    EcSigned = signerl:sign(Raw, sha256, EcKey, EcCert),
    test_helpers:parse_verified_message(EcSigned, signerl_cert_helpers:ecdsa_public_key(EcCert)),
    OtherCert = signerl_cert_helpers:cert_der(signerl_cert_helpers:leaf_cert_path()),
    lists:foreach(
        fun({K, C}) ->
            ?assertError(certificate_key_mismatch, signerl:sign(Raw, sha256, K, C))
        end,
        [{Key, OtherCert}, {Key, EcCert}, {EcKey, Cert}]
    ).

malformed_embedded_certificate(Config) ->
    Tree = ?config(parsed, Config),
    lists:foreach(
        fun({Label, Value}) ->
            Changed = test_helpers:update_xml(Tree, <<"ds:X509Certificate">>, fun({N, A, _}) ->
                {N, A, [Value]}
            end),
            assert_rejected(Label, Changed, Config)
        end,
        [
            {base64, "!!!invalid!!!"},
            {empty, ""},
            {der, base64:encode(<<1, 2, 3>>)},
            {trailing_der, base64:encode(<<(?config(cert, Config))/binary, 0>>)}
        ]
    ),
    Child = test_helpers:update_xml(Tree, <<"ds:X509Certificate">>, fun({N, A, _}) ->
        {N, A, [{<<"invalid">>, [], []}]}
    end),
    assert_rejected(non_text_certificate, Child, Config).

certificate_cardinality(Config) ->
    Tree = ?config(parsed, Config),
    lists:foreach(
        fun({Label, Parent, Child}) ->
            assert_rejected(Label, duplicate(Tree, Parent, Child), Config)
        end,
        [
            {key_info, <<"ds:Signature">>, <<"ds:KeyInfo">>},
            {x509_data, <<"ds:KeyInfo">>, <<"ds:X509Data">>},
            {certificate, <<"ds:X509Data">>, <<"ds:X509Certificate">>}
        ]
    ),
    lists:foreach(
        fun({Parent, Child}) ->
            assert_rejected(Child, remove(Tree, Parent, Child), Config)
        end,
        [
            {<<"ds:KeyInfo">>, <<"ds:X509Data">>},
            {<<"ds:X509Data">>, <<"ds:X509Certificate">>}
        ]
    ).

certificate_container_content(Config) ->
    Tree = ?config(parsed, Config),
    lists:foreach(
        fun({Parent, Extra}) ->
            Changed = test_helpers:update_xml(Tree, Parent, fun({N, A, C}) ->
                {N, A, [Extra | C]}
            end),
            assert_rejected(ambiguous_certificate_content, Changed, Config)
        end,
        [
            {<<"ds:KeyInfo">>, {<<"ds:KeyValue">>, [], []}},
            {<<"ds:X509Data">>, {<<"wrapper">>, [], [{<<"ds:X509Certificate">>, [], ["AQID"]}]}},
            {<<"ds:X509Data">>, "unexpected"}
        ]
    ),
    Spaced = lists:foldl(
        fun(Tag, Acc) ->
            test_helpers:update_xml(Acc, Tag, fun({N, A, C}) -> {N, A, ["\n  " | C] ++ ["\n"]} end)
        end,
        Tree,
        [<<"ds:KeyInfo">>, <<"ds:X509Data">>]
    ),
    test_helpers:parse_verified_message(xmlan:export([], Spaced), ?config(public_key, Config)).

one_sided_metadata(Config) ->
    Tree = ?config(parsed, Config),
    assert_rejected(no_keyinfo, remove(Tree, <<"ds:Signature">>, <<"ds:KeyInfo">>), Config),
    assert_rejected(
        no_property,
        remove(Tree, <<"xades:SignedSignatureProperties">>, <<"xades:SigningCertificateV2">>),
        Config
    ).

malformed_certificate_properties(Config) ->
    Tree = ?config(parsed, Config),
    lists:foreach(
        fun({Label, Parent, Child}) ->
            assert_rejected(Label, duplicate(Tree, Parent, Child), Config)
        end,
        [
            {property, <<"xades:SignedSignatureProperties">>, <<"xades:SigningCertificateV2">>},
            {cert, <<"xades:SigningCertificateV2">>, <<"xades:Cert">>},
            {digest, <<"xades:Cert">>, <<"xades:CertDigest">>},
            {issuer, <<"xades:Cert">>, <<"xades:IssuerSerialV2">>},
            {method, <<"xades:CertDigest">>, <<"ds:DigestMethod">>},
            {value, <<"xades:CertDigest">>, <<"ds:DigestValue">>}
        ]
    ),
    lists:foreach(
        fun(Tag) ->
            lists:foreach(
                fun(Value) ->
                    Changed = test_helpers:update_xml(Tree, Tag, fun({N, A, _}) ->
                        {N, A, [Value]}
                    end),
                    assert_rejected(Tag, Changed, Config)
                end,
                ["!!!invalid!!!", {<<"invalid">>, [], []}]
            )
        end,
        [<<"xades:IssuerSerialV2">>]
    ).

certificate_metadata_values(Config) ->
    Tree = ?config(parsed, Config),
    WrongIssuer = test_helpers:update_xml(Tree, <<"xades:IssuerSerialV2">>, fun({N, A, _}) ->
        {N, A, [base64:encode(<<1, 2, 3>>)]}
    end),
    assert_rejected(issuer_value, WrongIssuer, Config),
    WrongDigest = test_helpers:update_xml(Tree, <<"xades:CertDigest">>, fun(E) ->
        test_helpers:update_xml(E, <<"ds:DigestValue">>, fun({N, A, _}) ->
            {N, A, [base64:encode(<<0:256>>)]}
        end)
    end),
    assert_rejected(digest_value, WrongDigest, Config),
    WrongMethod = test_helpers:update_xml(Tree, <<"xades:CertDigest">>, fun(E) ->
        test_helpers:update_xml(E, <<"ds:DigestMethod">>, fun({N, _, C}) ->
            {N, [{<<"Algorithm">>, ?DSIG_DIGEST_SHA512_URI}], C}
        end)
    end),
    assert_rejected(digest_method, WrongMethod, Config).

verification_key_binding(Config) ->
    Tree = ?config(parsed, Config),
    lists:foreach(
        fun(Cert) ->
            Changed = replace_certificate(Tree, Cert),
            assert_rejected(unrelated_certificate, Changed, Config)
        end,
        [
            signerl_cert_helpers:cert_der(signerl_cert_helpers:leaf_cert_path()),
            signerl_cert_helpers:cert_der(signerl_cert_helpers:signer_ecdsa_cert_path())
        ]
    ),
    %% A wrong supplied RSA key remains a cryptographic mismatch.
    OtherPublic = signerl_cert_helpers:rsa_public_key_from_cert(
        signerl_cert_helpers:leaf_cert_path()
    ),
    ?assertEqual(false, signerl:verify(xmlan:export([], Tree), sha256, OtherPublic)),
    ?assertEqual(true, signerl:verify(xmlan:export([], Tree), sha256, ?config(key, Config))).

certificate_less_arities(Config) ->
    Raw = ?config(raw, Config),
    Key = ?config(key, Config),
    lists:foreach(
        fun(Signed) ->
            Parsed = test_helpers:parse_verified_message(Signed, ?config(public_key, Config)),
            {ok, Data} = signerl_verify:extract_signature_data(Parsed),
            #{signed_properties := Props, key_info := undefined} = Data,
            ?assert(maps:is_key(signing_time, Props)),
            ?assertNot(maps:is_key(signing_certificate_v2, Props))
        end,
        [
            signerl:sign(Raw, sha256, Key),
            signerl:sign(Raw, sha256, Key, undefined),
            signerl:sign(Raw, sha256, Key, undefined, <<"2026-10-27T12:00:00Z">>)
        ]
    ).

optional_issuer(Config) ->
    Tree = ?config(parsed, Config),
    Without = remove(Tree, <<"xades:Cert">>, <<"xades:IssuerSerialV2">>),
    Signed = test_helpers:refresh_signature(Without, Config),
    test_helpers:parse_verified_message(Signed, ?config(public_key, Config)).

certificate_namespaces(Config) ->
    Tree = ?config(parsed, Config),
    Alias = test_helpers:update_xml(Tree, <<"ds:X509Certificate">>, fun({_, A, C}) ->
        {<<"cert:X509Certificate">>, [{<<"xmlns:cert">>, ?DSIG_NAMESPACE_URI} | A], C}
    end),
    test_helpers:parse_verified_message(xmlan:export([], Alias), ?config(public_key, Config)),
    lists:foreach(
        fun(Tag) ->
            Changed = test_helpers:update_xml(Tree, Tag, fun({N, A, C}) ->
                {N, [{<<"xmlns:ds">>, "urn:wrong"} | A], C}
            end),
            assert_rejected(wrong_namespace, Changed, Config)
        end,
        [<<"ds:X509Data">>, <<"ds:X509Certificate">>]
    ).

legacy_marker_is_not_binding(Config) ->
    Bare = signerl:sign(?config(raw, Config), sha256, ?config(key, Config)),
    Tree = test_helpers:parse_verified_message(Bare, ?config(public_key, Config)),
    Marked = test_helpers:update_xml(Tree, <<"xades:SignedSignatureProperties">>, fun({N, A, C}) ->
        {N, A, C ++ [{<<"xades:SigningCertificate">>, [], []}]}
    end),
    assert_rejected(legacy_marker, Marked, Config).

malformed_certificate_keys(Config) ->
    RsaKeyDer = public_key:der_encode('RSAPublicKey', {'RSAPublicKey', 0, 65537}),
    Restricted = signerl_cert_helpers:replace_certificate_algorithm(?config(cert, Config)),
    assert_rejected(
        restricted_rsa_scheme,
        replace_certificate(?config(parsed, Config), Restricted),
        Config
    ),
    BadRsa = signerl_cert_helpers:replace_certificate_key(?config(cert, Config), RsaKeyDer),
    assert_rejected(invalid_rsa_key, replace_certificate(?config(parsed, Config), BadRsa), Config),
    EcKey = signerl_cert_helpers:signer_ecdsa_key(),
    EcCert = signerl_cert_helpers:cert_der(signerl_cert_helpers:signer_ecdsa_cert_path()),
    EcPublic = signerl_cert_helpers:ecdsa_public_key(EcCert),
    Signed = signerl:sign(?config(raw, Config), sha256, EcKey, EcCert),
    EcTree = test_helpers:parse_verified_message(Signed, EcPublic),
    BadEc = signerl_cert_helpers:replace_certificate_key(EcCert, <<4, 1, 2>>),
    assert_rejected(
        invalid_ec_point,
        replace_certificate(EcTree, BadEc),
        [{key, EcKey}, {public_key, EcPublic}, {parsed, EcTree} | Config]
    ).

assert_rejected(Label, Tree, Config) ->
    ?assertNotEqual(?config(parsed, Config), Tree),
    Signed = test_helpers:refresh_signature(Tree, Config),
    Result = signerl:verify(Signed, sha256, ?config(public_key, Config)),
    ?assertMatch({Label, {error, _}}, {Label, Result}).

replace_certificate(Tree, Cert) ->
    NewCert = test_helpers:update_xml(Tree, <<"ds:X509Certificate">>, fun({N, A, _}) ->
        {N, A, [base64:encode(Cert)]}
    end),
    NewDigest = test_helpers:update_xml(NewCert, <<"xades:CertDigest">>, fun(E) ->
        test_helpers:update_xml(E, <<"ds:DigestValue">>, fun({N, A, _}) ->
            {N, A, [base64:encode(crypto:hash(sha256, Cert))]}
        end)
    end),
    test_helpers:update_xml(NewDigest, <<"xades:IssuerSerialV2">>, fun({N, A, _}) ->
        {N, A, [signerl_cert:issuer_serial_v2_base64(Cert)]}
    end).

remove(Tree, Parent, Tag) ->
    test_helpers:update_xml(Tree, Parent, fun({N, A, C}) -> {N, A, lists:keydelete(Tag, 1, C)} end).
duplicate(Tree, Parent, Tag) ->
    test_helpers:update_xml(Tree, Parent, fun({N, A, C}) ->
        {N, A, C ++ [lists:keyfind(Tag, 1, C)]}
    end).
