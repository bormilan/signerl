# Implementation: add_signed_info

## What Changed
- Added XMLDSig constants in `include/signerl_dsig.hrl` for:
  - canonicalization/signature/digest/reference URIs
  - fixed IDs (`Signature-1`, `SignedProperties-1`)
- Extended `src/signerl_xml.erl` with `export_fragment/1` to serialize deterministic XML fragments without prolog.
- Refactored `src/signerl_signature.erl`:
  - added `build_signature_element/4`
  - `sign/3` now builds `ds:SignedInfo` with two references:
    - document reference (`URI=""`)
    - signed-properties reference (`URI="#SignedProperties-1"`, XAdES `Type`)
  - `ds:SignatureValue` now signs deterministic `ds:SignedInfo` bytes
  - kept `add_signature_element/2,3` for low-level tests
- Refactored `src/signerl_verify.erl`:
  - added `extract_signature_data/1` (structured extraction for verify pipeline)
  - added `verify_reference_digests/2`
  - verify path now validates reference digests before crypto signature verification
  - kept `extract_signature/1` and legacy fallback for existing helper-level tests
- Updated `src/signerl.erl`:
  - `sign/3` now uses `build_signature_element/4`
  - `verify/3` now performs reference digest validation + `SignedInfo` signature validation
- Updated `test/signerl_SUITE.erl`:
  - adjusted existing assertions for new signature shape (`SignedInfo`, attributes)
  - added negative tests for unsupported hash/key and malformed `SignedInfo`/reference structures
  - added explicit coverage for verification error branches
- Updated docs:
  - `README.md` (current SignedInfo behavior and verify order)
  - `docs/signed_properties_scope_and_gaps.md` (SignedInfo now present, C14N still deferred)

## Why This Solves The Task
- The signature now contains a deterministic `ds:SignedInfo` structure and signs it.
- XAdES `SignedProperties` is bound with a dedicated `ds:Reference` and XAdES `Type` URI.
- Verification now follows required order for this profile:
  1. extract and validate signature structure
  2. validate both reference digests
  3. verify `ds:SignatureValue` over deterministic `ds:SignedInfo` bytes
- Canonicalization is explicitly deferred, matching task scope.

## Validation
- `rebar3 test` passed
  - EUnit: `13 tests, 0 failures`
  - CT: `47 tests, 0 failures`
  - Coverage: `100% total`
- `rebar3 flint` passed
- `rebar3 dialyzer` passed

## Notes
- No API change: `sign/3` and `verify/3` signatures remain unchanged.
- External XMLDSig/XAdES interoperability remains deferred until canonicalization is implemented.
