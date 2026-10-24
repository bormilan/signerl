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
- Existing API tests now expect an already_signed error on a second signing call and a
  structure error for an RSA key against an ECDSA method; an unrelated RSA key
  remains false. The EUnit transform mutation helper accepts the new chain shape.
- README, API contract, signing profile, property gap map and test responsibility
  map describe these public changes while retaining #54/#55 and ECDSA #53 gaps.
  Documentation updates are required because generated XML and rejection behavior
  change. No dependency, generic XML implementation or XML-only tests are added.

Initial validation and review (commit 35f7d39):

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

## Review follow-up: explicit signing failures

The maintainer requested actual errors instead of a maybe block propagating
error tuples in signerl_signature. Removed that block and its feature directive.
The signing_ids helper now returns the identity pair directly and raises
error(already_signed) or error(invalid_signature_structure) for rejected signing
input. These explicit reasons identify the failure without a nested badmatch.
Existing returned errors for hash/key/time selection and verification retain
their current handling; this change concerns the reviewed identity precondition.

Updated public API assertions first: both focused policy cases failed because
the prior implementation returned tuples instead of raising. The cases retain
successful signing/verification controls and assert the exact error reasons.
README, public API contract and signing profile document the chosen exceptions.
Follow-up validation: the two focused cases pass after the change. Complete
rebar3 test and final native rebar3 tall pass: 150 EUnit + 84 Common Test cases,
all eight modules and total coverage 100%, no failures or skips. rebar3 as test
cover, flint, Xref and Dialyzer pass. Reapplied the ferike review checklist;
no blocking findings. Documentation links/fences and git diff --check pass.
All six latest-head CI jobs must pass again after pushing this follow-up;
their immutable run/commit evidence is saved in the follow-up recovery folder.

Follow-up recovery copies and logs are stored under
/Users/milanbor/projects/signerl/.recovery/issue-52-signature-validation/error-policy-review/.
