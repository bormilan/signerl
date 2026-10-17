# Test responsibilities

Signerl tests its own signing, verification, XMLDSig/XAdES rules, certificate
handling and public API errors. Generic XML parsing, serialization, namespace
validation and canonicalization are owned and tested by
[xmlan](https://github.com/bormilan/xmlan).

Tests may use xmlan to build or inspect signed documents. They do not assert
standalone parser/exporter/canonicalizer behavior, dependency internals, generic
type aliases or installation contracts.

## Where to put a test

| File | Cases | Responsibility |
| --- | ---: | --- |
| `signerl_dsig_utils_test.erl` | 10 | Signature identity, inherited namespace context, enveloped-signature removal and lookalike preservation. |
| `signerl_signed_properties_test.erl` | 72 | XAdES property extraction and malformed signed-property values. |
| `signerl_utils_test.erl` | 25 | UTC dates, leap-year boundaries and fixed datetime formatting. |
| `signerl_signature_test.erl` | 5 | RSA/ECDSA signature construction. |
| `signerl_verify_test.erl` | 30 | Signature extraction, references, algorithm routing and malformed signatures. |
| `signerl_xades_xml_test.erl` | 1 | XAdES lookup rejects a non-signature root. |
| `signerl_cert_test.erl` | 1 | Exact issuer/serial DER against OTP ASN.1. |
| `signerl_cert_helpers_test.erl` | 6 | Fixture paths and missing/malformed PEM failures. |
| `signerl_api_SUITE.erl` | 70 | Public binary/file/key/certificate workflows, RSA/ECDSA, fixed time, content preservation, public input errors, tampering and independent signatures. |

Total: **150 EUnit + 70 Common Test = 220 cases**. Required coverage is **100%**
of Signerl production modules. The independent xmlsec1 signatures stay in
`examples/independent/`; `examples/payloads/` contains inputs used for actual
sign/verify/tamper cases.

## Run the tests

Use the OTP/rebar3 versions in `.tool-versions` and generate test certificates:

```sh
scripts/gen_certs.sh
rebar3 eunit
rebar3 ct
rebar3 test
rebar3 as test cover
rebar3 flint
rebar3 dialyzer
rebar3 tall
```

`test` checks formatting, resets coverage, combines EUnit and Common Test data,
and requires 100% Signerl coverage. `tall` adds lint, Xref and Dialyzer. Run it
natively before commit/push. All six latest-head OTP 26/27/28 Ubuntu/Windows jobs
must pass before merge. The suite needs OpenSSL for certificates and does not
fetch or compile a historical XML implementation.

Focused examples:

```sh
rebar3 eunit --module signerl_dsig_utils_test
rebar3 eunit --module signerl_verify_test
rebar3 ct --suite test/signerl_api_SUITE
```

## Existing build caches after the suite moves

When updating a checkout from the old suite layout,
reset its generated test profile once. Rebar's `clean` command removes compiled
BEAM files but can leave copied sources for deleted suites. Common Test can then
print suite-loading failures even while reporting that all current cases passed.

For a local checkout, run `rm -rf _build/test`, then `rebar3 test`. This resets
only generated test artifacts; it retains the default-profile dependency builds
and Dialyzer PLT. Do not edit copied test sources to repair a cached build.

Ordinary repeated runs reuse the rebuilt caches. Check for suite-loading errors
and skipped cases as well as the final case count and exit status.

## Tooling versions and clean builds

Use the runtime/rebar3 pins in `.tool-versions` and the project plugin pins in
`rebar.config`: rebar3 3.25.1, erlfmt 1.8.0, rebar3_lint 5.0.4 / Elvis 5.0.4.
Change these deliberately after reviewing upstream compatibility; validate the
new versions from clean and warm builds and across all six GitHub jobs.

`rebar3 fmt` is the developer command that writes formatting changes.
`rebar3 fmt --check`, `test`, `flint`, and `tall` fail on formatting drift without
rewriting source files. Run `fmt`, review the resulting diff, then rerun the gate.
`.gitattributes` keeps all default formatter inputs (Erlang sources, headers,
application files, and `rebar.config`) at LF line endings even when Git uses
`core.autocrlf=true`; XML fixtures keep their existing checkout behavior.

Start a cache investigation with `rebar3 version` and `rebar3 plugins list`.
The plugin list should show `erlfmt (1.8.0)` and `rebar3_lint (5.0.4)`. A changed
pin can leave an existing plugin build stale. Upgrade only the affected plugin:

```sh
rebar3 plugins upgrade erlfmt
rebar3 plugins upgrade rebar3_lint
rebar3 plugins list
rebar3 flint
```

The linter migration example below explains the 4.x configuration transition.
Do not repair caches by editing generated plugin sources or BEAM files.

To separate project failures from stale builds or user-global plugins, run this
from the repository root in a POSIX shell with the pinned tools on `PATH`:

```sh
tooling_diag_dir="$(mktemp -d)"
(
    set -e
    mkdir -p "$tooling_diag_dir/global-config"
    scripts/gen_certs.sh
    export REBAR_GLOBAL_CONFIG_DIR="$tooling_diag_dir/global-config"
    export REBAR_BASE_DIR="$tooling_diag_dir/build"
    export REBAR_CACHE_DIR="$tooling_diag_dir/cache"
    rebar3 tall
    rebar3 plugins list
)
```

This uses a new build directory, package cache, and empty global configuration;
it leaves the normal `_build` and user-global settings intact. Reuse the same
directory for a warm comparison or create a new one for another clean run.
The subshell stops on a failed command, preserving its exit status. A failure
that occurs only with the normal global configuration points to user tooling, not a new project dependency.

CI cache keys include `rebar.lock`, `rebar.config`, and `elvis.config`, plus the
resolved OTP/rebar3 versions and operating system. The build cache also includes
source, header, and test paths. Updating a tool pin or its configuration therefore
invalidates the relevant CI caches. GitHub runs the same non-mutating `tall` gate.

## Lint plugin upgrades

`rebar.config` pins `rebar3_lint` 5.0.4, which selects Elvis 5.0.4. Both support
OTP 26 and newer. `elvis.config` uses the 5.x top-level `config` list and `files`
globs; both source and test modules retain the `erl_files` ruleset. Configuration
validation is built into Elvis rather than a separate `elvis_config` ruleset.

When updating a checkout that already built the 4.x plugin, changing the declared
version alone can leave the old plugin in `_build`. Use Rebar's plugin upgrade
command, then verify and lint:

```sh
rebar3 plugins upgrade rebar3_lint
rebar3 plugins list
rebar3 flint
```

The plugin list must report `rebar3_lint (5.0.4)`. The upgrade command refreshes
its Elvis dependency as well. Do not edit generated plugin files by hand.
CI's build and package-cache keys include `rebar.config` and `elvis.config`, so
this migration gets fresh caches and subsequent runs reuse the matching versions.

The remaining exceptions cover OTP ASN.1 record/field spelling in certificate
modules and fixtures. Their reasons
are documented beside the rules in `elvis.config`; no new rule is disabled for
this upgrade. See the [implementation log](../docs/implementations/lint_upgrade_2026-10-05.md)
for the clean/warm checks and lint failure probes.

## Fixtures and controls

- `signerl_cert_helpers.erl` owns PEM loading, certificate decoding, and public
  key extraction. Generated fixtures come only from `code:priv_dir(signerl)/certs`;
  there is no working-directory or parent-directory search. Run `gen_certs.sh`
  before testing. Missing files and invalid PEM report the fixture path.
- Load keys/certificates once per relevant CT group. When both DER and the public
  key are needed, decode the loaded DER with `rsa_public_key/1` or
  `ecdsa_public_key/1` rather than reading the same certificate again.
- `test_helpers.erl` owns small XML builders and the baseline/replacement
  assertions introduced in #57. Its minimal signature wrappers are suitable for
  extraction tests only. Sign a real document before end-to-end tampering.
- Keep mutation helpers next to their tests. Preserve literal XML for prologs,
  namespaces, encodings, whitespace, and self-closing syntax; use small builders
  only when the relevant input is an Erlang tree.
- Signature mutation tests verify the original and unchanged parse/export
  reconstruction before the mutation. Binary replacements must match once;
  tree mutations must change their target.
- Verifier tests retain the original unsigned tree rather than reparsing it
  through a separate parsing policy. Both parser entry points now preserve
  whitespace identically. Changing SignedInfo's
  canonicalization leaves reference digests valid but invalidates the existing
  signature bytes; a separate fixture tests genuine Exclusive C14N signing.
- `examples/independent/` contains signatures created by `xmlsec1`, alongside
  their public key and templates. See [provenance and scope](examples/independent/README.md).
  Ordinary tests read these fixtures and do not require `xmlsec1`.
- File workflow tests write outputs only to CT's temporary directory. No test
  overwrites a tracked XML fixture.

Public signing/verification behavior is unchanged. Clock behavior is #56;
bidirectional Python/Java interoperability CI remains post-1.0 work in #40.
