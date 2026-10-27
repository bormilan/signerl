-module(signerl_cert).

-include_lib("public_key/include/OTP-PUB-KEY.hrl").

-include("signerl_dsig.hrl").

-export([
    cert_digest_base64/2,
    issuer_serial_v2_base64/1,
    certificate_info/1,
    verify_signature/5
]).

-spec cert_digest_base64(HashAlgorithm, CertDer) -> binary() when
    HashAlgorithm :: atom(),
    CertDer :: binary().
cert_digest_base64(HashAlgorithm, CertDer) ->
    base64:encode(crypto:hash(HashAlgorithm, CertDer)).

-spec issuer_serial_v2_base64(CertDer) -> binary() when
    CertDer :: binary().
issuer_serial_v2_base64(CertDer) ->
    Cert = public_key:pkix_decode_cert(CertDer, plain),
    base64:encode(issuer_serial_v2(Cert)).

-spec certificate_info(binary()) -> map().
certificate_info(CertDer) ->
    Plain = public_key:pkix_decode_cert(CertDer, plain),
    % Require one DER certificate, including no ignored trailing bytes.
    CertDer = public_key:der_encode('Certificate', Plain),
    Cert = public_key:pkix_decode_cert(CertDer, otp),
    Tbs = Cert#'OTPCertificate'.tbsCertificate,
    {Method, Key} = certificate_key(Tbs#'OTPTBSCertificate'.subjectPublicKeyInfo),
    #{
        x509_certificate => CertDer,
        public_key => Key,
        signature_method => Method,
        issuer_serial_v2 => issuer_serial_v2(Plain)
    }.

certificate_key(#'OTPSubjectPublicKeyInfo'{
    subjectPublicKey = #'RSAPublicKey'{} = Key,
    algorithm = #'PublicKeyAlgorithm'{algorithm = ?DSIG_RSA_KEY_OID}
}) ->
    {?DSIG_SIG_RSA_SHA256_URI, Key};
certificate_key(#'OTPSubjectPublicKeyInfo'{
    subjectPublicKey = #'ECPoint'{} = Point,
    algorithm = #'PublicKeyAlgorithm'{algorithm = ?DSIG_EC_KEY_OID, parameters = Params}
}) ->
    {?DSIG_SIG_ECDSA_SHA256_URI, {Point, Params}}.

-spec verify_signature(map(), string(), binary(), atom(), binary()) -> boolean().
verify_signature(#{signature_method := Method, public_key := Key}, Method, Bytes, Hash, Sig) ->
    public_key:verify(Bytes, Hash, Sig, Key);
verify_signature(_, _, _, _, _) ->
    false.

issuer_serial_v2(Cert) ->
    Tbs = Cert#'Certificate'.tbsCertificate,
    Issuer = Tbs#'TBSCertificate'.issuer,
    Serial = Tbs#'TBSCertificate'.serialNumber,
    GeneralNamesDer = public_key:der_encode('GeneralNames', [{directoryName, Issuer}]),
    SerialDer = der_encode_integer(Serial),
    der_encode_sequence(<<GeneralNamesDer/binary, SerialDer/binary>>).

%% ASN.1 DER encoding helpers for IssuerSerial (RFC 5035).
%% OTP does not include this type, so we encode manually.

der_encode_integer(N) when N >= 0 ->
    Raw = binary:encode_unsigned(N),
    Padded =
        case Raw of
            <<1:1, _/bitstring>> -> <<0, Raw/binary>>;
            _ -> Raw
        end,
    <<2, (der_encode_length(byte_size(Padded)))/binary, Padded/binary>>.

der_encode_sequence(Contents) ->
    <<16#30, (der_encode_length(byte_size(Contents)))/binary, Contents/binary>>.

der_encode_length(Len) when Len < 128 ->
    <<Len>>;
der_encode_length(Len) ->
    Bytes = binary:encode_unsigned(Len),
    <<(128 + byte_size(Bytes)), Bytes/binary>>.
