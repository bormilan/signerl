# Task: add_ci_lint_and_dialyzer

## 1. Goal
Add lint-only (`rebar3 lint`) and static analysis (`rebar3 dialyzer`) checks to the repository's GitHub Actions workflow.

## 2. Scope
- In scope: update `.github/workflows/erlang.yml` so CI runs lint and dialyzer in addition to existing tests.
- In scope: keep current test behavior (`rebar3 test`) and matrix strategy intact unless explicitly changed by this task.
- In scope: ensure failures in lint or dialyzer fail CI.
- Out of scope: unrelated CI refactors, release automation, or non-Erlang workflow changes.

## 3. Constraints
- Keep workflow changes small and readable.
- Preserve existing OTP/OS matrix unless there is a clear runtime/stability reason to scope heavy checks.
- Avoid duplicate work where possible (reuse setup/cache/cert generation steps).

## 4. Acceptance Criteria
1. GitHub Actions workflow includes a lint step that runs `rebar3 lint`.
2. GitHub Actions workflow includes a dialyzer step that runs `rebar3 dialyzer`.
3. CI fails when lint fails.
4. CI fails when dialyzer fails.
5. Existing test command (`rebar3 test`) is still executed.
6. Workflow YAML remains valid and passes a local sanity check (syntax + basic command order review).

## 5. Iteration Plan
### Iteration 1
- Review `.github/workflows/erlang.yml` and decide execution model:
  - Option A: add `lint` and `dialyzer` as steps in existing `ci` job.
  - Option B: split into dedicated jobs (test/lint/dialyzer) with shared setup for clearer status signals.
- Preferred for minimal change: Option A.

### Iteration 2
- Implement workflow changes:
  - keep checkout/setup/cache/cert generation sequence.
  - run commands in deterministic order:
    1. `rebar3 test`
    2. `rebar3 lint`
    3. `rebar3 dialyzer`
- Ensure step names are explicit and easy to identify in GitHub UI.

### Iteration 3
- Validate locally:
  - run `rebar3 test`, `rebar3 lint`, `rebar3 dialyzer`.
  - verify workflow file formatting and syntax.
- Update implementation log under `docs/implementations/` with:
  - files changed
  - rationale
  - validation commands and outcomes.

## 6. Risks and Edge Cases
- `dialyzer` is slower and may increase CI time materially.
- Dialyzer PLT/cache behavior may differ by OS and OTP version; cache misses can cause long first runs.
- Windows runners may be slower/less stable for dialyzer than Linux; if flaky, consider isolating heavy checks to a dedicated Linux job in follow-up.

## 7. Open Questions
- Should lint and dialyzer run on the full matrix or only a single canonical environment (for example Ubuntu + latest OTP) to reduce CI duration?
  - Default for this task: run on existing matrix for strictness.
  - Follow-up option: scope heavy checks to one environment if CI time becomes a problem.

## 8. Done Definition
- [ ] Workflow updated with `lint` and `dialyzer` checks
- [ ] Local validation commands run and recorded
- [ ] Implementation log added/updated in `docs/implementations/`
