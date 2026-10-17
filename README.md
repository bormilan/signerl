# SignErl

SignerL is a small Erlang library for signing XML messages. It currently supports
basic signing and verification over normalized XML. The project is early-stage
and evolving, but active.

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
- `<ds:SignedInfo>` (deterministic internal profile)
- `<ds:SignatureValue>` containing base64 signature bytes over `ds:SignedInfo`
- `<ds:Object>/<xades:QualifyingProperties>/<xades:SignedProperties Id="SignedProperties-1">`
- `<xades:QualifyingProperties Target="#Signature-1">`

`SigningTime` is strict UTC in `YYYY-MM-DDThh:mm:ssZ` format, with real Gregorian
calendar dates and years 0001–9999. Fractional seconds, offsets, and leap seconds
are unsupported. Signing and verification reject malformed or impossible dates
with `{error, invalid_signing_time}`.

`sign/3` and `sign/4` capture the current UTC second once per call. For a controlled
signing time, use `sign/5` with a timestamp binary and an optional DER certificate
(`undefined` omits the certificate):

```erlang
Time = <<"2024-02-29T03:04:05Z">>,
Signed = signerl:sign(RawMessage, sha256, PrivateKey, undefined, Time),
true = signerl:verify(Signed, sha256, PublicKey).
```

The same XML, RSA key, certificate, and fixed signing time produce identical bytes.
Default calls made in different seconds can differ because signing time is signed
metadata. XML normalization is deterministic; ECDSA signature generation is
randomized, so its output must be checked by verification rather than byte equality.
The lower-level signature builder also accepts the timestamp through
`build_signature_element/5`. `signerl_utils:format_utc_timestamp/1` formats an
already valid UTC `calendar:datetime()` without reading the clock.

`verify/3` expects a signed XML message. It returns:
- `true` when signature verification succeeds
- `false` when signature bytes are present but do not match message/key
- `{error, invalid_signature}` when signature structure/properties are missing or malformed

`verify/3` validates `ds:Reference` digest values (document + signed properties) before verifying
`ds:SignatureValue`.

## Supported profile work

The 1.0 scope keeps **XAdES signed properties, signing time and certificate
properties** with enveloped RSA-SHA256 signing. See the
[selected profile and implementation sequence](docs/signing_profile.md) for the
public API, required reference/algorithm checks and known work still open.
The profile document distinguishes intended behavior from current capabilities;
it does not claim complete XMLDSig/XAdES conformance.

## Signing input

Signerl accepts UTF-8 XML as a binary or file path. `sign/3`, `sign/4` and
`sign/5` require an XML declaration at the start of the input; a missing or
unsupported declaration returns `{error, invalid_prolog}`. Malformed XML returns
`{error, invalid_xml}`. File loading failures return `{error, {file_error, Reason}}`.

XML parsing, serialization, namespaces and canonicalization are handled by
[xmlan](https://github.com/bormilan/xmlan). See its documentation for the supported
XML format. Signerl's tests cover signing, verification, signed-content
preservation, signature metadata, tampering and error propagation through its
public APIs.

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
