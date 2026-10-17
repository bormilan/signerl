# Apply roadmap review — 17 October 2026

## Request and scope

The maintainer approved applying the [roadmap review](../reviews/roadmap_review_2026-10-17.md).
This task reconciles roadmap metadata and repository documentation; it does not
implement the remaining signing defects, choose a distribution method, publish a
release or merge branches/PRs.

## Applied GitHub changes

- Updated 20 issue bodies: #26, #34, #35, #36, #37, #38, #40, #42, #43, #52, #53,
  #54, #55, #58, #59, #64, #65, #83, #87 and #88.
- Retitled #64 as completed profile definition and #37 as remaining semantic
  validation after PR #48. Both original issue states were preserved.
- Moved #59 from 1.0.0 to 0.3. It owns early contract decisions and final docs;
  this documentation PR will not complete its implementation acceptance criteria.
- Refreshed four milestone descriptions (0.2, 0.3, 1.0.0 and post-1.0
  interoperability), preserving all six milestone states. The XML migration stays
  closed with its final signature-only ownership boundary.
- Added scope: mvp, scope: post-1.0 and scope: decision labels; replaced obsolete
  phase labels on the 12 open issues while preserving unrelated labels/assignees.
- Removed retired Docker/consumer-app requirements from active release planning.
  Recorded conditional Hex/xmlan packaging, ECDSA support and main/dev integration
  decisions without making those decisions or claiming defects fixed.

## Repository documentation

- docs/signing_profile.md: correct #64 completion scope and synchronize the
  implementation sequence, ECDSA decision and conditional packaging dependency.
- docs/signed_properties_scope_and_gaps.md: replace missing-C14N/all-properties-
  validated claims with current extraction/check boundaries and issue ownership.
- Nine docs/tasks notes: replace obsolete checklists with archival summaries and
  links to active ownership/implementation history. docs/tasks/README.md explains
  that GitHub is the active backlog.
- Preserve the review/report log as an explicit pre-update snapshot; add this log
  for the approved follow-up. No source/tests/configuration or public behavior
  changed. README/API implementation changes remain #59 work.

## Why this resolves the request

Each approved recommendation has an issue/milestone/document owner. The roadmap
no longer counts profile documentation as finished enforcement, repeats already
implemented placeholder work, or requires deliberately removed machinery.
Correctness precedes refactoring; optional features and conditional decisions do
not silently expand the RSA/XAdES MVP. Generic XML ownership stays in xmlan.

## Validation

- PASS: saved GitHub bodies/titles/labels/milestone assignment match all 20
  prepared patches. Verified all 54 issues remain 12 open/42 closed with their
  original states/state reasons and assignees; unrelated metadata was preserved.
- PASS: all four saved milestone descriptions match; every milestone's original
  title/state/deadline was preserved. Only #59 changed milestone assignment.
- PASS: all 15 changed Markdown files, 53 relative links, nine archival task
  summaries, current-source links/line bounds, sequence numbering and whitespace
  validate; source/tests/configuration are unchanged. Manual review found no
  blocking scope/status or documentation findings.
- PASS: native rebar3 test (150 EUnit + 70 Common Test, 100% coverage), flint,
  Dialyzer and final native tall (all 220 cases, 100% across eight production
  modules, formatting/lint, Xref and Dialyzer; no skipped required checks).
- Initial commands exited successfully but logged an unrelated user-global
  rebar3_run arm64 linker/load error. Following test/TESTS.md, reran flint,
  Dialyzer and final tall with REBAR_GLOBAL_CONFIG_DIR pointing to an empty
  task-owned directory; the final logs are clean. No project check was disabled
  and no user-global configuration was changed.
- A documentation-only PR targeting dev will reference #59 without closing it.
  Latest-head six-job CI results are recorded in the PR checks after creation;
  all six are required before merge. This task does not merge automatically.

## Persistent work and recovery

Worktree: /Users/milanbor/.codex/worktrees/signerl-issue-56/signerl.
Branch: codex/roadmap-review-2026-10-17.
Before/after metadata, prepared patches, validation and gate logs are saved at
/Users/milanbor/projects/signerl/.recovery/roadmap-review-2026-10-17/.
Recovery copies of all changed/untracked documentation and tracked diffs are saved
under that directory's applied-documents/ folder before yielding/commit.
The original project checkout and its unfinished changes remain intact.
