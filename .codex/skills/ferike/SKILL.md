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
- Structural smells that hide intent:
  - pass-through wrappers that add no behavior (for example `f(X) -> g(X).`) and should be inlined/removed.
  - unnecessary local rebinding of already matched values where function-head pattern matching is clearer
    (for example `f({'tag', _, _} = E) -> ...` instead of rebuilding/reassigning the same term).
  - map-access patterns that could be clearer in function-head matching:
    if a function receives a map and immediately does `maps:get/2` or `maps:find/2` for top-level keys,
    suggest head matching (for example `f(#{key := Value} = Map) -> ...`) when it improves readability.
    Do not force this for deep/nested keys where explicit `maps:*` access is clearer.
  - module flow/order smells:
    when a module has a clear main flow, check whether functions are ordered top-down
    (public entrypoints first, then immediate helpers, then lower-level/private helpers).
    Flag heavily interleaved ordering that makes control flow hard to follow.
  - placement/layering smells:
    spot functions that likely belong in another module by responsibility.
    Examples:
    - generic reusable helpers that should live in `*_utils`
    - orchestration/business-flow logic that should move up to a higher-level module
    - domain-specific logic incorrectly sitting in a generic utility module.
    Suggest concrete target module(s) and why.

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
6. Include a small "simplification candidates" section for non-blocking cleanups:
   - function-head pattern matching opportunities.
   - no-op wrapper function removal opportunities.
   - map head-pattern opportunities for shallow key extraction from function parameters.
   - top-down function ordering opportunities for clearer module flow.
   - function placement opportunities (move to utils vs move to upper-level orchestration module).

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
