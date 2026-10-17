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
is implemented; it is no longer a missing prerequisite.

The public interfaces are `sign/3`, `sign/4`, `sign/5` and `verify/3`. `sign/5`
allows controlled UTC time; other signing arities use the current UTC time.
Certificate-less signing remains supported and still includes SignedProperties
and SigningTime. The [API contract](api_contract.md) records malformed-input and
return/raise behavior; [#59](https://github.com/bormilan/signerl/issues/59) remains
open for final alignment after correctness/ownership work.

The property readers perform the following extraction/checks. Extraction alone
does not imply semantic validation, complete cardinality enforcement or trust.

| Property | Current boundary |
| --- | --- |
| SigningTime | Required; validates UTC format and real calendar dates, completed in #56. |
| SigningCertificate | Presence marker; not a full certificate-property validator. |
| SigningCertificateV2 | Extracts certificate digest and optional issuer metadata; full malformed/missing metadata and certificate/key binding remain #54. |
| SignaturePolicyIdentifier | Reads implied or explicit policy identifier/digest data; does not establish that policy material matches the declared digest. |
| SignatureProductionPlace | Extracts recognized text fields; malformed/duplicate field treatment needs #55. |
| SignerRole | Extracts claimed/certified role text; does not prove certified-role validity. |
| DataObjectFormat | Requires ObjectReference during extraction and reads optional text; reference/MIME semantics remain #37. |
| CommitmentTypeIndication | Extracts identifier and supported scope/reference text; semantic validation remains #37. |

PR #48 supplied structural readers/validators for optional properties. They are
not unconditional placeholders, and their presence does not establish that all
XAdES properties are structurally or semantically validated.

## Remaining ownership

- [#52](https://github.com/bormilan/signerl/issues/52): exact references, unique
  actual IDs/targets, declared method/key agreement, signature placement/count,
  explicit reference transforms and legacy compatibility. SignedInfo
  canonicalization and reference transform processing are separate concerns.
- [#54](https://github.com/bormilan/signerl/issues/54): distinguish absent,
  malformed and valid certificate metadata and enforce the chosen binding
  contract. Successful signature verification does not establish certificate
  chain trust, validity periods or revocation status.
- [#55](https://github.com/bormilan/signerl/issues/55): reject ambiguous or
  malformed known containers/fields, including optional-container lookup errors
  that currently become absence. Decide unknown-extension handling separately.
- [#37](https://github.com/bormilan/signerl/issues/37): optional policy-material,
  role-certification and URI/MIME/referenced-object semantic extensions are
  deferred beyond 1.0. The MVP promises structural handling, with #55 responsible
  for rejecting malformed known fields and ambiguous containers. Extraction is
  not semantic validation; unknown extensions may be ignored semantically.
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
