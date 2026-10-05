# Test responsibilities

Use EUnit for module contracts and Common Test for public API workflows, real
file output, and the external `xmllint` comparison. Tests are discovered by
rebar3; there is no custom runner or manually maintained suite list.

## Where to put a test

| File | Cases | Responsibility |
| --- | ---: | --- |
| `signerl_c14n_test.erl` | 35 | Canonicalization, namespace ordering, escaping, Exclusive C14N, and signature-removal transforms. |
| `signerl_signed_properties_test.erl` | 66 | XAdES property extraction and malformed Erlang/XML value boundaries. |
| `signerl_signature_test.erl` | 5 | Signature construction contracts for RSA and ECDSA. |
| `signerl_verify_test.erl` | 23 | Signature extraction, reference validation, algorithm selection, and malformed signature contracts. |
| `signerl_xml_test.erl` | 20 | XML parsing, prologs, export, tree lookup, text values, and signature-element recognition. |
| `signerl_xades_xml_test.erl` | 1 | XAdES tree lookup rejects a non-signature root. |
| `signerl_cert_test.erl` | 1 | Exact issuer/serial DER against OTP ASN.1, including positive integer padding. |
| `signerl_cert_helpers_test.erl` | 6 | Application fixture paths and clear missing/malformed PEM failures. |
| `signerl_api_SUITE.erl` | 54 | Full public signing/verification, binary/file/key inputs, RSA/ECDSA certificate wiring, tampering, and independent signature fixtures. |
| `signerl_c14n_interop_SUITE.erl` | 7 | Compare production parsing/canonicalization with `xmllint --c14n11`. |
| `signerl_xml_SUITE.erl` | 1 | A real file export/read-back using CT's isolated `priv_dir`. |

Total: **157 EUnit + 62 Common Test = 219 cases**. See the
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

## Run the tests

Use the [pinned development toolchain](../README.md#development-toolchain):
OTP 28.5.0.7 and rebar3 3.25.1. OTP 26/27 remain CI compatibility targets.

Generate the test-only certificates before running the complete suite:

```sh
scripts/gen_certs.sh
rebar3 test
```

`test` formats the code, resets coverage once, runs EUnit and CT with coverage,
then checks **100% combined production-module coverage**. Both
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
`xmllint` is required for the seven interoperability comparisons; an unavailable
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
  with `parse_file/1` whitespace normalization. Changing SignedInfo's
  canonicalization leaves reference digests valid but invalidates the existing
  signature bytes; a separate fixture tests genuine Exclusive C14N signing.
- `examples/independent/` contains signatures created by `xmlsec1`, alongside
  their public key and templates. See [provenance and scope](examples/independent/README.md).
  Ordinary tests read these fixtures and do not require `xmlsec1`.
- Export unit tests run in memory. The file round-trip writes only to CT's
  temporary directory. No test overwrites a tracked XML fixture.

Production behavior is unchanged by the test cleanup. Clock behavior is #56;
bidirectional Python/Java interoperability CI remains post-1.0 work in #40.
