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
| `signerl_xml_test.erl` | 15 | XML parsing, prologs, export, tree lookup, text values, and signature-element recognition. |
| `signerl_xades_xml_test.erl` | 1 | XAdES tree lookup rejects a non-signature root. |
| `signerl_cert_test.erl` | 1 | High-serial certificate issuer/serial encoding. |
| `signerl_api_SUITE.erl` | 54 | Full public signing/verification, binary/file/key inputs, RSA/ECDSA certificate wiring, tampering, and independent signature fixtures. |
| `signerl_c14n_interop_SUITE.erl` | 7 | Compare production parsing/canonicalization with `xmllint --c14n11`. |
| `signerl_xml_SUITE.erl` | 1 | A real file export/read-back using CT's isolated `priv_dir`. |

Total: **146 EUnit + 62 Common Test = 208 cases**. Four duplicate XML checks
were consolidated into the existing EUnit assertions; no distinct behavior was
removed. See the [migration log and case map](../docs/implementations/test_organization_2026-10-04.md)
for the old locations.

Pure EUnit cases keep their descriptive names with a `_test` suffix. Builder
and verifier fixtures use ordinary EUnit setup descriptors with an explicit
name for every case, so failures still identify the original scenario.

## Run the tests

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

Before pushing, run `rebar3 flint`, `rebar3 dialyzer`, `rebar3 tall`, and
`make ci-local` as required by [AGENTS.md](../AGENTS.md). `tall` includes `test`,
lint, Xref, and Dialyzer. GitHub CI and the Docker OTP 26/27/28 matrix run it.
`xmllint` is required for the seven interoperability comparisons; an unavailable
tool skips that group, which is not a complete validation run. Linux CI and the
local Docker images install it.

## Existing build caches after the suite moves

When updating a checkout or Docker build volume from the old suite layout,
reset its generated test profile once. Rebar's `clean` command removes compiled
BEAM files but can leave copied sources for deleted suites. Common Test can then
print suite-loading failures even while reporting that all current cases passed.

For a local checkout, run `rm -rf _build/test`, then `rebar3 test`. This resets
only generated test artifacts; it retains the default-profile dependency builds
and Dialyzer PLT. Do not edit copied test sources to repair a cached build.

For existing local Docker volumes/images, reset the same generated profile:

```sh
for otp in 26 27 28; do
    docker run --rm -v "signerl_build_cache_otp${otp}:/build" \
        "signerl-ci:otp${otp}" sh -c 'rm -rf /build/test'
done
make ci-local
```

Ordinary repeated runs reuse the rebuilt caches. Check for suite-loading errors
and skipped cases as well as the final case count and exit status.

## Fixtures and controls

- `signerl_cert_helpers.erl` locates the generated keys/certificates.
- `test_helpers.erl` contains shared certificate/tree fixtures and the baseline
  and replacement assertions introduced in #57.
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

Fixture construction and assertion semantics are preserved in this migration.
Further fixture/assertion cleanup is #68; clock behavior is #56 and bidirectional
Python/Java interoperability CI remains post-1.0 work in #40.
