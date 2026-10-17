# Signerl roadmap review — 17 October 2026

> Historical review snapshot before the approved roadmap updates. See the
> [application log](../implementations/roadmap_updates_2026-10-17.md) for the
> changes applied afterward and their validation. Issue states/assignments below
> describe the review snapshot.

## Recommendation

Keep the XML extraction complete and keep XAdES signing-time and certificate properties in the RSA-SHA256 MVP. The next milestone should finish signature correctness, settle the public API contract, and then simplify the implementation. Several issue descriptions still describe old code or superseded requirements; correct those before using the roadmap as a release checklist.

This review covers **all 54 GitHub issues (12 open, 42 closed), all six milestones, the 40-PR history and nine local task notes**. It compares the roadmap with merged `dev` revision [`36077b5`](https://github.com/bormilan/signerl/commit/36077b507284ce9b75f8b9076086e490f452d997). At review completion, recommendations below had **not** been applied to GitHub. This review initially added only the report and its implementation log; the later approved updates are recorded in the application log above.

[PR #94](https://github.com/bormilan/signerl/pull/94) is merged. Its three changed files document the selected profile; they do not implement the remaining checks. All six OTP 26/27/28 Ubuntu/Windows jobs passed on the merged revision ([CI run](https://github.com/bormilan/signerl/actions/runs/39044540261)). Existing passing gates do not prove the unfinished acceptance criteria below.

## Milestones

Counts below come from actual issue assignments, excluding pull requests, rather than milestone counters.

| Milestone | Current issues | Recommended disposition |
| --- | --- | --- |
| [0.1](https://github.com/bormilan/signerl/milestone/1) | 19 closed | Keep closed. The tooling/test baseline is complete; old formatter, lint and Docker task wording is historical. |
| [0.2](https://github.com/bormilan/signerl/milestone/2) | 7 closed | Keep closed. Add an ownership note if its description is refreshed: generic XML implementation and validation now belong to xmlan. |
| [0.3](https://github.com/bormilan/signerl/milestone/3) | 4 open, 2 closed | Keep open. Define its exit as the retained RSA-SHA256/XAdES profile implemented and tested, followed by ownership cleanup. Move #59 here so contract decisions precede refactoring. Correct the scope/status mismatch in #64. |
| [1.0.0](https://github.com/bormilan/signerl/milestone/4) | 2 open | Focus on #65 release acceptance after 0.3. Remove retired Docker and mandatory external test-application requirements. Make distribution and branch integration explicit. Include #43 only if Hex is chosen for this release. |
| [Post-1.0 — Interoperability CI](https://github.com/bormilan/signerl/milestone/5) | 1 open | Keep #40 after 1.0. Specify one independent signer and the exact retained RSA/XAdES profile. |
| [XML extraction into xmlan](https://github.com/bormilan/signerl/milestone/6) | 7 closed | Keep closed. The final ownership boundary in #89/PR #93 supersedes earlier wrapper/consumer-test plans. Do not restore generic XML code, suites or external consumer applications. |

Five open issues have no milestone: #37, #38, #42, #43 and #53. Assign them intentionally after their release-scope decisions; unassigned should not imply either mandatory or abandoned.

## Changes needed before the next implementation task

### 1. Correct #64's completion claim

[#64](https://github.com/bormilan/signerl/issues/64) is closed as completed, but its title still says **“Define and implement”** and its body says to keep it open until implementation. PR #94 explicitly uses `Refs #64` and records gaps owned by #52, #54, #55, #58 and #59. The profile document also still says #64 remains open.

**Recommendation:** keep the completed decision as a closed task, retitle it **“Define the 1.0 RSA-SHA256/XAdES profile”**, and narrow its completed criteria to scope selection, documentation and the inline example. Link implementation acceptance to the existing issues and the 0.3 milestone. Update the profile document's issue-status sentence accordingly. If the broad implementation scope is retained instead, reopen #64. Do not count the full profile as implemented or create a duplicate implementation umbrella.

Evidence: [profile and current gaps](https://github.com/bormilan/signerl/blob/36077b507284ce9b75f8b9076086e490f452d997/docs/signing_profile.md), [PR #94 implementation log](https://github.com/bormilan/signerl/blob/36077b507284ce9b75f8b9076086e490f452d997/docs/implementations/issue_64_xades_profile_2026-10-17.md).

### 2. Keep #52 as the next correctness implementation

[#52](https://github.com/bormilan/signerl/issues/52) is still needed. Reference decoding selects the expected two references without rejecting every additional reference, uses a fixed SignedProperties ID, and checks declared signature methods through an allowlist rather than agreement with the actual supplied key/operation. Generated reference transforms also differ from the selected target profile.

Refresh its code links to the merged tree and make these acceptance cases explicit:

- Exactly the two supported references; reject unknown/additional references and external dereferencing.
- Resolve unique actual IDs and bind SignedProperties, QualifyingProperties Target and the containing Signature.
- Match declared digest/signature methods with the supplied hash/key and performed operation.
- Generate and verify the selected reference canonicalization transforms in their defined order.
- Decide compatibility for old signatures without explicit reference canonicalization.
- Reject already-signed input and unsupported signature placement/count; cover nested/extra signatures and duplicate referenced IDs through Signerl behavior tests.

This is signature policy over xmlan's tree/API, not a reason to implement or retest generic XML processing in Signerl.

Evidence: [reference selection](https://github.com/bormilan/signerl/blob/36077b507284ce9b75f8b9076086e490f452d997/src/signerl_verify.erl#L142), [algorithm checks](https://github.com/bormilan/signerl/blob/36077b507284ce9b75f8b9076086e490f452d997/src/signerl_verify.erl#L214), [reference construction](https://github.com/bormilan/signerl/blob/36077b507284ce9b75f8b9076086e490f452d997/src/signerl_signature.erl#L109), [signing entry point](https://github.com/bormilan/signerl/blob/36077b507284ce9b75f8b9076086e490f452d997/src/signerl.erl#L50).

### 3. Keep #54/#55; rewrite the overlap with #37

[#54](https://github.com/bormilan/signerl/issues/54) and [#55](https://github.com/bormilan/signerl/issues/55) remain required because XAdES is retained. Missing/malformed certificate metadata can converge on `undefined`, and a SigningCertificateV2 property with no decoded KeyInfo currently bypasses its certificate digest check. SignedDataObjectProperties lookup errors are treated as absence. These are still relevant acceptance gaps, not discarded-feature work.

For #54, distinguish absent, malformed and valid metadata, state the certificate/key-binding guarantee, and preserve the valid certificate-less signing API. Do not equate verification with certificate-chain trust, validity-period or revocation checks. For #55, specify cardinality and malformed-known-property behavior separately from the policy for unknown extensions.

[#37](https://github.com/bormilan/signerl/issues/37) still claims that five validators are unconditional placeholders. [PR #48](https://github.com/bormilan/signerl/pull/48) already supplied structural validation, but the original request also includes semantics that remain incomplete. Rewrite #37 around the remaining policy-digest, URI/MIME/reference and certified-role semantics. Assign duplicate/malformed-container rejection to #55. Decide which optional semantics the MVP supports; defer excluded semantics explicitly and document their treatment. Do not close #37 as fully implemented or rerun its original implementation wholesale. Policy verification should not imply automatic network fetching.

Evidence: [certificate fallback and digest verification](https://github.com/bormilan/signerl/blob/36077b507284ce9b75f8b9076086e490f452d997/src/signerl_verify.erl#L307), [existing property validators and optional-container handling](https://github.com/bormilan/signerl/blob/36077b507284ce9b75f8b9076086e490f452d997/src/signerl_signed_properties.erl#L10).

### 4. Set the API contract in #59 before simplifying under #58

[#59](https://github.com/bormilan/signerl/issues/59) contains implementation/API decisions as well as documentation. Move it from 1.0.0 to 0.3, settle supported algorithms and return/raise behavior early, and finish its docs after the correctness work. The public hash type still advertises SHA-384/512 while signature construction supports SHA-256. Invalid key/certificate handling also needs the agreed contract. Some README complaints in the issue are already fixed; the new profile and inline example should count as completed work.

[#58](https://github.com/bormilan/signerl/issues/58) should then be a focused, behavior-preserving cleanup after #52/#54/#55. XML extraction has already removed generic Signerl XML modules and moved signature-specific removal/recognition into `signerl_dsig_utils`. Mark those parts done and rewrite the remaining scope around orchestration, key-material ownership, XAdES ownership and test-only helpers. Reuse xmlan's representation; avoid recreating generic wrappers/types or a transform framework. Keep the public arities and retained XAdES features.

Update `docs/signed_properties_scope_and_gaps.md` under #59: its missing-C14N and blanket property-validation claims are stale. Preserve the distinction between extraction, structural validation, cryptographic binding and trust.

Evidence: [public types/API](https://github.com/bormilan/signerl/blob/36077b507284ce9b75f8b9076086e490f452d997/src/signerl.erl#L4), [supported signing hash](https://github.com/bormilan/signerl/blob/36077b507284ce9b75f8b9076086e490f452d997/src/signerl_signature.erl#L31), [signature utilities](https://github.com/bormilan/signerl/blob/36077b507284ce9b75f8b9076086e490f452d997/src/signerl_dsig_utils.erl), [stale scope/gaps document](https://github.com/bormilan/signerl/blob/36077b507284ce9b75f8b9076086e490f452d997/docs/signed_properties_scope_and_gaps.md).

## Release and backlog decisions

### 5. Refresh #65's release checks and branch plan

[#65](https://github.com/bormilan/signerl/issues/65) still requires local Docker checks and a clean consumer installation example. Remove those mandatory gates: Docker was retired by #62/PR #72, and the external consumer application/checks were removed at the maintainer's request. Keep an inline usage example and tests of Signerl's own public signing/verification behavior.

Retain native EUnit/Common Test, 100% Signerl coverage, flint, Dialyzer, final native tall and all six latest-candidate GitHub tall jobs without required skips. Unicode, namespaces, content preservation and prolog handling belong here only as observable signing/verification regression cases, using xmlan rather than testing its generic implementation again.

Make the release integration plan explicit. The default branch is still `main`; at this snapshot `dev` has 103 unique commits and `main` has five unique commits, so the branches have diverged. Review/reconcile their histories before tagging a candidate from the release branch. These counts describe commits, not 103 distinct features. Do not force-reset a branch or change the default branch merely to close issues. Keep tagging/publication as a separately authorized release action.

Evidence: [current CI workflow](https://github.com/bormilan/signerl/blob/36077b507284ce9b75f8b9076086e490f452d997/.github/workflows/erlang.yml), [branch comparison](https://github.com/bormilan/signerl/compare/main...dev).

### 6. Give #43 an xmlan distribution prerequisite

[#43](https://github.com/bormilan/signerl/issues/43) is conditional on the initial distribution choice. A tagged Git dependency is already allowed by #65; if that is chosen, schedule Hex after 1.0. If Hex is chosen for 1.0, add a prerequisite for an appropriately versioned xmlan Hex package and switch Signerl's production dependency accordingly. Signerl currently pins xmlan Git revision `1fe39f6d414217584f514e70e43b8e7b4171f1ef`.

This dependency is material: Hex's Rebar3 publishing guide says package dependencies must be Hex packages and Git dependencies cannot be uploaded ([official guide](https://hex.pm/docs/rebar3-publish)). Prefer the documented nonpublishing `rebar3 hex build` for package inspection rather than relying on the issue's assumed `publish --dry-run` command ([Rebar3 package management](https://www.rebar3.org/docs/package_management/)). Define package contents, metadata, changelog and supported public API docs before the separate publication action. Do not turn every exported internal helper into a promised public API or restore a standalone consumer gate.

### 7. Make an explicit pre-release decision about #53

[#53](https://github.com/bormilan/signerl/issues/53) is an existing ECDSA wire-format defect, not just a new algorithm enhancement. Current source still passes OTP signature bytes directly between signing/base64 and verification; no XMLDSig ECDSA conversion is visible. This review did not rerun the earlier runtime reproduction.

The selected MVP is RSA-SHA256, so ECDSA need not be added to that profile. Nevertheless, decide its supported status through #59: if supported/exposed as a supported feature for 1.0, fix #53 before release; otherwise explicitly exclude it from the release contract and decide whether unsupported calls should be rejected. Do not leave a known format defect looking supported because internal round trips pass. The required ECDSA octet representation is specified by [XMLDSig](https://www.w3.org/TR/xmldsig-core1/#sec-ECDSA).

### 8. Schedule #38/#42 later; retain #40's purpose

[#38](https://github.com/bormilan/signerl/issues/38) (more algorithms) and [#42](https://github.com/bormilan/signerl/issues/42) (multiple/counter-signatures) should be explicitly marked post-1.0/backlog. They are outside the selected single-signature RSA profile. When #42 is scheduled, separate multiple signatures from countersignatures if they need different acceptance criteria.

Keep [#40](https://github.com/bormilan/signerl/issues/40) in its existing post-1.0 milestone. Select one Python or Java implementation, verify both directions for the supported Signerl signature/profile, include independent reference processing and tampering controls, and keep it a focused extra job. It validates Signerl's interoperability, not xmlan's generic internals, and is not a reason to restore external consumer/type-analysis gates.

## Historical tasks and local notes

Most closed issues should stay closed. Unchecked boxes alone do not establish unfinished work; some original scope was intentionally superseded.

- **#35:** Exclusive C14N support exists, but the original PrefixList and public signing-mode-option promises are not delivered by the current Signerl API. Narrow the historical completion note. Any generic InclusiveNamespaces PrefixList enhancement belongs in xmlan; signing-mode selection is a future Signerl feature only if wanted. Do not reopen generic canonicalization work in Signerl.
- **#34/#36:** retain completed integration/property construction history. Reference enforcement belongs to #52 and certificate binding to #54; do not treat historical closure as proof that all verification semantics are finished.
- **#26:** retain the implemented review-skill work; distinguish its broader optional agent wishlist from completed functionality. Docker-related agent ideas are obsolete. This is not a release blocker.
- **#83/#87/#88:** annotate superseded compatibility/consumer-probe promises with final #89/PR #93 scope if these historical descriptions are edited. Do not restore removed requirements.
- Replace obsolete phase labels with labels that reflect the selected release/backlog scope when scheduling issues; the old phase buckets no longer reliably express priority.

The nine files under `docs/tasks/` should be archived or marked superseded, with issue links rather than maintained as a competing backlog:

| Local task note | Current disposition |
| --- | --- |
| `add_ci_lint_and_dialyzer.md` | Completed; current native tall and six CI jobs supersede old commands. |
| `add_local_docker_otp_matrix_checks.md` | Retired by #62/PR #72; do not reintroduce. |
| `add_signed_info.md` | Construction/integration complete; remaining enforcement is #52. |
| `add_signed_properties.md` | Construction complete; SigningTime-only wording is obsolete; follow #54/#55/#37 for remaining validation. |
| `extract_verify_module.md` | Completed extraction; remaining ownership cleanup is #58. |
| `migrate_helper_eunit_to_ct.md` | Superseded by #67/#68 and the current meaningful EUnit/Common Test split. |
| `refactor_signed_properties_verification.md` | Refactor implemented; placeholder-validator instructions are obsolete; remaining work is #55/#37. |
| `restructure_signed_properties_xades_object.md` | Structure implemented; replace outdated payload/error instructions with history links. |
| `return_signed_message.md` | Completed; old whole-message verification instructions conflict with current SignedInfo signing. |

## Recommended sequence

1. Correct #64's scope/status wording and refresh the affected task descriptions.
2. Set #59's supported API/failure/compatibility decisions; reconcile #37's supported-property scope.
3. Implement #52, then #54 and #55, retaining XAdES and using signature-focused regression tests.
4. Complete #58 as a behavior-preserving cleanup, then finish #59 documentation against the resulting implementation.
5. Complete #65 release acceptance, including the #53 support decision and branch integration. Include #43/xmlan packaging only if Hex is chosen.
6. Keep #38/#42 and the broader optional semantics outside the MVP; run #40 after 1.0 as planned.

No new milestone is necessary to finish the current release. If deferred issues are assigned a milestone, make it explicitly non-blocking for 1.0; do not overload the narrowly named interoperability milestone with unrelated algorithm/multisignature work.

## Complete issue disposition

Every issue in the snapshot appears once below. “Keep closed” preserves completed or superseded history; it is not a claim that every original unchecked box was independently reimplemented or revalidated during this review.

| Issue | State | Current milestone | Recommended action |
| --- | --- | --- | --- |
| [#2 — Add erlfmt](https://github.com/bormilan/signerl/issues/2) | Closed | 0.1 | Keep closed; formatter baseline is historical. |
| [#3 — Add rebar3 test command](https://github.com/bormilan/signerl/issues/3) | Closed | 0.1 | Keep closed; current aggregate test/tall aliases supersede the initial command. |
| [#4 — Add elvis](https://github.com/bormilan/signerl/issues/4) | Closed | 0.1 | Keep closed; current rebar3_lint tooling supersedes the initial Elvis setup. |
| [#5 — Add common tests](https://github.com/bormilan/signerl/issues/5) | Closed | 0.1 | Keep closed; Common Test baseline remains. |
| [#6 — Add signer module](https://github.com/bormilan/signerl/issues/6) | Closed | 0.1 | Keep closed; signer exists; correctness follows #52. |
| [#7 — Make a validator module](https://github.com/bormilan/signerl/issues/7) | Closed | 0.1 | Keep closed; verifier exists; remaining verification gaps have dedicated issues. |
| [#8 — Generate certs](https://github.com/bormilan/signerl/issues/8) | Closed | 0.1 | Keep closed; certificate generation is integrated into current checks. |
| [#9 — Add certs module](https://github.com/bormilan/signerl/issues/9) | Closed | 0.1 | Keep closed; certificate module exists; metadata correctness follows #54. |
| [#10 — Make a full test](https://github.com/bormilan/signerl/issues/10) | Closed | 0.1 | Keep closed; integration baseline retained with later control fixes. |
| [#11 — Convert to a lib](https://github.com/bormilan/signerl/issues/11) | Closed | 0.1 | Keep closed; library conversion is complete; distribution is #43/#65. |
| [#12 — Add tall to ci check](https://github.com/bormilan/signerl/issues/12) | Closed | 0.1 | Keep closed; six current CI jobs execute tall. |
| [#13 — Add 100% coverage](https://github.com/bormilan/signerl/issues/13) | Closed | 0.1 | Keep closed; retain the 100% coverage gate. |
| [#14 — Fix dialyzer error](https://github.com/bormilan/signerl/issues/14) | Closed | 0.1 | Keep closed; retain Dialyzer in the quality gate. |
| [#18 — xml parser work with binary](https://github.com/bormilan/signerl/issues/18) | Closed | Unassigned | Keep closed; binary XML processing is now xmlan-owned. |
| [#26 — improve agents](https://github.com/bormilan/signerl/issues/26) | Closed | Unassigned | Keep closed; narrow historical claims to delivered review tooling; defer optional agent ideas. |
| [#27 — solve opaque problem in signerl_xml](https://github.com/bormilan/signerl/issues/27) | Closed | 0.2 | Keep closed; old Signerl XML representation/API no longer exists; xmlan owns the boundary. |
| [#28 — make test groups](https://github.com/bormilan/signerl/issues/28) | Closed | Unassigned | Keep closed; test organization was further superseded by #67/#68. |
| [#33 — Implement XML Canonicalization (C14N 1.1)](https://github.com/bormilan/signerl/issues/33) | Closed | Unassigned | Keep closed; generic C14N implementation now belongs to xmlan. |
| [#34 — Integrate C14N into sign/verify pipeline](https://github.com/bormilan/signerl/issues/34) | Closed | Unassigned | Keep closed; integration exists; reference/method enforcement remains #52. |
| [#35 — Add Exclusive C14N support](https://github.com/bormilan/signerl/issues/35) | Closed | Unassigned | Keep closed with a narrowed completion note; defer PrefixList to xmlan and optional signing-mode API separately. |
| [#36 — Implement SigningCertificateV2 property](https://github.com/bormilan/signerl/issues/36) | Closed | Unassigned | Keep closed; construction/basic digest support exists; remaining binding follows #54. |
| [#37 — Implement remaining signed property validators](https://github.com/bormilan/signerl/issues/37) | Open | Unassigned | Rewrite around remaining semantics after PR #48; distinguish #55 and decide MVP/deferred scope. |
| [#38 — Add algorithm configuration (SHA-384/512, RSA-PSS)](https://github.com/bormilan/signerl/issues/38) | Open | Unassigned | Explicitly defer additional algorithms beyond 1.0. |
| [#39 — Add XXE and XML bomb protections](https://github.com/bormilan/signerl/issues/39) | Closed | 0.2 | Keep closed; generic parser protections are xmlan-owned. |
| [#40 — Add post-1.0 two-way interoperability CI with a Python or Java signer](https://github.com/bormilan/signerl/issues/40) | Open | Post-1.0 — Interoperability CI | Keep post-1.0; choose one independent signer and the exact retained RSA/XAdES profile. |
| [#41 — Namespace-aware XML handling](https://github.com/bormilan/signerl/issues/41) | Closed | 0.2 | Keep closed; generic namespace processing is xmlan-owned. |
| [#42 — Multi-signature support](https://github.com/bormilan/signerl/issues/42) | Open | Unassigned | Explicitly defer beyond 1.0; split multiple/counter-signature work when scheduled. |
| [#43 — Hex.pm package publication](https://github.com/bormilan/signerl/issues/43) | Open | Unassigned | Conditional release task; add xmlan Hex prerequisite if Hex is chosen, otherwise defer. |
| [#49 — Fix UTF-8 handling throughout XML signing and export](https://github.com/bormilan/signerl/issues/49) | Closed | 0.2 | Keep closed; retain Signerl Unicode behavior tests; generic handling belongs to xmlan. |
| [#50 — Preserve signed XML content through parsing and serialization](https://github.com/bormilan/signerl/issues/50) | Closed | 0.2 | Keep closed; retain signature content-preservation regressions without generic XML suites. |
| [#51 — Reject trailing garbage and multiple document elements when parsing XML](https://github.com/bormilan/signerl/issues/51) | Closed | 0.2 | Keep closed; complete-document parsing belongs to xmlan; retain Signerl error propagation. |
| [#52 — Validate every reference and enforce signature IDs, targets, and algorithms](https://github.com/bormilan/signerl/issues/52) | Open | 0.3 | Keep in 0.3 and implement next; refresh evidence and add profile/legacy-compatibility cases. |
| [#53 — Encode and decode ECDSA SignatureValue in XMLDSig format](https://github.com/bormilan/signerl/issues/53) | Open | Unassigned | Decide support before release; fix for supported ECDSA or explicitly exclude/gate via #59. |
| [#54 — Distinguish missing and malformed certificate metadata during verification](https://github.com/bormilan/signerl/issues/54) | Open | 0.3 | Keep in 0.3; require absent/malformed distinction and explicit certificate/key binding. |
| [#55 — Reject ambiguous or malformed signed-property containers instead of skipping validation](https://github.com/bormilan/signerl/issues/55) | Open | 0.3 | Keep in 0.3; define known-container/cardinality checks separately from unknown extensions. |
| [#56 — Define deterministic signing-time behavior and validate real calendar dates](https://github.com/bormilan/signerl/issues/56) | Closed | 0.3 | Keep closed; fixed-time API and real calendar validation are complete. |
| [#57 — Make signature regression tests prove the intended failure and use one XML path](https://github.com/bormilan/signerl/issues/57) | Closed | 0.1 | Keep closed; preserve passing controls and one XML dependency path. |
| [#58 — Simplify module ownership and make the sign/verify flow easy to follow](https://github.com/bormilan/signerl/issues/58) | Open | 0.3 | Refresh after extraction; perform remaining ownership cleanup after correctness fixes. |
| [#59 — Align public API contracts and documentation with the implemented signing profile](https://github.com/bormilan/signerl/issues/59) | Open | 1.0.0 | Move to 0.3; decide API contracts first, finish accurate docs after implementation. |
| [#60 — Make formatter/linter versions and CI cache inputs reproducible](https://github.com/bormilan/signerl/issues/60) | Closed | 0.1 | Keep closed; retain reproducible formatter/linter/cache inputs. |
| [#61 — Bound XML name handling so untrusted input cannot exhaust VM atoms](https://github.com/bormilan/signerl/issues/61) | Closed | 0.2 | Keep closed; generic name/atom protections are xmlan-owned. |
| [#62 — Standardize on Erlang/OTP 28 and land its CI matrix coverage](https://github.com/bormilan/signerl/issues/62) | Closed | 0.1 | Keep closed; native OTP/matrix setup supersedes Docker requirements. |
| [#63 — Upgrade rebar3_lint and migrate the Elvis configuration](https://github.com/bormilan/signerl/issues/63) | Closed | 0.1 | Keep closed; lint tooling/configuration upgrade is complete. |
| [#64 — Define and implement the 1.0 enveloped RSA-SHA256 profile](https://github.com/bormilan/signerl/issues/64) | Closed | 0.3 | Retitle/narrow to completed profile definition; otherwise reopen its broad implementation scope. |
| [#65 — Complete the 1.0.0 MVP release acceptance checklist](https://github.com/bormilan/signerl/issues/65) | Open | 1.0.0 | Refresh release acceptance; remove retired gates, plan branch integration and distribution. |
| [#67 — Organize tests by responsibility and combine EUnit/Common Test coverage](https://github.com/bormilan/signerl/issues/67) | Closed | 0.1 | Keep closed; current responsibility-based EUnit/Common Test organization supersedes old plans. |
| [#68 — Simplify test fixtures, named cases, and assertions](https://github.com/bormilan/signerl/issues/68) | Closed | 0.1 | Keep closed; retain simplified fixtures and meaningful assertions. |
| [#83 — Define the xmlan extraction boundary and compatibility contract](https://github.com/bormilan/signerl/issues/83) | Closed | XML extraction into xmlan | Keep closed; annotate early compatibility promises as superseded by #89/PR #93. |
| [#84 — Bootstrap xmlan with its public XML tree API and quality gates](https://github.com/bormilan/signerl/issues/84) | Closed | XML extraction into xmlan | Keep closed; xmlan bootstrap belongs to the dependency repository. |
| [#85 — Extract generic XML parsing, serialization, and namespace helpers into xmlan](https://github.com/bormilan/signerl/issues/85) | Closed | XML extraction into xmlan | Keep closed; parser/serializer/namespace extraction is complete. |
| [#86 — Extract the generic canonicalization engines into xmlan](https://github.com/bormilan/signerl/issues/86) | Closed | XML extraction into xmlan | Keep closed; generic canonicalization engines are in xmlan. |
| [#87 — Replace Signerl XML implementations with a pinned xmlan dependency](https://github.com/bormilan/signerl/issues/87) | Closed | XML extraction into xmlan | Keep closed; pinned dependency is in use; old wrapper/probe promises were superseded. |
| [#88 — Prove XML extraction preserves Signerl behavior and security boundaries](https://github.com/bormilan/signerl/issues/88) | Closed | XML extraction into xmlan | Keep closed; final acceptance scope supersedes removed generic/consumer checks. |
| [#89 — Finish XML extraction with signature-only Signerl code and tests](https://github.com/bormilan/signerl/issues/89) | Closed | XML extraction into xmlan | Keep closed; final signature-only ownership boundary is complete. |

## Validation and limits

GitHub issue states/assignments were cross-checked through both the issue listing and REST listing, and the merge, CI head and main/dev comparison were verified read-only. Source, tests, workflow, documentation and implementation history were reviewed for scope/status evidence. Generic XML test applications and removed XML machinery were not restored.

This was a roadmap/source review, not a fresh runtime or security audit. No EUnit, Common Test, coverage, flint, Dialyzer or native tall commands were rerun because runtime code/configuration did not change and no commit/push is being made. The existing merged-revision six-job CI result is reported separately above. #53's prior runtime reproduction was not repeated. Markdown/inventory validation results and recovery locations are recorded in the implementation log.
