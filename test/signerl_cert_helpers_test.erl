-module(signerl_cert_helpers_test).

-include_lib("eunit/include/eunit.hrl").

fixture_path_uses_application_priv_test_() ->
    [
        {Name,
            ?_assertEqual(
                filename:join([code:priv_dir(signerl), "certs", Name]),
                signerl_cert_helpers:path(Name)
            )}
     || Name <- ["signer_rsa.cert.pem", "missing-fixture.pem"]
    ].

missing_fixture_reports_path_test() ->
    Path = signerl_cert_helpers:path("missing-fixture.pem"),
    ?assertError({fixture_read_failed, Path, enoent}, signerl_cert_helpers:load_private_key(Path)).

malformed_pem_reports_path_test_() ->
    [
        {Name,
            ?_assertError({invalid_pem_fixture, Path}, signerl_cert_helpers:load_private_key(Path))}
     || {Name, Path} <- [
            {"not PEM", signerl_utils:file_path("test/examples/base/books.xml")},
            {"multiple PEM entries", signerl_cert_helpers:chain_full_cert_path()}
        ]
    ].

certificate_fixture_rejects_private_key_test() ->
    Path = signerl_cert_helpers:signer_rsa_key_path(),
    ?assertError({invalid_certificate_fixture, Path}, signerl_cert_helpers:cert_der(Path)).
