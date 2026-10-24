# Issue #52 — signature references, identities and algorithms

## Scope and reasoning

Implement exactly two supported references, unique actual IDs and XAdES target
binding, method/key agreement, strict reference transform pairs and one direct
child enveloped signature. New output declares C14N 1.1 reference transforms;
verification retains the complete legacy pair and separate Exclusive C14N
SignedInfo support. XML processing remains delegated to xmlan. Certificate and
known-property validation follow separately in #54/#55.

## Work and validation

Investigation: read issue #52, merged API contract/profile, public orchestration,
builder, verifier, signature helpers and their EUnit/Common Test callers. No
CodeGraph index exists in this worktree. New public policy regressions refresh
reference digests and re-sign altered SignedInfo with OTP, with cryptographic
passing controls, before implementation changes.

Changed files and behavior:

- `src/signerl_signature.erl`: reject existing signatures/duplicate identities,
  select deterministic collision-free signature/properties IDs, generate the
  explicit document and SignedProperties transform chains.
- `src/signerl_dsig_utils.erl`: signature-policy inventory counts XMLDSig
  signatures at every depth and document-wide unqualified Id / xml:id values.
  Namespace resolution uses xmlan; traversal uses an explicit work stack.
- `src/signerl_verify.erl`: exactly two references, actual unique identity/target
  resolution, strict complete explicit/legacy pairs, parameter checks, digest
  methods and signature-method/key agreement. Hash the same properties element
  whose identity was resolved. SignedInfo C14N remains separate. Reject extra,
  root and nested signatures before cryptographic verification.
- `src/signerl.erl`: delegate final method/key checking and signature operation
  to the verifier; keep public arities, file/key conveniences and native failures.
- `test/signerl_signature_policy_SUITE.erl`: 11 public policy cases covering
  both complete formats with refreshed digests and OTP-signed SignedInfo. Each
  altered structure has a successful direct cryptographic control. Cases cover
  extra/missing/unknown references, IDs/targets, duplicate identities/containers,
  RSA/EC method mismatch, digest methods, hybrids/order/parameters, namespace
  and whitespace controls, placement, already-signed input and generated IDs.
- Existing API tests now expect already_signed on a second signing call and a
  structure error for an RSA key against an ECDSA method; an unrelated RSA key
  remains false. The EUnit transform mutation helper accepts the new chain shape.
- README, API contract, signing profile, property gap map and test responsibility
  map describe these public changes while retaining #54/#55 and ECDSA #53 gaps.
  Documentation updates are required because generated XML and rejection behavior
  change. No dependency, generic XML implementation or XML-only tests are added.

Validation and review:

- Before implementation, the focused suite reported 9 failures / 1 pass. Legacy
  controls reproduced true for an additional unresolved reference, a missing
  signature Id, RSA bytes declaring ECDSA and a transform parameter attribute.
  Explicit-pair verification, already-signed rejection and ID collision tests also
  failed as expected. Logs: ct-red.log and ct-legacy-red.log in recovery storage.
- Final rebar3 test: 150 EUnit and 84 Common Test cases, no failures/skips;
  all eight production modules and total coverage 100%.
- rebar3 flint: PASS after sharing the repeated transform constructor and
  simplifying repeated test setup. No lint rules were disabled.
- rebar3 dialyzer: PASS, all eight production modules analyzed.
- Native validation uses OTP 28.4.2 / rebar3 3.25.1, the normal project build/cache
  and the documented empty REBAR_GLOBAL_CONFIG_DIR under recovery storage.
  Project plugins/gates stay enabled; user-global settings are unchanged.
- Applied the project ferike review checklist: no blocking findings. Reused the
  resolved properties subtree for hashing, removed redundant signature filtering
  after the one-signature placement check and kept new traversals tail-recursive.
  Remaining certificate binding and known-property validation are #54/#55;
  ECDSA wire encoding remains #53. There is no interoperability claim for ECDSA.
- rebar3 as test cover: PASS, combined total 100%.
- Final native rebar3 tall: PASS, 150 EUnit / 84 CT, 100% coverage,
  formatting/lint, Xref and Dialyzer; no failed or skipped checks.
- Markdown links/fences, test-map counts and git diff --check: PASS.
- Six latest-head GitHub Actions jobs (OTP 26/27/28 on Ubuntu and Windows)
  must pass before merge. Their results are recorded on the PR and in recovery
  storage after pushing; this local result is not a substitute for those jobs.

The narrow compatibility case is the complete former pair only. W3C reference
validation requires checking every reference; the exact two-reference allowlist
and the retained implicit C14N 1.1 legacy processing are Signerl profile choices,
not general XMLDSig default behavior:
https://www.w3.org/TR/xmldsig-core1/#sec-ReferenceValidation.

## Persistence

Implementation worktree: /Users/milanbor/.codex/worktrees/signerl-issue-56/signerl.
Recovery copies, tracked diffs, untracked source and validation logs are retained
outside temporary storage under
/Users/milanbor/projects/signerl/.recovery/issue-52-signature-validation/.
The prior roadmap-sync audit note was stashed before switching to this branch,
then restored; it remains a local audit artifact outside the issue #52 commit.
