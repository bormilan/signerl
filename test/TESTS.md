# Test responsibilities

Use EUnit for module contracts and Common Test for public API workflows, real
file output, and the external `xmllint` comparison. Tests are discovered by
rebar3; there is no custom runner or manually maintained suite list.

## Where to put a test

| File | Cases | Responsibility |
| --- | ---: | --- |
| `signerl_c14n_test.erl` | 39 | Canonicalization, namespace ordering, escaping, Exclusive C14N, and signature-removal transforms. |
| `signerl_signed_properties_test.erl` | 66 | XAdES property extraction and malformed Erlang/XML value boundaries. |
| `signerl_signature_test.erl` | 5 | Signature construction contracts for RSA and ECDSA. |
| `signerl_verify_test.erl` | 23 | Signature extraction, reference validation, algorithm selection, and malformed signature contracts. |
| `signerl_xml_test.erl` | 65 | XML parsing, prologs, export, tree lookup, text values, and signature-element recognition. |
| `signerl_xades_xml_test.erl` | 1 | XAdES tree lookup rejects a non-signature root. |
| `signerl_cert_test.erl` | 1 | Exact issuer/serial DER against OTP ASN.1, including positive integer padding. |
| `signerl_cert_helpers_test.erl` | 6 | Application fixture paths and clear missing/malformed PEM failures. |
| `signerl_api_SUITE.erl` | 62 | Full public signing/verification, binary/file/key inputs, RSA/ECDSA certificate wiring, tampering, and independent signature fixtures. |
| `signerl_c14n_interop_SUITE.erl` | 9 | Compare production parsing/canonicalization with `xmllint --c14n11`; Unicode and content preservation also cover `--exc-c14n`. |
| `signerl_xml_SUITE.erl` | 6 | Real file export/read-back, Unicode, unsupported encodings, and missing files using CT's isolated `priv_dir`. |

Total: **206 EUnit + 77 Common Test = 283 cases**. See the
[migration log and case map](../docs/implementations/test_organization_2026-10-04.md)
for the earlier suite locations and the
[fixture cleanup log](../docs/implementations/test_fixtures_2026-10-04.md)
for the named-case and fixture changes.

Add a pure contract case as a descriptive `_test` function. When several inputs
exercise the same operation and assertion, use a small `_test_` generator with
one `{Name, ?_assertEqual(...)}` descriptor per input. Keep literal inputs visible
and names specific; do not hide different contracts in a generic test runner.
Builder and verifier fixtures use ordinary EUnit setup descriptors with an
explicit name for every case. Public API/file workflows belong in the relevant
CT group; share immutable input bytes, keys, and certificates in `init_per_group`.

The UTF-8 regressions cover character-list and binary canonicalization, multilingual
text/attributes, Unicode XML names, direct export, public `sign/3`/`sign/4` with
binary/file inputs, verification with and without a declaration/BOM, and a
Unicode mutation after successful verification. Encoding rejection covers
unsupported declarations, UTF-16 bytes, and malformed UTF-8 sequences.

Content-preservation regressions cover whitespace-only and mixed text, CDATA,
`xml:space`, literal line-ending normalization versus character references, and
attribute/text export round trips. Export tests also verify nested/sibling ordering
and a 10,000-level tree. Public signing tests verify the untouched binary signature
before mutating separating whitespace, mixed text, attribute controls, and a text
CR. A single positive file-path verification covers that entry point; mutations
are not repeated for the shared parser. Processing instructions are rejected
before, inside, and after the root; PI-looking CDATA/comment text is not mistaken for an instruction.
The interoperability fixture compares original and exported bytes through
`xmllint` in both supported canonicalization modes. On Windows, the helper undoes
only C stdio's LF-to-CRLF output translation before comparing bytes; fixture and
production output bytes are untouched, and XML CR values remain `&#xD;`.

Complete-document regressions append legal whitespace/comments or invalid suffixes
to a successfully verified signature, then exercise signing with the same suffixes.
Parser cases cover self-closing and nonempty roots, malformed trailing markup,
CDATA/character references outside the root, non-XML whitespace, and misplaced
BOMs. One file-path case checks an accepted comment suffix and second-root
rejection through parsing, signing, and verification; the full binary suffix
matrix is not duplicated for files.

## Run the tests

Use the [pinned development toolchain](../README.md#development-toolchain):
OTP 28.5.0.7 and rebar3 3.25.1. OTP 26/27 remain CI compatibility targets.

Generate the test-only certificates before running the complete suite:

```sh
scripts/gen_certs.sh
rebar3 test
```

`test` checks formatting without rewriting source, resets coverage once, runs
EUnit and CT with coverage, then checks **100% combined production-module coverage**. Both
`eunit.coverdata` and `ct.coverdata` contribute. Neither framework alone is
expected to cover all production modules after the split.

Run a focused module or suite while working:

```sh
rebar3 eunit --module signerl_verify_test
rebar3 ct --suite test/signerl_api_SUITE
rebar3 ct --suite test/signerl_c14n_interop_SUITE
```

Run all unit or integration cases with `rebar3 eunit` or `rebar3 ct`. These
standalone commands do not replace the fresh combined coverage gate. Use
`rebar3 as test cover` to inspect the most recently collected results.

Before pushing, run native `rebar3 flint`, `rebar3 dialyzer`, and `rebar3 tall`
as required by [AGENTS.md](../AGENTS.md). `tall` includes `test`, lint, Xref, and
Dialyzer. GitHub Actions runs the same gate on OTP 26/27/28 across Ubuntu and
Windows. All six jobs must pass on the latest PR commit before merging.
`xmllint` is required for the nine interoperability comparisons; an unavailable
tool skips that group, which is not a complete validation run. Install it locally;
Linux CI installs it automatically.

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
- Export unit tests run in memory. The file round-trip writes only to CT's
  temporary directory. No test overwrites a tracked XML fixture.

Production behavior is unchanged by the test cleanup. Clock behavior is #56;
bidirectional Python/Java interoperability CI remains post-1.0 work in #40.
