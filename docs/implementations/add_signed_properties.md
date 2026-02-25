# Implementation Log: add_signed_properties

## Linked Task
- `docs/tasks/add_signed_properties.md`

## What Changed
- `src/signerl_signature.erl`
  - extended signature construction to include:
    - `ds:SignatureValue`
    - `xades:SignedProperties/xades:SignedSignatureProperties/xades:SigningTime`
  - added `add_signature_element/3` and kept `add_signature_element/2` as convenience with default signing time.

- `src/signerl_verify.erl`
  - added `extract_signature_and_signing_time/1` for verification flow.
  - kept `extract_signature/1` (returns signature + unsigned message only).
  - added parsing/validation for signed-properties subtree.
  - added strict UTC validation for `SigningTime` (`YYYY-MM-DDThh:mm:ssZ`).

- `src/signerl.erl`
  - sign flow now signs deterministic payload:
    - `MessageWithoutSignature` bytes + newline + `SigningTime`
  - verify flow now extracts `SigningTime` and verifies same deterministic payload.
  - no API change (`sign/3`, `verify/3` unchanged).

- `test/signerl_SUITE.erl`
  - updated signature-construction assertions for signed-properties presence.
  - added new negative tests for missing/malformed signed-properties:
    - missing signed properties
    - missing signed-signature-properties
    - missing signing time
    - invalid signing time format
    - self-closing signing time
  - added integrity test for modified `SigningTime`.

- Updated fixtures:
  - `test/examples/signed_properties/books_signature_no_value.xml`
  - `test/examples/signed_properties/books_signature_empty_value.xml`
  - `test/examples/signed_properties/books_signature_invalid_base64.xml`
  - `test/examples/signed_properties/books_signature_self_closing_value.xml`
  - `test/examples/signed_properties/books_signature_wrong_value.xml`
  - added:
    - `test/examples/signed_properties/books_signature_missing_signed_properties.xml`
    - `test/examples/signed_properties/books_signature_missing_signed_signature_properties.xml`
    - `test/examples/signed_properties/books_signature_missing_signing_time.xml`
    - `test/examples/signed_properties/books_signature_invalid_signing_time.xml`
    - `test/examples/signed_properties/books_signature_self_closing_signing_time.xml`

- Documentation:
  - `README.md` updated with signed-properties output shape and strict UTC note.
  - `test/TESTS.md` updated with new signed-properties tests.
  - Added:
    - `docs/tasks/add_signed_properties.md`
    - `docs/signed_properties_scope_and_gaps.md`
    - `docs/examples/signed_message_with_signed_properties.xml`

## Why This Solves The Task
- Signed messages now include signed properties (`SigningTime`) as requested.
- Signature verification now requires and validates signed properties (no legacy-without-properties mode).
- `SigningTime` is strict UTC format only.
- Property integrity is cryptographically bound in the current internal deterministic profile by including signing time in the signed payload reconstruction.

## Validation Run
- `rebar3 test` -> pass
- `rebar3 as test cover` -> pass (100% total)
- `rebar3 flint` -> pass
- `rebar3 dialyzer` -> pass
- `make ci-local` (OTP 26/27/28) -> pass

## Notes
- This iteration intentionally does not implement XML canonicalization/C14N interoperability semantics yet.
- External XMLDSig/XAdES validator interoperability remains a follow-up task.
