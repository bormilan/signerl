# Signed Properties: Scope And Remaining Gaps

## What This Iteration Adds
- `xades:SignedProperties` under `ds:Signature/ds:Object/xades:QualifyingProperties`.
- Minimal signed property set:
  - `xades:SignedSignatureProperties/xades:SigningTime`
- Generic signed-properties verification flow:
  - parse all elements under `xades:SignedSignatureProperties`
  - dispatch each element to property validators
  - enforce required properties from aggregated validated values
- Placeholder validator slots for optional signed-signature properties:
  - `SigningCertificate`
  - `SigningCertificateV2`
  - `SignaturePolicyIdentifier`
  - `SignatureProductionPlace`
  - `SignerRole`
- Strict `SigningTime` format:
  - `YYYY-MM-DDThh:mm:ssZ` (UTC only).
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
- Full semantic validation logic for optional signed-signature properties (placeholders currently accept them).
- Additional XAdES properties beyond current signed-signature property slots (for example data object properties, timestamps, long-term validation data).
- Backward compatibility mode for previously signed messages without signed properties.

## Practical Consequence
- This iteration gives internal deterministic signed-properties support with `SignedInfo` + reference digest validation.
- It does **not** yet guarantee interoperability with third-party XMLDSig/XAdES validators until canonicalization is added.
