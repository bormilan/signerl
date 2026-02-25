# Task: add_signed_properties

## 1. Goal
Add signed properties support now as an internal deterministic profile, while explicitly deferring canonicalization (C14N) and external XMLDSig/XAdES interoperability to a later task.

## 2. Scope Strategy (No C14N Yet)
- In scope:
  - Introduce `SignedProperties` XML under `ds:Signature`.
  - Ensure properties are cryptographically bound in this project by signing deterministic bytes produced by the current exporter/parsing pipeline.
  - Add verification that fails when signed properties are modified or malformed.
- Out of scope:
  - XML canonicalization (C14N/C14N11/Exclusive C14N).
  - Full XMLDSig `SignedInfo` + `Reference` interoperability behavior.
  - Claiming standards-compliant XAdES output for third-party validators.

## 3. Non-Goal Clarification
- This iteration is **not** standards-complete XAdES.
- It is an internal compatibility profile that prepares the codebase for later C14N-based standards alignment.

## 3.1 Fixed Decisions For This Task
- `xades:SigningTime` format is strict UTC only: `YYYY-MM-DDThh:mm:ssZ`.
- Backward compatibility is not required:
  - messages without signed properties are not supported by the new verification profile.
- Property scope for this iteration is minimal:
  - include only `xades:SigningTime`.

## 4. Proposed XML Shape (Minimal)
Under existing `ds:Signature`, add:
- `xades:SignedProperties`
  - `xades:SignedSignatureProperties`
    - `xades:SigningTime`

Example target shape (conceptual):
- `ds:Signature`
  - `ds:SignatureValue`
  - `xades:SignedProperties`
    - `xades:SignedSignatureProperties`
      - `xades:SigningTime`

## 5. Implementation Plan

### Iteration 1: Build And Embed Signed Properties
1. Add helper(s) to construct `xades:SignedProperties` with required minimal fields.
2. Extend signing flow to include signed-properties subtree in the signed message output.
3. Keep current sign/verify API (`sign/3`, `verify/3`) unchanged.

Acceptance:
- Signed output contains `xades:SignedProperties` and `xades:SigningTime`.

### Iteration 2: Bind Properties To Signature (Internal Deterministic Method)
1. Define deterministic byte construction for verification/signing using current parse/export pipeline.
2. Ensure signature calculation includes signed-properties content (in project-local deterministic form).
3. Update verify flow to reconstruct same deterministic bytes and validate signature.

Acceptance:
- Modifying `xades:SigningTime` invalidates signature (`false` or explicit malformed error per contract).

### Iteration 3: Validation Hardening
1. Add structure validation for signed properties:
   - missing signed properties -> `{error, invalid_signature}`
   - missing signing time -> `{error, invalid_signature}`
   - empty/invalid signing time format -> `{error, invalid_signature}`
2. Keep error semantics consistent with current `invalid_signature` behavior.

Acceptance:
- Negative fixtures for malformed signed-properties structures are covered.

## 6. Test Plan
- Add/extend tests for:
  - signed message includes signed properties and signing time.
  - verify succeeds for valid message.
  - verify fails when signing time is modified.
  - verify errors on missing/malformed signed-properties nodes.
- Keep full behavior test coverage at `100%`.

## 7. Risks
- Without canonicalization, signature validity depends on this project’s deterministic serializer behavior.
- External validators may reject output as non-standard XAdES/XMLDSig.
- Future C14N migration may require XML structure/signing-flow adjustments.

## 8. Follow-up Task (Planned Later)
- Add canonicalization and standards-aligned XMLDSig/XAdES processing:
  - `SignedInfo`
  - `Reference` digest validation
  - XAdES `SignedProperties` reference with correct `Type`
  - interoperability-focused fixtures.

## 9. Closed Decisions
1. Timestamp format strictness:
   - ISO 8601 UTC (`YYYY-MM-DDThh:mm:ssZ`) only.
2. Backward compatibility:
   - verify does not support old messages without signed properties.
3. Property set:
   - `SigningTime` only in this task.

## 10. Done Definition
- [ ] Signed properties subtree added to signed output.
- [ ] Properties are included in project-local deterministic signed bytes.
- [ ] Verification checks properties integrity and structure.
- [ ] Positive/negative tests added and passing.
- [ ] `rebar3 eunit`, `rebar3 ct`, `rebar3 as test cover`, `rebar3 flint`, `rebar3 dialyzer`, `make ci-local` pass.
- [ ] Implementation log added under `docs/implementations/`.
