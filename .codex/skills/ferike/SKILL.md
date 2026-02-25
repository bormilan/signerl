# ferike

Use this skill when the user asks for a full post-implementation code review (for example: "ferike", "run ferike", or "review changes").

## Goal
- Review code changes for correctness, regression risk, and missing tests before commit/push.

## What To Review
- Behavioral bugs and edge cases.
- Contract/API regressions.
- Error handling and malformed-input behavior.
- Test coverage gaps for changed logic.
- CI-quality risks (`flint`, `dialyzer`, matrix assumptions).

## Review Workflow
1. Determine review scope:
   - uncommitted diff (`git status`, `git diff`)
   - or branch diff (`git diff <base>...HEAD`) when user specifies a base.
2. Inspect changed files first, then related callers/callees.
3. Prioritize findings by severity:
   - `high`: behavior break, security issue, data loss risk
   - `medium`: likely bug/regression path
   - `low`: maintainability risk or missing guardrails
4. Validate with targeted commands when needed:
   - `rebar3 test`
   - `rebar3 flint`
   - `rebar3 dialyzer`
   - `make ci-local` (before commit/push gate)
5. Report findings with file references and concrete fixes.

## Output Format
- Findings first, ordered by severity.
- Each finding should include:
  - short title
  - why it matters
  - exact file reference(s)
  - suggested fix
- If no findings:
  - state "no blocking findings"
  - list residual risks (if any)
  - list validation run/omitted.

## Guardrails
- Do not rewrite code during review unless user asks to fix items.
- Prefer high-signal findings over style nits.
- Keep review concise but concrete.
