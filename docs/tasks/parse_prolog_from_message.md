# Task: parse_prolog_from_message

## 1. Goal
Parse XML prolog from the input message itself (when valid), instead of using a static prolog.

## 2. Scope
- In scope: parse and validate XML prolog from input content for both binary and filepath inputs.
- Out of scope: unrelated XML parsing behavior, signature algorithm changes, and non-prolog transformation logic.

## 3. Constraints
- Keep changes focused on prolog extraction/validation and call sites that currently inject/use static prolog.
- Keep API shape stable where possible, except the explicitly defined error behavior in this task.
- Keep implementation simple; do not add broad refactors.

## 4. Acceptance Criteria
1. Static prolog usage is removed from the signing flow.
2. When input contains a valid XML prolog, signed output contains the same prolog.
3. When input has no prolog, return `{error, invalid_prolog}`.
4. When input has an invalid prolog, return `{error, invalid_prolog}`.
5. Behavior works for both binary and filepath inputs.
6. Tests pass: `rebar3 eunit` and `rebar3 ct` (if affected suites require it).
7. Lint/quality check passes: `rebar3 flint`.
8. Static analysis passes: `rebar3 dialyzer`.

## 5. Iteration Plan
### Iteration 1
- Add tests first (red phase):
  - fixture with valid prolog + body
  - tests in `test/signerl_SUITE.erl` (or relevant suite/module)
  - binary input and filepath input coverage
  - assertions for preserved input prolog in output
  - assertions for `{error, invalid_prolog}` on missing prolog

### Iteration 2
- Implement parsing logic:
  - remove static prolog behavior
  - add prolog parser function in `src/signerl_xml.erl`
  - use parser in `signerl:sign` and `signerl:verify` paths as applicable
  - keep existing non-prolog API behavior unchanged

### Iteration 3
- Harden validation + tests (green/refine phase):
  - validate parsed prolog format (simple and explicit checks)
  - ensure parser extracts only prolog, not body content
  - add invalid examples (typos, malformed attributes, malformed declaration)
  - ensure missing and invalid prolog both return `{error, invalid_prolog}`

## 6. Risks and Edge Cases
- Whitespace/newline before prolog.
- Single vs double quotes in attributes.
- Prolog-like text that is malformed.
- Inputs that previously succeeded with static prolog may now return `{error, invalid_prolog}`.

## 7. Open Questions
- Resolved: `verify` must enforce prolog in exactly the same way as `sign`.
- Resolved: UTF-8 BOM before prolog is rejected for now and treated as `{error, invalid_prolog}`.

## 8. Done Definition
- [ ] Tests updated and passing
- [ ] New logic is covered by targeted positive/negative tests
- [ ] Docs updated (if behavior changed)
