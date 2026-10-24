# SignErl

Signerl is a small Erlang library for signing and verifying UTF-8 XML. The 1.0
profile is enveloped RSA-SHA256 with XAdES SignedProperties, SigningTime and
optional certificate properties. The project is in active development.

## Status

Early development. APIs may change and XML-DSig compliance is not complete yet.

## Features

- Sign an XML message using a private key.
- Verify a signature using a public key.

## XML dependency

Generic XML parsing, serialization, namespaces, and canonicalization are provided
by [xmlan](https://github.com/bormilan/xmlan), pinned to validated commit
`1fe39f6d414217584f514e70e43b8e7b4171f1ef` in
[rebar.config](rebar.config) and [rebar.lock](rebar.lock). Builds fetch that exact
Git revision; no sibling checkout or path override is needed. Add `signerl` to
your application's runtime dependencies. `application:ensure_all_started(signerl)`
starts xmlan and its OTP xmerl dependency transitively.

Signerl owns signing/verification, XMLDSig/XAdES rules, signature transforms,
references, certificate properties, signing time and cryptography. Generic XML
APIs and types are provided by xmlan directly; the former `signerl_xml` and
`signerl_c14n` modules and `signerl_xml.hrl` compatibility header are removed.
Use `xmlan`/`xmlan_c14n` for generic XML operations and `xmlan`'s public types.

## Quick Start

With loaded RSA private/public keys:

```erlang
Input = <<"<?xml version='1.0'?><invoice><amount>42.00</amount></invoice>">>,
Signed = signerl:sign(Input, sha256, PrivateKey),
true = signerl:verify(Signed, sha256, PublicKey).
```

`sign/3` returns XML with SignedInfo, SignatureValue and XAdES SignedProperties.
The signature covers canonicalized SignedInfo. `verify/3` checks reference digests before the
cryptographic signature, using the supplied key. It normally returns `true`,
`false` for a digest/signature mismatch, or `{error, Reason}` for a rejected
input/structure. Error reasons are specific; there is no single
`invalid_signature` result for every malformed signature.

Use `sign/4` to include a DER certificate. Use `sign/5` for a controlled UTC time;
`undefined` omits the certificate in either arity:

```erlang
Time = <<"2024-02-29T03:04:05Z">>,
SignedWithTime = signerl:sign(Input, sha256, PrivateKey, undefined, Time),
true = signerl:verify(SignedWithTime, sha256, PublicKey).
```

`sign/3` and `sign/4` use the current UTC second. Time must be a real date in
`YYYY-MM-DDThh:mm:ssZ`, with years 0001–9999; fractions, offsets and leap seconds
are rejected with `{error, invalid_signing_time}`. The same supported RSA input,
key, certificate and controlled time produce identical bytes.

## Public API and supported profile

See the [public API contract](docs/api_contract.md) for inputs, file/key
conveniences, normal errors and native exceptions. Only `sha256` is supported;
other hash atoms return `{error, unsupported_hash}` for otherwise valid inputs.
The legacy ECDSA path remains callable but is outside the supported 1.0 profile
until [#53](https://github.com/bormilan/signerl/issues/53) fixes its XMLDSig format.

XML arguments are UTF-8 binaries or filename strings. Signing requires an XML
declaration at the start; verification accepts a declaration or its absence.
Malformed XML is rejected through xmlan. File read failures return
`{error, {file_error, Reason}}`. Malformed supplied key/certificate material can
raise native OTP errors; the API does not wrap every invalid argument.

New signatures declare explicit C14N 1.1 reference transforms. Verification
also accepts the complete legacy reference pair, with the same strict reference,
ID/target, algorithm and signature-placement checks. Signing already-signed XML
raises `error:already_signed`.

XAdES signing-time and certificate properties stay in scope. The
[selected profile and implementation sequence](docs/signing_profile.md) separates
implemented reference rules from unfinished certificate and property checks.
Successful signature verification is not certificate-chain trust, validity or
revocation validation, and internal round trips do not establish full
XMLDSig/XAdES interoperability. The tracked `priv/key.pem` is public test data.

Generic XML parsing, serialization, namespaces and canonicalization are owned by
[xmlan](https://github.com/bormilan/xmlan). Signerl tests its own signature
behavior and public error propagation; it does not duplicate xmlan's tests.

## Development toolchain

The primary development runtime is **Erlang/OTP 28.5.0.7** with
**rebar3 3.25.1**, pinned in [.tool-versions](.tool-versions). GitHub Actions
reads these pins. OTP 26 and 27 remain compatibility targets on Ubuntu and
Windows; their CI jobs track the latest available patch in each major release.

With [asdf](https://asdf-vm.com/), register any missing plugins once, then install
the repository's versions:

```bash
asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git
asdf plugin add rebar https://github.com/Stratus3D/asdf-rebar.git
asdf install
```

The Erlang plugin builds OTP from source; follow its
[platform prerequisites](https://github.com/asdf-vm/asdf-erlang#before-asdf-install).
Alternatively, install the pinned OTP and rebar3 releases directly. Native
testing also requires OpenSSL for test certificates.

[rebar3 3.25.1](https://github.com/erlang/rebar3/releases/tag/3.25.1) supports the
retained OTP 26–28 matrix and includes Windows fixes for OTP 28. The
[OTP 28.5.0.7 release notes](https://github.com/erlang/otp/releases/tag/OTP-28.5.0.7)
record the selected patch's fixes and compatibility notes.

Formatting is pinned to **erlfmt 1.8.0**; lint is pinned to
**rebar3_lint 5.0.4 / Elvis 5.0.4**. This release supports the
retained OTP 26 target; [6.0.0 requires OTP 27 or newer](https://github.com/project-fifo/rebar3_lint/blob/6.0.0/rebar.config).
Tool updates are deliberate: change the exact pins, review compatibility, and
pass the full supported CI matrix. See the
[tooling and cache instructions](test/TESTS.md#tooling-versions-and-clean-builds)
for cached plugin upgrades and isolated clean builds.

## Tests

Run tests with rebar3:

```bash
scripts/gen_certs.sh
rebar3 test
```

Run the complete quality gate before pushing:

```bash
rebar3 tall
```

`tall` runs the test alias (format checking, EUnit, Common Test, and a 100%
coverage check), lint, Xref, and Dialyzer. Formatting is checked once without
rewriting files; `flint` also checks formatting and lint without rewriting files.
Run it natively before pushing.
GitHub Actions runs the same gate on OTP 26/27/28 across Ubuntu and Windows;
all six jobs must pass on the latest PR commit before merging. CI runs for pull
requests and pushes to `dev` and `main`.
Generate the test certificates before the first run.
Each `rebar3 test` run resets collected coverage once, then combines fresh EUnit
and Common Test coverage for the 100% threshold. Focused runs of either framework
are useful during development but do not replace that combined gate. See the
[test responsibility map and focused commands](test/TESTS.md).

Apply formatting explicitly, then review the diff before rerunning the checks:

```bash
rebar3 fmt
```

For a formatting-only check that leaves source files unchanged:

```bash
rebar3 fmt --check
```

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
then run all tests, coverage, lint, and Dialyzer. Push only after native
`rebar3 tall` passes, and merge only after all six GitHub Actions jobs pass
on the latest PR commit.

## XML library extraction

The migration is complete at the source level: generic XML code, tests and
fixtures are owned by xmlan. Signerl contains signature logic and tests its own
signing/verification behavior. See the [migration acceptance report](docs/xmlan_migration_acceptance.md)
for the dependency revision, removed compatibility API and validation results.
