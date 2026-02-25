# Task: extract_verify_module

## Goal
- Separate verification-oriented XML/signature parsing logic from signature-construction logic.
- Keep `signerl_signature` focused on building signature XML elements.
- Introduce a dedicated verification module for extracting and validating signature bytes from a signed message structure.

## Scope
- In scope:
  - Move `extract_signature/1` from `src/signerl_signature.erl` to a new module (proposed: `src/signerl_verify.erl`).
  - Move all helper functions used only for verification/parsing from `src/signerl_signature.erl` to the new module.
  - Update call sites (notably `src/signerl.erl`) to use the new module.
  - Update tests that directly call `signerl_signature:extract_signature/1`.
  - Keep current behavior and error contract unchanged (`{error, invalid_signature}` for invalid signature XML/value cases).
- Out of scope:
  - Changing sign/verify public API.
  - Changing signature XML format.
  - Changing verification semantics or error values.

## Functions To Move
- Public:
  - `extract_signature/1`
- Private helpers tied to extraction/parsing:
  - `is_signature_element/1`
  - `signature_value/1`
  - `is_signature_value_element/1`
  - `decode_signature_value/1`
  - `decode_signature_value_binary/1`

## Functions To Keep In `signerl_signature`
- Public:
  - `add_signature_element/2`
- Private:
  - `construct_signature/1` (used only by signature construction path)

## Proposed Module Design
- New module: `src/signerl_verify.erl`
- Exports:
  - `extract_signature/1`
- Responsibilities:
  - Locate exactly one `ds:Signature` element.
  - Extract exactly one `ds:SignatureValue`.
  - Decode Base64 signature bytes.
  - Return unsigned message tree without `ds:Signature`.

## Implementation Steps
1. Create `src/signerl_verify.erl` with moved `extract_signature/1` and helper functions/specs.
2. Remove moved functions from `src/signerl_signature.erl`.
3. Update `src/signerl.erl`:
   - Replace `signerl_signature:extract_signature(ParsedMessage)` with `signerl_verify:extract_signature(ParsedMessage)`.
4. Update tests in `test/signerl_SUITE.erl`:
   - Replace direct calls to `signerl_signature:extract_signature/1` with `signerl_verify:extract_signature/1`.
5. Ensure no stale references remain (`rg "signerl_signature:extract_signature"`).
6. Run full validation suite.

## Validation
- Required checks:
  - `rebar3 eunit`
  - `rebar3 ct`
  - `rebar3 as test cover` (coverage remains 100%)
  - `rebar3 flint`
  - `rebar3 dialyzer`
  - `make ci-local`
- Expected result:
  - No behavior regression in sign/verify tests.
  - Same invalid-signature handling as before.

## Acceptance Criteria
- Verification extraction code is no longer in `src/signerl_signature.erl`.
- `src/signerl_signature.erl` contains only signature construction concerns.
- Verification flow in `src/signerl.erl` compiles and behaves unchanged.
- All checks pass, including Docker OTP matrix.
