# Code Review Fixes

## What Changed

### Step 1: HIGH Priority Fixes

**1A. Disambiguate `sign/3` and `verify/3` dispatch** (`src/signerl.erl`)
- Added `is_binary(Message)` / `is_binary(SignedMessage)` guards on core clauses to make dispatch unambiguous between file-path and binary overloads.

**1B. Specific error types** (`src/signerl_verify.erl`, `src/signerl_signed_properties.erl`, `src/signerl_xades_xml.erl`, `src/signerl_xml.erl`, `src/signerl_signature.erl`)
- Replaced all `{error, invalid_signature}` returns with specific atoms: `missing_signature`, `missing_signature_value`, `missing_signed_info`, `invalid_signed_info`, `invalid_reference`, `unsupported_algorithm`, `invalid_base64`, `missing_attribute`, `invalid_signature_structure`, `missing_element`, `missing_signing_time`, `invalid_signing_time`, `duplicate_property`, `invalid_xml`, `unsupported_hash`, `unsupported_key`, `invalid_pem`, `{file_error, Reason}`.

**1C. Case → function clauses** (`src/signerl_signed_properties.erl`)
- Converted `validate_signed_property/2` from a single case statement to pattern-matched function clause heads. Removed 5 stub `validate_*` functions and changed return value from `valid` to `present`.

**1D. Graceful error handling** (`src/signerl.erl`, `src/signerl_utils.erl`)
- `load_key_from_file` returns `{ok, Key} | {error, Reason}`. Convenience clauses in `sign/3` and `verify/3` use `case` instead of bare `=` matches.

**1E. Pattern matching instead of `lists:nth`** (`src/signerl_signature.erl`)
- `add_signature_value/2` destructures `[SignedInfo, Object]` directly.

### Step 2: MEDIUM Priority Fixes

**2C. Move `attr_value/2` to `signerl_xml`** (`src/signerl_xml.erl`, `src/signerl_verify.erl`)
- Moved `attr_value/2` and `attr_value_or_undefined/2` from `signerl_verify` to `signerl_xml` as general-purpose XML attribute accessors.

**2D. Fix typo** (`src/signerl_xml.erl`)
- Renamed `simplifie_xml_element` → `simplify_xml_element`.

**2E. Document stub validations** (`src/signerl_signed_properties.erl`)
- Added `%% TODO` comments to all 5 structural presence checks.

**2F. Tighten type specs** (`src/signerl.erl`, `src/signerl_signature.erl`, `src/signerl_verify.erl`)
- Added `-spec` for public API `sign/3` and `verify/3`. Defined and exported `hash()` type. Used `signerl_xml:simplified_xml()`, `public_key:private_key()`, `public_key:public_key()` in specs.

**2G. Standardize error conventions** (`src/signerl_xml.erl`, `src/signerl_xades_xml.erl`, `src/signerl_verify.erl`)
- Changed `find_path/2` and `single_text/1` to return `{error, not_found}` instead of bare `error`. Updated all callers.

**2H. Pass original attrs** (`src/signerl_xades_xml.erl`)
- `find_signed_signature_properties` now preserves original `Attrs` instead of replacing with `[]`.

### Blocked

**2A** and **2B** are blocked — they require `signerl_c14n.erl` which is on the `feature/c14n` branch.

## Why

Each fix directly addresses a finding from the Erlang code review:
- Specific errors enable debugging and meaningful error messages for library consumers.
- Guard disambiguation prevents accidental clause matching.
- Function clauses are idiomatic Erlang and more maintainable than case statements.
- Moving utilities to `signerl_xml` reduces coupling and duplication.
- Tighter type specs catch misuse at compile time via Dialyzer.

## Validation

- **eunit:** 13 tests, 0 failures
- **CT:** 67 tests, 0 failures (6 new coverage tests added)
- **Coverage:** 100% across all modules
- **Flint:** clean
- **Dialyzer:** clean

## Documentation

No public-facing documentation changes needed — these are internal refactors. Error atoms are a behavioral change but the library is pre-1.0.
