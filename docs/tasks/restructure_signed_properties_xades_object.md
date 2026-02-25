# Task: restructure_signed_properties_xades_object

## 1. Goal
Move signed properties from the current internal placement to the XAdES-style XML structure under `ds:Object`, while explicitly deferring `ds:SignedInfo`/reference work.

## 2. Scope
- In scope:
  - Change signature XML shape to:
    - `ds:Signature`
      - `ds:SignatureValue`
      - `ds:Object`
        - `xades:QualifyingProperties`
          - `xades:SignedProperties`
            - `xades:SignedSignatureProperties`
              - `xades:SigningTime`
  - Update signature-building code to produce this structure.
  - Update verification parsing code to extract/validate signing time from this structure.
  - Keep strict UTC signing time validation (`YYYY-MM-DDThh:mm:ssZ`).
  - Update tests/fixtures/docs to new XML shape.
- Out of scope:
  - `ds:SignedInfo`
  - `ds:Reference` to signed properties
  - canonicalization (C14N)
  - external XAdES interoperability guarantees

## 3. Constraints
- Keep current public API unchanged:
  - `sign/3`
  - `verify/3`
- Keep current behavior contracts:
  - malformed signature/properties -> `{error, invalid_signature}`
  - cryptographic mismatch -> `false`
- No backward compatibility required for older message shape.

## 4. Target XML Example (Conceptual)
```xml
<ds:Signature>
  <ds:SignatureValue>...</ds:SignatureValue>
  <ds:Object>
    <xades:QualifyingProperties>
      <xades:SignedProperties>
        <xades:SignedSignatureProperties>
          <xades:SigningTime>2026-01-01T00:00:00Z</xades:SigningTime>
        </xades:SignedSignatureProperties>
      </xades:SignedProperties>
    </xades:QualifyingProperties>
  </ds:Object>
</ds:Signature>
```

## 5. Implementation Plan
1. Update signature constructor in `src/signerl_signature.erl`:
   - build `ds:Object` + `xades:QualifyingProperties` wrapper.
2. Update parser/validator in `src/signerl_verify.erl`:
   - navigate through `ds:Object` and `xades:QualifyingProperties` before reading `xades:SignedProperties`.
3. Keep signing payload binding logic unchanged for now:
   - same internal deterministic payload method used in current profile.
4. Update fixtures under `test/examples/` to new structure.
5. Update CT tests in `test/signerl_SUITE.erl`:
   - positive shape checks
   - missing wrapper element checks (`ds:Object`, `xades:QualifyingProperties`, etc.).
6. Update docs/examples:
   - `docs/examples/signed_message_with_signed_properties.xml`
   - `README.md` if output structure text references old placement
   - implementation log under `docs/implementations/`.

## 6. Validation
- Required checks:
  - `rebar3 eunit`
  - `rebar3 ct`
  - `rebar3 as test cover` (100%)
  - `rebar3 flint`
  - `rebar3 dialyzer`
  - `make ci-local`

## 7. Acceptance Criteria
- Signed message contains signed properties only under:
  - `ds:Object/xades:QualifyingProperties/xades:SignedProperties`
- Verify successfully reads signing time from new structure.
- Verify returns `{error, invalid_signature}` for malformed/missing wrapper hierarchy.
- Existing sign/verify API remains unchanged.
- All quality gates pass, including Docker OTP matrix.

## 8. Follow-up (After This Task)
- Separate task for `ds:SignedInfo` + `ds:Reference` + C14N integration.
