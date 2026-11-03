# Signed properties: current scope and remaining work

The selected 1.0 target is [enveloped RSA-SHA256 with XAdES](signing_profile.md).
XAdES SignedProperties, SigningTime and optional certificate properties stay.
Profile definition in [#64](https://github.com/bormilan/signerl/issues/64) is
complete; the remaining implementation is tracked in 0.3. This document describes
the current implementation boundary, not full XAdES conformance.

## Existing behavior

Signatures contain `ds:Object/xades:QualifyingProperties/xades:SignedProperties`.
`SignedSignatureProperties` includes a required SigningTime; signing with a
certificate also emits SigningCertificateV2 and embedded certificate material.
The document and SignedProperties have reference digests, and the cryptographic
signature covers canonicalized SignedInfo. Generic parsing, namespaces,
serialization and C14N 1.1/Exclusive C14N are provided by xmlan. Canonicalization
is implemented; it is no longer a missing prerequisite. #52 enforces exactly two
references, actual unique IDs/targets, declared methods/key agreement and a
single direct-child signature. New reference chains declare C14N 1.1 explicitly;
the complete legacy pair remains supported. SignedInfo canonicalization remains
separate from reference processing. See the API contract for the exact rules.

The public interfaces are `sign/3`, `sign/4`, `sign/5` and `verify/3`. `sign/5`
allows controlled UTC time; other signing arities use the current UTC time.
Certificate-less signing remains supported and still includes SignedProperties
and SigningTime. The [API contract](api_contract.md) records malformed-input and
return/raise behavior; [#59](https://github.com/bormilan/signerl/issues/59) remains
open for final alignment after correctness/ownership work.

#54 validates the paired certificate metadata and signature/key binding. Successful
verification does not establish certificate-chain trust, validity periods or
revocation status.

The property readers enforce the supported structure below. Extraction alone
does not imply semantic validation, complete XAdES schema validation or trust.

| Property | Current boundary |
| --- | --- |
| SigningTime | Required; validates UTC format and real calendar dates, completed in #56. |
| SigningCertificate | Unique presence marker; its contents are not semantically validated, and alone it cannot satisfy the certificate-bearing profile. |
| SigningCertificateV2 | Requires the embedded certificate/V2 pair, rejects malformed/duplicate fields, checks digest and optional issuer/serial, and binds the certificate key to the signature (#54). Both absent is certificate-less signing. |
| SignaturePolicyIdentifier | Exactly one implied or explicit choice. The explicit form requires unique identifier/digest fields; this does not establish that policy material matches the digest. |
| SignatureProductionPlace | Optional, unique City/StateOrProvince/PostalCode/CountryName text fields; malformed present fields are rejected. |
| SignerRole | Unique ClaimedRoles/CertifiedRoles containers with one or more text-only items when present; at least one kind is required. Does not prove certified-role validity. |
| DataObjectFormat | Repeatable; requires the ObjectReference attribute and checks optional text/ObjectIdentifier fields. The existing ObjectReference-only form is accepted at this structural reader boundary, without claiming full schema validation. Reference/MIME semantics remain #37. |
| CommitmentTypeIndication | Repeatable; requires an identifier and either one empty AllSignedDataObjects marker or one or more text ObjectReference items, never both. Semantic validation remains #37. |

PR #48 supplied structural readers/validators for optional properties; #55
enforces their supported cardinalities and malformed-field handling.
SignedSignatureProperties is required and unique. SignedDataObjectProperties is
optional and unique; duplicate optional containers are errors, not absence.
Recognized singleton properties and fields reject duplicates. Property containers
accept element children and formatting whitespace, not other text. A present
text field must contain text only; malformed optional fields are rejected rather
than dropped.

The shared ObjectIdentifier structure used by policy/commitment identifiers and
optional format metadata requires one Identifier and allows one Description.
Optional DocumentationReferences is unique and requires one or more text
DocumentationReference items. Role items, documentation items, scope references,
DataObjectFormat and CommitmentTypeIndication remain repeatable. Unknown elements
and elements in other namespaces do not count as recognized fields; they are
ignored semantically but remain covered by the signed bytes. These are supported
structural checks, not general XAdES schema or extension validation.

## Remaining ownership

- [#37](https://github.com/bormilan/signerl/issues/37): optional policy-material,
  role-certification and URI/MIME/referenced-object semantic extensions are
  deferred beyond 1.0. The MVP promises the structural handling implemented in
  #55. The legacy SigningCertificate marker remains presence-only under #54;
  this change adds no certificate semantics. Extraction is not semantic
  validation; unknown extensions are ignored semantically.
- [#58](https://github.com/bormilan/signerl/issues/58): simplify signature/XAdES
  ownership after correctness fixes, while preserving the retained properties.
- #59: finish accurate API/capability documentation after implementation.
  [#65](https://github.com/bormilan/signerl/issues/65) owns release acceptance.
  Independent signature interoperability CI is post-1.0
  [#40](https://github.com/bormilan/signerl/issues/40).

Signerl tests its own signature behavior. Generic XML implementation and its
tests remain in xmlan; no XML-only suites or external consumer application are
required here. Internal round trips and coverage do not establish general
XMLDSig/XAdES interoperability.
