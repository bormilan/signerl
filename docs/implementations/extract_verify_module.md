# Implementation Log: extract_verify_module

## What Changed
- Added new module `src/signerl_verify.erl`.
  - Moved verification-oriented signature extraction logic from `signerl_signature`:
    - `extract_signature/1`
    - `is_signature_element/1`
    - `signature_value/1`
    - `is_signature_value_element/1`
    - `decode_signature_value/1`
    - `decode_signature_value_binary/1`
- Updated `src/signerl_signature.erl` to keep only signature construction concerns:
  - now exports only `add_signature_element/2`
  - keeps `construct_signature/1` as internal helper
- Updated verification call site in `src/signerl.erl`:
  - `signerl_signature:extract_signature/1` -> `signerl_verify:extract_signature/1`
- Updated suite tests in `test/signerl_SUITE.erl`:
  - direct extraction assertions now call `signerl_verify:extract_signature/1`

## Why This Solves The Task
- The verification/parsing behavior is now isolated in a dedicated module (`signerl_verify`), while `signerl_signature` is focused on constructing signature XML.
- This matches the requested scope: move extraction and non-signature-construction logic out of `signerl_signature`.
- Behavior and error contract were preserved:
  - invalid signature structure/value handling still returns `{error, invalid_signature}`
  - verify pipeline in `signerl:verify/3` remains functionally unchanged.

## Validation Run
- `rebar3 eunit` -> pass
- `rebar3 ct` -> pass
- `rebar3 as test cover` -> pass (`100%` total coverage)
- `rebar3 flint` -> pass
- `rebar3 dialyzer` -> pass
- `make ci-local` (OTP 26, 27, 28) -> pass

## Documentation Updates
- Added this implementation log.
- No README or usage docs changes were required, because public API and user-facing behavior did not change.
