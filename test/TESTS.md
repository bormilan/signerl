# Test responsibilities

Use EUnit for Signerl protocol/module contracts and Common Test for actual
signing/verification, file workflows, compatibility APIs, and runtime consumers.
Generic XML algorithms and their pure tests are owned by
[xmlan at the pinned revision](https://github.com/bormilan/xmlan/tree/1fe39f6d414217584f514e70e43b8e7b4171f1ef).
Tests here execute the real Git dependency, with no path override or local copy.

## Where to put a test

| File | Cases | Responsibility |
| --- | ---: | --- |
| `signerl_c14n_test.erl` | 4 | Protocol-specific enveloped-signature removal, inherited identity, and lookalike preservation. |
| `signerl_signed_properties_test.erl` | 72 | XAdES property extraction and malformed Erlang/XML value boundaries. |
| `signerl_utils_test.erl` | 25 | UTC dates, leap-year boundaries, and fixed datetime formatting. |
| `signerl_signature_test.erl` | 5 | RSA/ECDSA signature construction through xmlan. |
| `signerl_verify_test.erl` | 30 | Signature extraction, references, algorithm routing, and malformed signature contracts. |
| `signerl_xml_test.erl` | 6 | Namespace-aware signature identity, aliases/defaults/rebindings, and non-signature values. |
| `signerl_xades_xml_test.erl` | 1 | XAdES tree lookup rejects a non-signature root. |
| `signerl_cert_test.erl` | 1 | Exact issuer/serial DER against OTP ASN.1. |
| `signerl_cert_helpers_test.erl` | 6 | Application fixture paths and missing/malformed PEM failures. |
| `signerl_api_SUITE.erl` | 71 | Public binary/file/key workflows, RSA/ECDSA certificates, fixed time, encoding/content/DTD/namespace boundaries, tampering, and independent signatures. |
| `signerl_xmlan_contract_SUITE.erl` | 4 | Frozen pre-extraction XML/RSA contracts, invalid-mode error, real compatibility file output, and fresh-VM transitive startup/consumer. |
| `signerl_xml_SUITE.erl` | 1 | Zero persistent atom growth through the pinned parser/exporter/both canonicalizers and actual signing/verification. |
| `xmlan_contract_consumer.erl` | Consumer support | All legacy generic exports, signature operations, five transparent XML aliases, canonical mode alias, and forwarded include path. |

Total: **150 EUnit + 76 Common Test = 226 cases**. There are no skipped required
checks. The original pure parser/export/namespace and canonicalization cases,
file/entity canaries, deep-tree tests, and all xmllint comparisons run in xmlan.
Its validated commit has 259 passing cases, 100% coverage, and all six OTP/OS
jobs green. No XML contract is discarded: only test ownership changes.

Signerl retains all 71 public API cases. They sign real data before tampering,
verify frozen/independently supplied signatures, cover RSA/ECDSA and certificates,
carry inherited namespace context into signed fragments, exercise file/key errors,
and reject unsupported XML/prologs/encodings/entities through the dependency.
The controlled-time cases preserve deterministic RSA bytes and Gregorian UTC
validation. No profile, algorithm, certificate, or failure-policy redesign is
part of this extraction.

The compatibility consumer reads original parsed/exported/canonical/signed bytes
from committed files, verifies the frozen signature, and signs twice with a fresh
in-memory key and fixed time. It verifies both outputs and compares serialized
bytes against the baseline except for the necessarily different SignatureValue.
A changed golden must fail its real assertion. Private generated keys are never
published or persisted by the consumer. The five XML type aliases and mode alias
are constructed/pattern-matched by an external Dialyzer consumer; the legacy XML
header must resolve dependency-owned macros.

The fresh-VM application contract requires Signerl to depend on xmlan directly,
xmerl to start transitively, and the frozen consumer to work using only installed
application paths. The separate warmed atom probe exercises actual dependency
parse/export/C14N and sign/verify with two disjoint batches of 25 fresh name sets;
each must add zero permanent atoms, including malformed input.

## Run the tests

Use OTP/rebar3 pinned in `.tool-versions`. Generate ignored test certificates:

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

`test` checks formatting, resets coverage once, combines fresh EUnit and CT data,
and requires **100% Signerl production coverage**. xmlan owns its own complete
coverage gate; dependency internals are not reimplemented or duplicated in this
suite. `tall` adds lint, Xref, and Dialyzer. Run it natively before commit/push;
all six latest-commit OTP 26/27/28 Ubuntu/Windows jobs must pass before merge.
OpenSSL is required for generated test certificates; xmllint is required by
xmlan's interop suite and is not needed by Signerl's ordinary suite.

Focused examples:

```sh
rebar3 eunit --module signerl_verify_test
rebar3 ct --suite test/signerl_api_SUITE
rebar3 ct --suite test/signerl_xmlan_contract_SUITE
```

Focused runs do not replace the complete combined test/coverage gate. The
[migration contract](../docs/xmlan_migration_contract.md) maps old tests to their
new owners; historical implementation logs describe the pre-extraction layout.

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

The existing exceptions remain limited to the transparent simplified XML tree
type and OTP ASN.1 record/field spelling in the certificate modules. Their reasons
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
- Compatibility file output writes only to CT's temporary directory. Pure export
  unit tests live in xmlan. No test overwrites a tracked XML fixture.

Production behavior is unchanged by the test cleanup. Clock behavior is #56;
bidirectional Python/Java interoperability CI remains post-1.0 work in #40.

## XML extraction baseline

The [xmlan migration contract](../docs/xmlan_migration_contract.md) maps every
XML export/helper, caller, and test family to its future repository owner.
`signerl_xmlan_contract_SUITE` runs the standalone `xmlan_contract_consumer`
against the [frozen corpus](examples/xmlan_migration/README.md), captured before
extraction. Expected parsed values, exported/canonical bytes, and fixed-time RSA
output are read from committed files. Only the verification public key is
committed; fresh signing keys stay in memory.
Tests do not regenerate their oracle; keep the independent signatures and
xmlan's xmllint checks as complementary evidence. External compile/Dialyzer and
changed-golden failure probes are documented in the migration contract/log.
