-module(test_helpers).

-export([
    rsa_public_key_from_cert/1,
    ecdsa_public_key_from_cert/1,
    cert_der/1,
    signature_element/1,
    signature_element/2,
    parse_verified_message/2,
    replace_once/3
]).

-include_lib("public_key/include/OTP-PUB-KEY.hrl").
-include_lib("eunit/include/eunit.hrl").

rsa_public_key_from_cert(CertPath) ->
    % Use pkix_decode_cert/2 for typed, future-proof access to the SPKI.
    {ok, CertRaw} = file:read_file(CertPath),
    [PemEntry] = public_key:pem_decode(CertRaw),
    {_, Der, _} = PemEntry,
    Cert = public_key:pkix_decode_cert(Der, otp),
    Tbs = Cert#'OTPCertificate'.tbsCertificate,
    Spki = Tbs#'OTPTBSCertificate'.subjectPublicKeyInfo,
    KeyBits = Spki#'OTPSubjectPublicKeyInfo'.subjectPublicKey,
    case KeyBits of
        #'RSAPublicKey'{} -> KeyBits;
        _ when is_binary(KeyBits) -> public_key:der_decode('RSAPublicKey', KeyBits)
    end.

ecdsa_public_key_from_cert(CertPath) ->
    % pkix_decode_cert/2 returns OTP records that expose curve params + EC point.
    {ok, CertRaw} = file:read_file(CertPath),
    [PemEntry] = public_key:pem_decode(CertRaw),
    {_, Der, _} = PemEntry,
    Cert = public_key:pkix_decode_cert(Der, otp),
    Tbs = Cert#'OTPCertificate'.tbsCertificate,
    Spki = Tbs#'OTPTBSCertificate'.subjectPublicKeyInfo,
    Alg = Spki#'OTPSubjectPublicKeyInfo'.algorithm,
    Params = Alg#'PublicKeyAlgorithm'.parameters,
    PointRec = Spki#'OTPSubjectPublicKeyInfo'.subjectPublicKey,
    {PointRec, Params}.

cert_der(CertPath) ->
    {ok, CertRaw} = file:read_file(CertPath),
    [PemEntry] = public_key:pem_decode(CertRaw),
    {_, Der, _} = PemEntry,
    Der.

signature_element(SignedSignaturePropertiesElements) ->
    {'ds:Signature', [], [
        {'ds:SignatureValue', [], ["AQID"]},
        {'ds:Object', [], [
            {'xades:QualifyingProperties', [], [
                {'xades:SignedProperties', [], [
                    {'xades:SignedSignatureProperties', [], SignedSignaturePropertiesElements}
                ]}
            ]}
        ]}
    ]}.

signature_element(SignedSignaturePropertiesElements, SignedDataObjectPropertiesElements) ->
    {'ds:Signature', [], [
        {'ds:SignatureValue', [], ["AQID"]},
        {'ds:Object', [], [
            {'xades:QualifyingProperties', [], [
                {'xades:SignedProperties', [], [
                    {'xades:SignedSignatureProperties', [], SignedSignaturePropertiesElements},
                    {'xades:SignedDataObjectProperties', [], SignedDataObjectPropertiesElements}
                ]}
            ]}
        ]}
    ]}.

parse_verified_message(SignedMessage, PublicKey) ->
    ?assertEqual(true, signerl:verify(SignedMessage, sha256, PublicKey)),
    {ok, Parsed} = signerl_xml:parse_binary(SignedMessage),
    %% Verification accepts XML without a declaration, as do the reconstruction tests.
    Rebuilt = signerl_xml:export([], Parsed),
    ?assertEqual(true, signerl:verify(Rebuilt, sha256, PublicKey)),
    Parsed.

replace_once(Message, Before, After) ->
    ?assertMatch([_], binary:matches(Message, Before)),
    Replaced = binary:replace(Message, Before, After),
    ?assertNotEqual(Message, Replaced),
    Replaced.
