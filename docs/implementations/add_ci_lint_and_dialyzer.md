# Implementation Log: add_ci_lint_and_dialyzer

## Linked Task Spec
- `docs/tasks/add_ci_lint_and_dialyzer.md`

## What Changed
- Updated `.github/workflows/erlang.yml`:
  - added lint step: `rebar3 lint`
  - added static analysis step: `rebar3 dialyzer`
  - kept existing test step: `rebar3 test`

## Why This Solves The Task
- CI now enforces lint and dialyzer checks in GitHub Actions in addition to tests.
- Lint uses `rebar3 lint` (lint-only) rather than `rebar3 flint` (`fmt + lint`), so CI does not run formatting checks.
- Any lint or dialyzer failure will fail the workflow job.

## Validation Run
- `rebar3 eunit`
  - pass (`10 tests, 0 failures`)
- `rebar3 as test ct`
  - pass (`signerl_SUITE`, all 21 tests passed)
- `rebar3 lint`
  - pass
- `rebar3 flint`
  - pass
- `rebar3 dialyzer`
  - pass
- `rebar3 as test eunit && rebar3 as test ct && rebar3 as test cover`
  - pass (`100%` total coverage; all modules at `100%`)

## Notes
- `rebar3 ct` (default profile) reported missing module/debug-info in this environment; `rebar3 as test ct` passed and is the relevant profile for coverage and CT flow.
- `rebar3` commands continue to print an existing environment warning about `rebar3_run` NIF linking on arm64; it did not block task validation.
