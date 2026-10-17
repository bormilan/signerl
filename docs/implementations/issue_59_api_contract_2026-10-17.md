# Public API contract first pass (#59) — 17 October 2026

## Scope

The maintainer requested the next roadmap task. PR #95 was still open, so this
work extends that existing #59 PR rather than opening a second concurrent PR for
the issue. This is the early contract/alignment pass; #59 stays open for final
alignment after #52/#54/#55 correctness and #58 ownership work.

## Investigation and decisions

Reviewed public APIs, signature/reference verification, key/certificate helpers,
callers and existing tests. This worktree has no .codegraph directory; CodeGraph
was skipped as instructed. Signing rejected unsupported hashes explicitly while
verification folded that error into invalid_signature_structure. Public types
advertised unsupported SHA-384/512, omitted sign/4's undefined certificate option
and omitted the existing private-key verification convenience.

- Keep public arities and binary/file/key/certificate conveniences.
- Support sha256; preserve explicit unsupported_hash errors in both operations.
- Keep native OTP errors for malformed caller-supplied DER/key material and
  invalid argument representations; do not add catch/translation wrappers.
- Keep legacy ECDSA callable, without a new rejection gate, but explicitly outside
  the supported 1.0 XMLDSig profile until #53's wire-format defect is fixed.
- #52 generates explicit reference C14N chains and retains only the complete
  legacy chain pair for verification, with all reference/ID/algorithm checks
  still mandatory. No arbitrary transform compatibility framework is added.
- #54 must require coherent embedded certificate/SigningCertificateV2 metadata
  and key correspondence; both absent remains valid. Binding is not trust.
- #37 optional semantic extensions are post-1.0. #55's known-property structural
  rejection remains MVP; unknown extensions may be ignored semantically while
  their bytes remain covered by SignedProperties.

The future reference/certificate/property decisions are documented targets,
not claims those checks are implemented by this pass.

## Validation-first evidence

Extended the two public unsupported-hash cases to SHA-384 and SHA-512 with a
passing SHA-256 control. Added public cases for verifying valid signed XML
without a declaration, malformed PEM/key-term native failures, and malformed
certificate DER through sign/4 and sign/5.

The first --case invocation bypassed required Common Test group fixtures and
failed on undefined setup values; it is not defect evidence. The corrected
--group sign_group,verify_fixture_error_group,keyinfo_group run reproduced the
real mismatch: 62 cases passed and one failed, expected unsupported_hash but got
invalid_signature_structure. After the focused fix, all 63 affected cases pass.
The native-failure cases deliberately do not pin OTP-specific exception reasons.

## Changes

- src/signerl.erl: narrow hash(), include optional undefined certificate for
  sign/4, and include the supported private-key verification input.
- src/signerl_verify.erl: preserve unsupported_hash instead of misclassifying it
  as malformed signature structure. Other error mapping is unchanged.
- test/signerl_api_SUITE.erl: public contract regressions/characterization above.
- docs/api_contract.md: arities/inputs/errors, compatibility decisions, binding and
  optional-property boundaries, inline example, current read order and public
  legacy test-key documentation.
- README/profile/property-gap/test docs: synchronize supported/current/target
  behavior; remove the misleading blanket invalid_signature and chain-trust
  examples. No generic XML code, test application or dependency test is added.

## Validation and review

Affected Common Test groups: PASS (63 cases). Complete native rebar3 test:
PASS (150 EUnit + 73 Common Test = 223 cases), 100% coverage across eight
production modules. Explicit as test cover, flint and Dialyzer: PASS. Final
native tall: PASS, including all 223 cases, 100% coverage, formatting/lint, Xref
and Dialyzer, with no required skips. Commands use the documented task-owned
empty REBAR_GLOBAL_CONFIG_DIR; no user-global settings or project gates changed.
Markdown links/fences, test-map counts and git diff --check: PASS. Latest-head
six-job CI results are recorded in PR #95 after push and must all pass before
merge. No merge is performed automatically.

Ferike review: no blocking findings. Corrected wording to distinguish the
canonicalized bytes covered by the signature from the serialized XML tree.
Simplification follow-up: keep the already tracked orchestration/key/time
ownership work in #58; this fix needs no wrapper or new abstraction.

## Persistence

Persistent worktree: /Users/milanbor/.codex/worktrees/signerl-issue-56/signerl.
Branch: codex/roadmap-review-2026-10-17; existing PR #95 targets dev.
Validation logs and recovery copies of tracked diffs/untracked source are saved
outside temporary storage under
/Users/milanbor/projects/signerl/.recovery/issue-59-api-contract/.
The original checkout and its unfinished changes remain intact.
