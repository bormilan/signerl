-module(signerl_cert).

-include_lib("public_key/include/OTP-PUB-KEY.hrl").

-export([cert_digest_base64/2, issuer_serial_v2_base64/1]).

-spec cert_digest_base64(HashAlgorithm, CertDer) -> binary() when
    HashAlgorithm :: atom(),
    CertDer :: binary().
cert_digest_base64(HashAlgorithm, CertDer) ->
    base64:encode(crypto:hash(HashAlgorithm, CertDer)).

-spec issuer_serial_v2_base64(CertDer) -> binary() when
    CertDer :: binary().
issuer_serial_v2_base64(CertDer) ->
    Cert = public_key:pkix_decode_cert(CertDer, plain),
    TBS = Cert#'Certificate'.tbsCertificate,
    Issuer = TBS#'TBSCertificate'.issuer,
    Serial = TBS#'TBSCertificate'.serialNumber,
    GeneralNamesDer = public_key:der_encode('GeneralNames', [{directoryName, Issuer}]),
    SerialDer = der_encode_integer(Serial),
    IssuerSerialDer = der_encode_sequence(<<GeneralNamesDer/binary, SerialDer/binary>>),
    base64:encode(IssuerSerialDer).

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
