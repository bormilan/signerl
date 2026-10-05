# OTP 28 development toolchain and GitHub compatibility matrix (#62)

## Scope and version selection

Primary runtime: OTP 28.5.0.7; build tool: rebar3 3.25.1. The OTP patch is the
latest stable OTP 28 release verified in the official release list on 2026-10-05.
The Windows x64 installer and setup-beam Ubuntu 24.04 build were verified.
rebar3 3.25.1 supports OTP 26–28 and includes OTP 28 Windows fixes. OTP 26/27
remain compatibility targets.

Sources:
- https://github.com/erlang/otp/releases/tag/OTP-28.5.0.7
- https://github.com/erlang/rebar3/releases/tag/3.25.1
- https://github.com/erlang/rebar3#compatibility-between-rebar3-and-erlangotp
- https://github.com/erlef/setup-beam#input-versioning

## Changes and acceptance criteria

- `.tool-versions` pins the primary OTP/rebar3 versions for asdf and CI.
- `.github/workflows/erlang.yml` reads those pins for OTP 28 and all rebar3
  jobs. OTP 28 uses strict selection; OTP 26/27 retain their compatibility
  ranges. All six Ubuntu/Windows jobs remain. Pushes to `dev` now run CI
  alongside `main` and pull requests. Each job reports actual tool versions
  and runs the existing `rebar3 tall` gate after certificate generation.
- At the maintainer's explicit request, remove `scripts/ci_local_docker.sh`,
  `scripts/ci.Dockerfile`, and the Docker-only `Makefile`. Native `tall` is the
  pre-commit/push gate. All six GitHub Actions jobs must pass on the latest PR
  commit before merge, with no skipped cases or failed checks. This replaces
  the former mandatory local Docker matrix in issue #62's acceptance criteria.
- `AGENTS.md`, the ferike review checklist, README, and `test/TESTS.md` describe
  the new workflow. The two original Docker task/implementation records are
  marked historical. README covers pinned installation and native prerequisites.
  Previously requested issue-key/closure and persistent recovery rules are also
  preserved in `AGENTS.md`.
- Production modules, test cases, coverage enforcement, and the `tall` alias
  are unchanged. No runtime or lint compatibility changes were needed locally.
  Linter migration remains #63; cache/formatter reproducibility remains #60.

## Validation

- A focused executable probe was added before removal. It executes CI's actual
  version-reading step, checks the six-job matrix and aggregate command, and
  detects retired Docker assets/commands. It initially failed because the
  Docker runner still existed; the final probe passes. actionlint 1.7.12
  also passes (external shellcheck is unavailable). Relative documentation links
  resolve and `git diff --check` is clean.
- Final native `rebar3 test`, `as test cover`, `flint`, `dialyzer`, and `tall`
  passed: 157 EUnit + 62 CT cases, 100% coverage across all ten modules, with no
  skipped cases or suite-loading failures. Native runtime is installed Homebrew
  OTP 28.4.2 with official rebar3 3.25.1 and an empty task-local global rebar
  config. GitHub Actions supplies exact OTP 28.5.0.7 execution on both platforms.
- Review found no blocking findings. The unchanged production/test tree and
  unchanged coverage/lint/Xref/Dialyzer commands preserve existing checks.
- GitHub matrix results for the pushed commit are recorded in the PR checks and
  validation summary. All six successful jobs are required before merge.
  No Docker matrix pass is claimed. No user-global tool settings were changed.

## Reason for retiring local Docker

Docker image downloads exhausted host storage, and automatic approval review
rejected another matrix attempt because of disk-exhaustion risk. The maintainer
then explicitly approved removing Docker tooling and using native validation
before push plus GitHub Actions before merge. The Docker matrix is therefore
retired, rather than treated as a passing or skipped required check. Existing
images, containers, volumes, and Docker Desktop are outside this repository
change; no further Docker cleanup or restart was performed.

## Persistence

Persistent worktree:
`/Users/milanbor/.codex/worktrees/signerl-issue-62/signerl`.
Recovery diff, untracked-source archive, probes, logs, and the earlier storage
inspection record:
`/Users/milanbor/projects/signerl/.recovery/issue-62`.
