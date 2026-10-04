# SignErl

SignerL is a small Erlang library for signing XML messages. It currently supports
basic signing and verification over normalized XML. The project is early-stage
and evolving, but active.

## Status

Early development. APIs may change and XML-DSig compliance is not complete yet.

## Features

- Sign an XML message using a private key.
- Verify a signature using a public key.

## Quick Start

```erlang
% Sign from a binary message and a loaded key:
{ok, SignedMessage} = case signerl:sign(RawMessage, sha256, PrivateKey) of
    {error, invalid_prolog} -> {error, invalid_prolog};
    SignedXml -> {ok, SignedXml}
end.

% Verify:
true = signerl:verify(SignedMessage, sha256, PublicKey).
```

`sign/3` returns signed XML with:
- `<ds:SignedInfo>` (deterministic internal profile, canonicalization deferred)
- `<ds:SignatureValue>` containing base64 signature bytes over `ds:SignedInfo`
- `<ds:Object>/<xades:QualifyingProperties>/<xades:SignedProperties Id="SignedProperties-1">`
- `<xades:QualifyingProperties Target="#Signature-1">`

`SigningTime` is currently strict UTC in `YYYY-MM-DDThh:mm:ssZ` format.

`verify/3` expects a signed XML message. It returns:
- `true` when signature verification succeeds
- `false` when signature bytes are present but do not match message/key
- `{error, invalid_signature}` when signature structure/properties are missing or malformed

`verify/3` validates `ds:Reference` digest values (document + signed properties) before verifying
`ds:SignatureValue`.

## Tests

Run tests with rebar3:

```bash
rebar3 test
```

Run the complete quality gate before pushing:

```bash
rebar3 tall
```

`tall` runs the test alias (formatting, EUnit, Common Test, and a 100% coverage
check), lint, Xref, and Dialyzer. Formatting runs once; `flint` remains available
for standalone formatting and lint checks. GitHub CI and the local Docker matrix
use this same gate. Generate the test certificates before the first run.
Each `rebar3 test` run resets collected coverage once, then combines fresh EUnit
and Common Test coverage for the 100% threshold. Focused runs of either framework
are useful during development but do not replace that combined gate. See the
[test responsibility map and focused commands](test/TESTS.md).

Run local Linux OTP matrix checks in Docker (OTP 26, 27, and 28):

```bash
make ci-local
```

Optional: run only one OTP version:

```bash
./scripts/ci_local_docker.sh --otp 27
```

Notes:

- This workflow is Linux-OTP parity only; it does not emulate Windows CI.
- The script builds a test image with `xmllint`, matching Linux CI's canonicalization test prerequisite.
- Docker named volumes are used for `_build` and rebar3 cache to speed up repeated runs.

## Test Certificates

Generate test-only keys and certificates:

```bash
scripts/gen_certs.sh
```

Docs for the generated artifacts:
`test/certs/README.md`

## Contributing

Issues and PRs are welcome. Keep changes small and focused, with one PR per issue
targeting `dev`. Follow the validation-first workflow in [AGENTS.md](AGENTS.md):
investigate, add behavioral validation, implement, test, review and simplify,
then run all tests, coverage, lint, and Dialyzer. Push only after `rebar3 tall`
and the required local matrix checks pass.
