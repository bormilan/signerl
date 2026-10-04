-module(signerl_cert_helpers).

-export([
    path/1,
    cert_der/1,
    rsa_public_key_from_cert/1,
    ecdsa_public_key_from_cert/1,
    rsa_public_key/1,
    ecdsa_public_key/1,
    leaf_key_path/0,
    leaf_cert_path/0,
    chain_full_cert_path/0,
    signer_rsa_key_path/0,
    signer_rsa_cert_path/0,
    signer_ecdsa_key_path/0,
    signer_ecdsa_cert_path/0,
    high_serial_cert_path/0,
    load_private_key/1,
    leaf_key/0,
    signer_rsa_key/0,
    signer_ecdsa_key/0
]).

-include_lib("public_key/include/OTP-PUB-KEY.hrl").

path(RelPath) ->
    filename:join([code:priv_dir(signerl), "certs", RelPath]).

leaf_key_path() -> path("leaf.key.pem").
leaf_cert_path() -> path("leaf.cert.pem").
chain_full_cert_path() -> path("chain_full.cert.pem").
signer_rsa_key_path() -> path("signer_rsa.key.pem").
signer_rsa_cert_path() -> path("signer_rsa.cert.pem").
signer_ecdsa_key_path() -> path("signer_ecdsa.key.pem").
signer_ecdsa_cert_path() -> path("signer_ecdsa.cert.pem").
high_serial_cert_path() -> path("high_serial.cert.pem").

load_private_key(Path) ->
    PemEntry = single_pem_entry(Path),
    try public_key:pem_entry_decode(PemEntry) of
        Decoded -> Decoded
    catch
        error:_ -> error({invalid_pem_fixture, Path})
    end.

single_pem_entry(Path) ->
    PemRaw =
        case file:read_file(Path) of
            {ok, Raw} -> Raw;
            {error, Reason} -> error({fixture_read_failed, Path, Reason})
        end,
    try public_key:pem_decode(PemRaw) of
        [Entry] -> Entry;
        _ -> error({invalid_pem_fixture, Path})
    catch
        error:_ -> error({invalid_pem_fixture, Path})
    end.

leaf_key() -> load_private_key(leaf_key_path()).
signer_rsa_key() -> load_private_key(signer_rsa_key_path()).
signer_ecdsa_key() -> load_private_key(signer_ecdsa_key_path()).

rsa_public_key_from_cert(CertPath) ->
    rsa_public_key(cert_der(CertPath)).

rsa_public_key(Der) ->
    Cert = public_key:pkix_decode_cert(Der, otp),
    Tbs = Cert#'OTPCertificate'.tbsCertificate,
    Spki = Tbs#'OTPTBSCertificate'.subjectPublicKeyInfo,
    KeyBits = Spki#'OTPSubjectPublicKeyInfo'.subjectPublicKey,
    case KeyBits of
        #'RSAPublicKey'{} -> KeyBits;
        _ when is_binary(KeyBits) -> public_key:der_decode('RSAPublicKey', KeyBits)
    end.

ecdsa_public_key_from_cert(CertPath) ->
    ecdsa_public_key(cert_der(CertPath)).

ecdsa_public_key(Der) ->
    Cert = public_key:pkix_decode_cert(Der, otp),
    Tbs = Cert#'OTPCertificate'.tbsCertificate,
    Spki = Tbs#'OTPTBSCertificate'.subjectPublicKeyInfo,
    Alg = Spki#'OTPSubjectPublicKeyInfo'.algorithm,
    Params = Alg#'PublicKeyAlgorithm'.parameters,
    PointRec = Spki#'OTPSubjectPublicKeyInfo'.subjectPublicKey,
    {PointRec, Params}.

cert_der(CertPath) ->
    case single_pem_entry(CertPath) of
        {'Certificate', Der, not_encrypted} -> Der;
        _ -> error({invalid_certificate_fixture, CertPath})
    end.
