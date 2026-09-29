# AGENTS.md

## Scope
Applies to the entire repository unless a nested `AGENTS.md` overrides it.

## Project Goals
- Keep XML signing behavior deterministic and easy to verify.
- Prefer small, focused changes with test coverage for behavior changes.

## CodeGraph
- When `.codegraph/` exists at the repository root, consult `codegraph_explore` or `codegraph explore` before searching or reading code to understand or locate it. Name the relevant files or symbols in the query. Use `rg` or direct reads when the index does not cover the needed content.
- When `.codegraph/` does not exist, skip CodeGraph; do not create an index without the user's request.

## Required Issue Workflow
1. Investigate the issue, acceptance criteria, relevant code, callers, and existing tests before editing the implementation.
2. Add focused validation tests first. Test observable logic and meaningful failure cases, not merely line coverage. Reproduce the defect or missing behavior when practical; for tooling/CI changes, use an executable command or failure probe that exercises the gate. Documentation-only changes need appropriate document validation rather than artificial code tests.
3. Implement the smallest focused solution. Run the targeted tests and iterate until they pass.
4. Review the solution for correctness, regressions, missing cases, and opportunities to simplify control flow, ownership, or unnecessary abstraction. Fix actionable findings. After any implementation change during review, rerun the affected tests and iterate until they pass before moving on.
5. Run the complete test suite. If total coverage is below 100%, add meaningful missing tests and repeat until all tests pass and coverage is 100%; do not weaken assertions or add contrived tests solely to execute lines.
6. Run `rebar3 flint` and fix lint/format findings. Rerun affected tests after implementation changes.
7. Run `rebar3 dialyzer` and fix its findings. Rerun affected tests and earlier gates after changes that can invalidate their results.
8. Run `rebar3 tall` on the final implementation as the mandatory aggregate gate. It must include all tests, 100% coverage, formatting/lint checks, and Dialyzer. A failed or skipped required check is not a pass. Also run the required local Docker matrix before commit/push.
9. Only after the required gates pass, create a focused commit with a clear message, push the branch, and open a ready-for-review PR targeting `dev`. Use one PR per issue. Include the problem, resulting behavior, issue link, validation results, and any material limitations in the PR description. Do not merge the PR automatically.

If a required gate is unavailable, continue independent work, record the exact blocker, and ask the user how to resolve it. Do not push while claiming an unavailable gate passed. These workflow and PR defaults persist across tasks unless the user changes them.

## Coding Rules
- Prefer `rg` for file/text search.
- Keep Erlang functions focused and avoid unnecessary nesting.
- Preserve existing module/function naming patterns unless there is a strong reason to change.
- When switching to a new branch with local uncommitted changes, stash first (`git stash -u`), switch branch, then restore (`git stash pop`) to avoid carrying accidental branch state.
- Put static/long constants (for example validation regex patterns) into named macros in a shared `.hrl` file instead of inline literals.
- Do not manually edit generated artifacts under `_build/`.
- Keep docs in sync when public behavior changes.

## Testing Rules
- Run `rebar3 eunit` for unit-level changes.
- Run `rebar3 ct` for integration/contract changes.
- Run `rebar3 as test cover` and keep total coverage at `100%`.
- Run `rebar3 flint` after task implementation is complete (final quality gate).
- Run `rebar3 dialyzer` after task implementation is complete (final quality gate).
- Run `make ci-local` once before commit/push to validate `tall` across the Linux OTP matrix in Docker.
- If coverage drops below `100%`, add or update tests until it is restored and document the result.
- If `rebar3 flint` reports issues, fix them and rerun until clean. Document blockers; do not treat a deferred finding as a passing push gate.
- If `rebar3 dialyzer` reports issues, fix them and rerun until clean. Document blockers; do not treat a deferred finding as a passing push gate.
- If tests are skipped, explicitly state what was not run and why.

## Documentation Rules
- For every non-trivial task, write or update an implementation log in `docs/implementations/`.
- The implementation log must include:
  - what changed (files and behavior)
  - why the change solves the task (reasoning tied to acceptance criteria)
  - what validation was run (tests/commands and outcome)
- If public behavior, usage, or workflows change, update the relevant docs in the same task (for example `README.md`, `test/TESTS.md`, or module docs under `docs/`).
- If no documentation update is required, state that explicitly in the implementation log with a short reason.

## Review Expectations
- Prioritize behavioral correctness and regression risk.
- Call out edge cases (encoding, prolog handling, namespace normalization, canonicalization order).
- Include file references for significant changes.

## Skills
- `xml-debugger`: `.codex/skills/xml-debugger/SKILL.md`
- `ferike`: `.codex/skills/ferike/SKILL.md`
