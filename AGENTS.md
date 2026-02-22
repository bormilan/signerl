# AGENTS.md

## Scope
Applies to the entire repository unless a nested `AGENTS.md` overrides it.

## Project Goals
- Keep XML signing behavior deterministic and easy to verify.
- Prefer small, focused changes with test coverage for behavior changes.

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
- If coverage drops below `100%`, add or update tests until it is restored and document the result.
- If `rebar3 flint` reports issues, fix them and rerun until clean; if any issue is intentionally deferred, document the reason explicitly.
- If `rebar3 dialyzer` reports issues, fix them and rerun until clean; if any issue is intentionally deferred, document the reason explicitly.
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
