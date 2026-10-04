-module(signerl_cert_test).

-include_lib("eunit/include/eunit.hrl").
-include_lib("public_key/include/OTP-PUB-KEY.hrl").

sign_with_high_serial_cert_encodes_issuer_serial_test() ->
    CertDer = signerl_cert_helpers:cert_der(signerl_cert_helpers:high_serial_cert_path()),
    Cert = public_key:pkix_decode_cert(CertDer, plain),
    Tbs = Cert#'Certificate'.tbsCertificate,
    Issuer = Tbs#'TBSCertificate'.issuer,
    ?assertEqual(255, Tbs#'TBSCertificate'.serialNumber),
    Expected = {'IssuerSerial', [{directoryName, Issuer}], 255, asn1_NOVALUE},
    %% OTP's ASN.1 codec is independent of signerl's manual DER encoder.
    {ok, ExpectedDer} = encode_issuer_serial(Expected),
    ActualDer = base64:decode(signerl_cert:issuer_serial_v2_base64(CertDer)),
    ?assertEqual(ExpectedDer, ActualDer),
    %% 255 must be encoded as positive 00 FF, not the negative integer FF.
    ?assertEqual(<<2, 2, 0, 255>>, binary:part(ActualDer, byte_size(ActualDer) - 4, 4)).

encode_issuer_serial(IssuerSerial) ->
    %% OTP 28 moved IssuerSerial out of the older combined ASN.1 module.
    case code:ensure_loaded('PKIXAttributeCertificate-2009') of
        {module, 'PKIXAttributeCertificate-2009'} ->
            'PKIXAttributeCertificate-2009':encode('IssuerSerial', IssuerSerial);
        {error, nofile} ->
            'OTP-PUB-KEY':encode('IssuerSerial', IssuerSerial)
    end.
