# Task: refactor_signed_properties_verification

## 1. Goal
Refactor signed-properties verification from single-field parsing (`xades:SigningTime`) to a general element-driven verification flow, so new signed properties can be added without rewriting traversal logic.

## 2. Scope
- In scope:
  - Replace direct `SigningTime` extraction logic with a generic verifier for all children under `xades:SignedSignatureProperties`.
  - Verify each recognized property via dedicated validator functions.
  - Keep current strict validation for `xades:SigningTime` (UTC format).
  - Fail verification when required property is missing or invalid.
  - Keep output/error contract unchanged (`{error, invalid_signature}` for malformed/invalid signed properties).
- Out of scope:
  - `ds:SignedInfo` / `ds:Reference` validation
  - canonicalization (C14N)
  - cross-signature profile interoperability work

## 3. Constraints
- Keep public API unchanged:
  - `sign/3`
  - `verify/3`
- Preserve behavior contracts:
  - malformed structure or invalid property value -> `{error, invalid_signature}`
  - crypto mismatch -> `false`
- Keep deterministic signing payload logic unchanged for now.

## 4. Refactor Direction
- Introduce a general pipeline in `src/signerl_verify.erl`:
  1. locate `xades:SignedSignatureProperties`
  2. iterate over all child elements
  3. dispatch recognized elements to validators
  4. aggregate validated values into a map/record
  5. enforce required set (currently only `xades:SigningTime`)
- Keep XML traversal in `signerl_xml` helpers (`find_path/2` etc.); avoid reintroducing nested manual scans.
- Create explicit validator function stubs for all properties we accept in this profile, so each property has a fixed place for future logic.

## 5. Implementation Plan
1. Add `extract_signed_properties/1` in `src/signerl_verify.erl` that returns validated properties (e.g. map with `signing_time`).
2. Implement property dispatcher:
   - `validate_signed_property(Element, Acc)`
   - route by element tag (`xades:SigningTime`, future tags).
3. Add validator function slots for all valid signed properties we want to support in this profile:
   - `validate_signing_time/1` (real validation now)
   - `validate_signing_certificate/1` (placeholder now)
   - `validate_signature_policy_identifier/1` (placeholder now)
   - `validate_signature_production_place/1` (placeholder now)
   - `validate_signer_role/1` (placeholder now)
   - placeholder behavior for now: return positive result (`{ok, Value}` or `ok`) without strict checks.
4. Move current signing-time parsing into `validate_signing_time/1`.
5. Update verification flow:
   - `extract_signature_and_signing_time/1` should use the generic properties extractor and read signing time from the validated result.
6. Ensure unrecognized properties policy is explicit:
   - initial recommendation: ignore unknown properties unless duplicate known property or malformed known property appears.
7. Update CT tests in `test/signerl_SUITE.erl`:
   - existing signing-time tests continue to pass.
   - add tests for generic flow behavior:
     - extra unknown property does not break verification.
     - duplicate `xades:SigningTime` fails.
     - malformed known property fails.
8. Update docs:
   - add implementation log in `docs/implementations/`.
   - update `docs/signed_properties_scope_and_gaps.md` with the new verification model.

## 6. Validation
- Required checks:
  - `rebar3 eunit`
  - `rebar3 ct`
  - `rebar3 as test cover` (100%)
  - `rebar3 flint`
  - `rebar3 dialyzer`
  - `make ci-local`

## 7. Acceptance Criteria
- Verifier no longer hardcodes a single-property traversal path beyond locating `SignedSignatureProperties`.
- `xades:SigningTime` validation remains strict and required.
- Validator function placeholders exist for all currently accepted signed properties, and return positive results until real validation is added.
- Framework exists to add new signed properties by adding validator functions only.
- Current sign/verify behavior remains compatible with current message shape.
- All quality gates pass.

## 8. Follow-up
- Add next signed properties using the new validator pipeline.
- Later task: bind verified signed properties with `SignedInfo` references and canonicalization.
