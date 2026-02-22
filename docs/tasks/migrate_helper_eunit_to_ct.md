# Task: migrate_helper_eunit_to_ct

## 1. Goal
Replace helper-focused EUnit modules with behavior-driven Common Test coverage, while preserving total coverage at 100% and keeping quality gates green.

## 2. Scope
- In scope: remove helper-focused EUnit tests:
  - `test/signerl_signature_test.erl`
  - `test/signerl_utils_test.erl`
- In scope: add/expand Common Test suites to cover equivalent behavior and edge cases.
- In scope: keep deterministic XML signing/verification behavior and current public API unchanged.
- In scope: update test documentation and implementation log for the migration.
- Out of scope: changes to signing algorithms, canonicalization strategy, or unrelated refactors.

## 3. Constraints
- Prefer real-world XML examples and end-to-end behavior checks over line-targeted micro-tests.
- Keep test modules below lint thresholds (avoid `god_modules` violations).
- Preserve existing naming/style patterns and avoid broad restructuring.

## 4. Acceptance Criteria
1. `test/signerl_signature_test.erl` and `test/signerl_utils_test.erl` are removed.
2. Common Test coverage includes all signature extraction validation paths currently covered by helper EUnit tests:
   - valid extraction
   - missing `ds:Signature`
   - multiple `ds:Signature`
   - missing `ds:SignatureValue`
   - empty `ds:SignatureValue`
   - invalid base64 in `ds:SignatureValue`
   - supported value representation path used by parser/export flow
3. Common Test coverage includes file-based and prolog-validation behavior that covers `signerl_utils` responsibilities in practical API flows.
4. `rebar3 eunit` passes (remaining unit tests, if any).
5. `rebar3 ct` passes.
6. `rebar3 flint` passes.
7. `rebar3 dialyzer` passes.
8. `rebar3 as test cover` reports total coverage `100%`.

## 5. Iteration Plan
### Iteration 1
- Baseline current behavior:
  - run `rebar3 as test cover`
  - note current module-level coverage and helper paths that must be preserved
- Design CT suite layout:
  - keep all behavior tests in `test/signerl_SUITE.erl`
  - do not add new CT suites

### Iteration 2
- Implement CT migration:
  - port helper-EUnit signature cases into `test/signerl_SUITE.erl` using realistic XML flows/fixtures
  - ensure `signerl_utils` responsibilities are covered via public API CT scenarios (file paths + prolog paths)
  - add minimal new fixtures only if needed for malformed signature structures

### Iteration 3
- Remove helper EUnit modules:
  - delete `test/signerl_signature_test.erl`
  - delete `test/signerl_utils_test.erl`
- Update test docs and implementation log
- Run quality gates + coverage and iterate until all criteria pass

## 6. Risks and Edge Cases
- Coverage can regress if private-branch cases are not explicitly represented in CT scenarios.
- CT module-size lint rules may fail if too many cases are added to a single suite; if this happens, merge/compress related cases while preserving behavioral assertions.
- Signature-shape edge cases must remain distinguished from cryptographic mismatch (`{error, invalid_signature}` vs `false`).
- Keep prolog validation behavior unchanged (`{error, invalid_prolog}` where applicable).

## 7. Open Questions
- Should all helper behavior be tested only through public API flows?
  - Proposed: prefer API-level CT coverage first; allow targeted module-level CT cases only for error-branch specificity that cannot be reached cleanly through API paths.

## 8. Done Definition
- [ ] Helper EUnit modules removed
- [ ] Equivalent or better CT behavioral coverage added
- [ ] Total coverage remains 100%
- [ ] All quality gates pass
- [ ] Docs updated (`test/TESTS.md` and implementation log)
