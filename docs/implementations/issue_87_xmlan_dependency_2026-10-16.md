# Signerl consumes xmlan — #87

Tracking: https://github.com/bormilan/signerl/issues/87

## Dependency and ownership

The prerequisite xmlan PR #3 is merged and Signerl #86 is actually closed.
`rebar.config` pins `xmlan` over HTTPS/Git to
`1fe39f6d414217584f514e70e43b8e7b4171f1ef`; rebar generated the matching
`rebar.lock` entry. This is the reviewed #86 implementation with 259 tests,
100% coverage, and all six OTP/OS jobs verified. The full implementation SHA is
reachable from merged xmlan dev and matches the validated SHA exactly. No moving
branch, sibling checkout, dependency override, or local fallback is configured.
Both native default/test dependency checkouts were checked against this SHA.

- `src/signerl.erl`, `signerl_signature`, `signerl_verify`,
  `signerl_signed_properties`, and `signerl_xades_xml` call xmlan/xmlan_c14n
  directly for generic parsing, serialization, tree lookup, namespace work,
  canonicalization, and types.
- `src/signerl_xml.erl` keeps all existing exports: 16 generic APIs are one-call
  delegates, five XML types are transparent remote aliases, and the two
  signature-identity predicates remain local protocol operations.
- `src/signerl_c14n.erl` keeps both canonicalization exports as direct delegates,
  the transparent canonical-mode alias, and immediate-child enveloped-signature
  removal. Signature removal uses generic dependency context plus local identity.
- `include/signerl_xml.hrl` is only an `include_lib` forward to
  `xmlan/include/xmlan.hrl`; no XML regexes/constants are copied locally.
- `src/signerl.app.src` replaces direct xmerl with xmlan. Fresh-VM application
  startup proves xmlan and xmerl start transitively. There are no direct xmerl
  implementation calls/imports in Signerl.

Local SAX parsing/callbacks, complete-document/encoding checks, generic escaping,
serialization, QName/namespace algorithms, recursive tree projection, and both
canonicalization engines are removed. Signature identity/removal, XMLDSig/XAdES
builders/validators, references/digests, algorithm URI routing, signing time,
certificate behavior, and cryptography stay in Signerl.

Public signatures, return values, malformed-input boundaries, prefixes, ordering,
UTF-8, and canonical bytes are preserved. `to_file/2`'s delegate specification
includes its already-existing file-error return, aligned with xmlan. APIs/types
are retained rather than removed. No algorithm/profile/failure-policy redesign
is included.

## Test ownership and documentation

Pure XML ownership moved to xmlan in #85/#86. Signerl removes the duplicated
parser/export/namespace and generic canonicalization unit cases, eight pure XML
file/entity cases, and the ten-case xmllint suite. Seven unused generic fixtures
are removed; unchanged `utf8.xml` and `preserved_content.xml` remain inputs for
real signature API tests. Independently signed and frozen protocol fixtures stay.
All original generic contracts remain in xmlan at the exact pinned revision.

Signerl retains its six signature-identity and four signature-removal unit cases,
all 71 public API cases, verifier/property/certificate/date tests, the combined
fresh-name parse/export/C14N/sign/verify atom probe, and the frozen baseline
consumer. Protocol/helper tests use the dependency directly except where testing
legacy compatibility or local signature-specific operations.

Two new CT cases prove direct xmlan application ownership/transitive startup in a
fresh VM, and exact compatibility file output/read-back/errors. The standalone
consumer now constructs and pattern-matches all five legacy XML aliases plus the
mode alias, includes the legacy forwarded header, and asserts the implicit XML
binding. Frozen parsed/export/canonical/RSA bytes remain externally supplied
oracles; fresh RSA keys remain in memory. The consumer verifies the frozen
signature, deterministic repeated signing, reconstruction bytes, and tampering.

`README.md`, `test/TESTS.md`, the migration contract, and fixture README describe
current ownership, immutable dependency/startup, compatibility APIs/types, and
focused commands. Signerl's CI no longer installs xmllint because its entire pure
interop suite now runs in xmlan's six-job gate. No required test is skipped.
Historical implementation logs retain their original pre-extraction descriptions.

## Validation and review

Native runtime: OTP 28.4.2 and rebar3 3.25.1, with isolated global configuration
and unchanged project plugin pins. Generated test certificates are ignored build
inputs, not committed source. The obsolete generated test profile was reset
before validation, preventing a deleted suite from surviving as a cached copy.

- Test first: the new startup contract failed because Signerl's application list
  contained no xmlan. After integration, all four compatibility/startup CT cases
  pass through the actual dependency.
- `rebar3 eunit`: 150 passed.
- Full `rebar3 test`: 150 EUnit + 76 CT = 226 cases; no skips.
- `rebar3 as test cover`: all ten Signerl production modules and total at 100%.
  No new coverage exclusions or weakened assertions are introduced. xmlan owns
  its separately verified 100% gate.
- `rebar3 flint`: passed. `rebar3 dialyzer`: passed for all ten production modules.
- Preprocessed function AST review: all eight other production modules differ
  only in generic call targets; all 18 generic compatibility exports are direct
  single-call delegates; signature predicates/removal match the original bodies
  after the corresponding generic helper retargeting.
- Compiled imports contain no xmerl call and no internal generic call through
  compatibility modules. Signature-specific identity/removal calls remain local.
- Both fetched dependency profiles and the lockfile match the exact reviewed SHA.
  All frozen fixture SHA256 hashes remain unchanged. Updated local doc links resolve.
- External consumer: all six transparent aliases, forwarded include, frozen
  XML/signature behavior, startup, and public API contracts pass against production
  BEAMs. Full dependency-PLT Dialyzer analysis passes.
- Opaque replacement negative control: the external tuple/type consumer fails
  Dialyzer with opacity findings (exit 2), proving transparent aliases matter.
- Changed exported-byte golden in a separate copy: the dependency-backed consumer
  fails its actual legacy export assertion. No expected file is regenerated.
- Final native `rebar3 tall`: passed before commit/push with all 226 cases,
  100% coverage, formatting/lint, Xref, and Dialyzer; no skipped checks.

All six latest-commit Signerl CI jobs must pass against the pinned dependency
before reporting merge readiness. A clean HTTPS consumer of the pushed Signerl
commit and its transitive xmlan pin will be recorded in the PR. The broader #88
baseline/security sweep and #89 final audit remain separate tasks.

## Recovery

Persistent attached source worktree:
`/Users/milanbor/.codex/worktrees/signerl-issue-56/signerl`, branch
`codex/issue-87-xmlan-dependency`.

Tracked diffs and untracked source files are saved outside temporary storage under
`/Users/milanbor/projects/signerl/.recovery/issue-87/`. This holds gate logs,
source/compiled-call review, exact dependency revisions, external consumer/type
controls, and a recovery source archive. A final Git bundle and patch are retained
before yielding. Existing unrelated changes in the user's original Signerl
checkout are preserved; generated certificates/private keys are not published.
