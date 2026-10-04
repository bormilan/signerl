-module(signerl_cert_test).

-include_lib("eunit/include/eunit.hrl").

sign_with_high_serial_cert_encodes_issuer_serial_test() ->
    HighSerialCertDer = test_helpers:cert_der(signerl_cert_helpers:high_serial_cert_path()),
    Result = signerl_cert:issuer_serial_v2_base64(HighSerialCertDer),
    ?assert(is_binary(Result)),
    Decoded = base64:decode(Result),
    %% Verify the DER is a SEQUENCE (tag 0x30)
    ?assertMatch(<<16#30, _/binary>>, Decoded).
