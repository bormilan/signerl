# Issue #55: signed-property structure

## Problem and scope

Optional-container lookup treated every error as absence. A valid signature with
one invalid SignedDataObjectProperties failed, but two identical invalid
containers verified successfully after refreshing its digests and signature.
Known-property readers also selected first/last duplicate fields or skipped
malformed present values. This change enforces the selected XAdES structural
boundary without adding the semantic work deferred by #37.

## Changes and acceptance

- `src/signerl_xades_xml.erl` counts the two known property containers using
  xmlan child lookup. Missing optional data-object properties remain allowed;
  duplicate containers return `duplicate_property` and cannot disable checks.
- `src/signerl_signed_properties.erl` validates singleton known fields and all
  present supported text values, including nested identifier documentation.
  Policy branches are exclusive. Commitment scope is exactly one all-objects
  marker or one-or-more text references. Repeated role/format/commitment/reference
  items stay supported. Known containers accept formatting whitespace; unknown
  extensions and other namespaces stay semantically ignored while signed.
- Shared helpers express Signerl property cardinality and value policy. Parsing,
  namespace expansion, serialization and canonicalization remain xmlan APIs;
  no generic XML implementation, tests or dependency gate is added.
- Existing extraction regressions now reject malformed known fields instead of
  recording their silent omission. The public property-policy suite refreshes
  both digests and re-signs through OTP independently of Signerl validation.
- Public/profile/property-scope docs and the test overview are updated in this
  task because rejection behavior changes.

This is the supported structural reader subset, not full XAdES schema validation.
Minimal ObjectReference-only DataObjectFormat, empty production place and the
legacy SigningCertificate presence marker retain their existing boundaries.
Roles remain opaque supported text; certificate trust, policy material, role
certification, URI/MIME meaning and referenced-object semantics are outside scope.
The XAdES 1.3.2 object-identifier and commitment-scope shapes were checked against
[ETSI TS 101 903 v1.3.2](https://uri.etsi.org/01903/v1.3.2/ts_101903v010302p.pdf).

## Validation

- Before implementation: initial public suite 13 failures / 3 passes; focused
  unit suite 21 failures / 90 cases. Failures reproduced accepted duplicates and
  malformed known fields, with passing controls.
- Exact recorded bypass: one invalid container returned
  `invalid_data_object_format`; two identical invalid containers returned `true`.
  This was observed before changing the container lookup.
- Review found that the first whitespace/text implementation could raise on
  non-ASCII container text or reject valid CJK field values. Both were reproduced
  through the public verifier before correction. Whitespace now checks only XML
  whitespace; property text conversion uses xmlan, with a narrow malformed-value
  boundary that cannot catch caller crypto errors.
- Final native test gate: 169 EUnit + 117 Common Test = 286 cases pass, with
  100% coverage across all eight production modules and no skipped tests.
- The ferike review checklist found no remaining blocking findings. Repeated
  parent lookup/ownership simplification remains #58.
- Flint initially caught a test debug log; assertions now include mutation labels
  directly. The affected 20-case public suite passed after that adjustment.
- Native `rebar3 flint`, `rebar3 dialyzer`, `rebar3 as test cover` and final
  `rebar3 tall` all pass with rebar3 3.25.1 on OTP 28.4.2. Tall includes the full
  286-case suite, 100% coverage, formatting, lint, Xref and Dialyzer. No required
  check or test is skipped. The default PATH initially selected rebar3 3.23.0;
  final gates explicitly used the existing pinned 3.25.1 binary.
- Documentation validation: current README/API/profile/property-scope/test docs
  agree with behavior, test counts sum correctly, relative links resolve and
  `git diff --check` passes. Historical logs are left as historical evidence.
- All six latest-head OTP 26/27/28 Ubuntu/Windows tall jobs must pass before
  merge; CI completion evidence is retained in the recovery directory.

Native commands use an empty task-local `REBAR_GLOBAL_CONFIG_DIR` to avoid the
pre-existing user-global rebar3_run linker issue, while retaining native OTP,
normal dependency/build caches and all configured project gates.

## Recovery

Persistent source worktree:
`/Users/milanbor/.codex/worktrees/signerl-issue-56/signerl`.
Recovery copies, tracked diff and command logs:
`/Users/milanbor/projects/signerl/.recovery/issue-55-property-validation/`.
The pre-existing untracked roadmap audit remains local and outside this PR.
