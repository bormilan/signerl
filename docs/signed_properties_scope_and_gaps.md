# Signed Properties: Scope And Remaining Gaps

## What This Iteration Adds
- `xades:SignedProperties` under `ds:Signature/ds:Object/xades:QualifyingProperties`.
- Signed property set:
  - `xades:SignedSignatureProperties/xades:SigningTime` — strict UTC format
  - `xades:SignedSignatureProperties/xades:SigningCertificate` — presence marker
  - `xades:SignedSignatureProperties/xades:SigningCertificateV2` — full digest + optional issuer serial
  - `xades:SignedSignatureProperties/xades:SignaturePolicyIdentifier` — implied or explicit (URI + digest + optional description)
  - `xades:SignedSignatureProperties/xades:SignatureProductionPlace` — optional City, StateOrProvince, PostalCode, CountryName
  - `xades:SignedSignatureProperties/xades:SignerRole` — ClaimedRoles and/or CertifiedRoles
  - `xades:SignedDataObjectProperties/xades:DataObjectFormat` — ObjectReference + optional MimeType/Description/Encoding
  - `xades:SignedDataObjectProperties/xades:CommitmentTypeIndication` — Identifier + optional scope
- Generic signed-properties verification flow:
  - parse all elements under `xades:SignedSignatureProperties`
  - dispatch each element to property validators
  - parse all elements under `xades:SignedDataObjectProperties` (optional)
  - enforce required properties from aggregated validated values
- Verification expects signed properties to exist (no legacy mode).

## What Stays The Same
- Public API shape can stay the same:
  - `sign/3`
  - `verify/3`
- High-level usage stays the same:
  - sign message -> verify signed message.

## What Changes
- Signed XML output shape changes:
  - `ds:Signature` now includes signed-properties subtree.
- Verification rules become stricter:
  - messages without signed properties are rejected.
- Signature validation now covers signed-properties integrity via `ds:Reference` digest checks in the project-local deterministic profile.

## What Is Still Missing (After This Iteration)
- XML canonicalization (C14N/C14N11/Exclusive C14N).
- Standards-aligned XMLDSig processing over canonicalized bytes (current `SignedInfo`/`Reference` flow is deterministic internal profile only).
- Standards-complete XAdES profile behavior (for external validators).
- Backward compatibility mode for previously signed messages without signed properties.

## Practical Consequence
- This iteration gives internal deterministic signed-properties support with `SignedInfo` + reference digest validation.
- All XAdES v1.3.2 signed properties (signature and data-object level) are structurally validated.
- It does **not** yet guarantee interoperability with third-party XMLDSig/XAdES validators until canonicalization is added.
