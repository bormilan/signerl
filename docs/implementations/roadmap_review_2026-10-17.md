# Roadmap review — 17 October 2026

This log records the initial review-only task. The subsequent approved changes
are recorded in [the roadmap application log](roadmap_updates_2026-10-17.md).

## Request and outcome

Review all tasks and milestones after PR #94 merged and report recommended changes. This task produces a review, not GitHub roadmap edits or implementation fixes.

## Files and reasoning

- `docs/reviews/roadmap_review_2026-10-17.md`: reviews all 54 issues, all six milestones, PR history, nine local task notes and current merged code. Includes a complete per-issue disposition, recommended sequence and evidence for scope/status corrections.
- `docs/implementations/roadmap_review_2026-10-17.md`: this log.

The review keeps generic XML ownership in xmlan, preserves the maintainer's XAdES decision, and distinguishes completed profile documentation from remaining implementation. It recommends updating stale acceptance criteria, resolving release/API decisions and scheduling existing issues rather than adding duplicate tasks. No GitHub issue/milestone/PR metadata, runtime source, tests or configuration was changed. No commit, push, merge or publication was performed.

No public behavior, usage or workflow was changed, so no README/API documentation update is required in this reporting task. The report identifies documentation changes for subsequent implementation work.

## Investigation and validation

- Verified PR #94 merged into dev as `36077b507284ce9b75f8b9076086e490f452d997`; the previous local head had the same tree before creating the review branch.
- Read all issue/milestone descriptions and PR history; cross-checked actual issue states/milestone assignments using a fresh REST listing: 54 issues, 12 open, 42 closed. Counts exclude pull requests.
- Inspected current signature/reference/property/certificate APIs, public docs, tests, workflow and task/implementation notes. This worktree has no `.codegraph` directory; CodeGraph was therefore skipped as instructed.
- Verified the existing post-merge CI run: all six OTP 26/27/28 Ubuntu/Windows jobs succeeded on the merged revision. This is existing CI evidence, not a newly executed local gate.
- Verified default main/dev divergence read-only: dev has 103 unique commits; main has five.
- Consulted official Hex/Rebar3 publishing guidance to check the xmlan dependency prerequisite and the nonpublishing package-build command.
- Document validation: PASS. Checked all 54 unique issue rows against current states/assignments, all six milestone links, all nine local task-note entries, source-link targets/line bounds, Markdown whitespace/fences, and unchanged tracked files. The local HEAD is the reviewed merge revision.

EUnit, Common Test, coverage, flint, Dialyzer and native tall were not rerun: this is a review/report-only task with no runtime/configuration changes and no commit/push. The earlier ECDSA runtime reproduction was not repeated. No skipped required gate is represented as a pass.

## Persistent work and recovery

- Persistent worktree: `/Users/milanbor/.codex/worktrees/signerl-issue-56/signerl`.
- Local review branch: `codex/roadmap-review-2026-10-17`, based on merged dev.
- Read-only GitHub snapshots: `/Users/milanbor/projects/signerl/.recovery/roadmap-review-2026-10-17/`.
- Recovery copies of both untracked review documents and tracked diff/status: `/Users/milanbor/projects/signerl/.recovery/roadmap-review-2026-10-17/documents/`.

The existing original checkout and its unfinished changes were left intact. Recommendations remain unapplied pending the maintainer's direction.
