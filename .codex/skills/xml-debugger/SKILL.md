# xml-debugger

Use this skill when debugging XML parsing/signing/canonicalization behavior in this repository.

## When to Use
- Failing tests in `test/signerl_xml_test.erl` or `test/signerl_SUITE.erl`.
- Differences caused by XML prolog/encoding/namespace handling.
- Signature mismatch after transformation or canonicalization.

## Workflow
1. Reproduce the issue with the smallest relevant test (`rebar3 eunit --module=signerl_xml_test` when applicable).
2. Isolate the XML input from `test/examples/` and reduce to a minimal fixture.
3. Compare before/after XML around:
   - prolog presence and encoding
   - namespace declarations and prefixes
   - whitespace and element order in signed regions
4. Confirm whether the issue is parse-time, transform-time, or signature-time.
5. Add/adjust tests first, then patch `src/signerl_xml.erl` (or related module), then rerun tests.

## Guardrails
- Avoid broad refactors while debugging a behavioral defect.
- Preserve public API shape unless task explicitly requests changes.
- Prefer deterministic fixtures over dynamic time/random input.
- Follow repository-wide documentation rules in `AGENTS.md` (including implementation log updates in `docs/implementations/`).
- Move static/long validation literals (for example regex patterns) into named macros in shared `.hrl` files instead of keeping them inline.

## Useful Commands
- `rg "prolog|encoding|namespace|canonical" src test`
- `rebar3 eunit --module=signerl_xml_test`
- `rebar3 ct --suite=test/signerl_SUITE`

## Output Checklist
- Root cause summary in 1-3 lines.
- Exact files changed.
- Tests run and results.
- Any unresolved risk.
