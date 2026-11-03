# Public signing and verification contract

This describes the public API and the remaining 0.3 decisions. The
[selected profile](signing_profile.md) separates the implemented signature
reference/identity/algorithm checks (#52) and certificate binding (#54) from
known-property enforcement still tracked in #55.

## Operations and inputs

| Operation | Result and inputs |
| --- | --- |
| `sign(Xml, sha256, Key)` | Signed XML binary; current UTC time, no certificate. |
| `sign(Xml, sha256, Key, CertDer)` | Signed XML binary; current UTC time, optional DER certificate. `undefined` omits it. |
| `sign(Xml, sha256, Key, CertDer, Time)` | Signed XML binary; explicit UTC timestamp binary and optional certificate. |
| `verify(SignedXml, sha256, Key)` | `true`, `false`, or a returned input/structure error, using the caller's key. |

An XML argument is a UTF-8 binary or a filename string. A character list is a
filename, not XML text; a binary is XML, not a filename. A key argument is a
loaded OTP key term or a filename string containing one unencrypted PEM key.
Signing uses an RSA private key. Verification accepts an RSA public key or the
existing RSA private-key convenience, including PEM key paths. Embedded KeyInfo
is not substituted for the caller's verification key.

`sha256` is the supported hash and the only member of `signerl:hash()`. Other
hash atoms return `{error, unsupported_hash}` for otherwise valid inputs in both
operations. Additional algorithms are [#38](https://github.com/bormilan/signerl/issues/38).
The existing ECDSA path remains callable for compatibility and regression tests,
but is excluded from the supported 1.0 XMLDSig profile until the wire-format
bug in [#53](https://github.com/bormilan/signerl/issues/53) is fixed. This pass
adds no ECDSA rejection gate and makes no ECDSA interoperability claim.

Signing requires an XML declaration at the start; verification accepts XML with
or without that declaration. xmlan owns complete-document parsing, encoding,
namespace handling, serialization and canonicalization. Signerl propagates its
public parse errors rather than maintaining another XML implementation.

`Time` is a UTC binary in `YYYY-MM-DDThh:mm:ssZ`, with a real Gregorian date and
year 0001–9999. Offsets, fractions and leap seconds are rejected. `sign/3` and
`sign/4` capture the current UTC second; use `sign/5` for controlled time. The same
supported RSA input, key, certificate and controlled time produce identical
output. Certificate-less calls still include SignedProperties and SigningTime.

## Returned errors and exceptions

| Condition, with other inputs valid | Public outcome |
| --- | --- |
| File read failure | `{error, {file_error, Reason}}`. |
| Key PEM decoder yields no entry or multiple entries | `{error, invalid_pem}`. |
| Signing declaration missing/unsupported | `{error, invalid_prolog}`. |
| Rejected XML | `{error, invalid_xml}` or another xmlan parse error propagated unchanged. |
| Unsupported hash atom | `{error, unsupported_hash}` in signing and verification. |
| Unsupported signing key kind | `{error, unsupported_key}`. |
| Signing input already contains any XMLDSig Signature | Raises `error:already_signed`. |
| Duplicate `Id`/`xml:id` values when signing | Raises `error:invalid_signature_structure`. |
| Additional/nested signatures or invalid reference IDs, target, algorithms or transform pair | `{error, invalid_signed_info}` or `{error, invalid_signature_structure}`. |
| Invalid signing time | `{error, invalid_signing_time}`. |
| Document/reference digest or cryptographic signature mismatch | `false`. |
| Missing/malformed recognized signature structure | `{error, Reason}`, for example `missing_signature`, `missing_signature_value`, `invalid_base64`, `invalid_signed_info` or `invalid_signature_structure`. |
| Supplied signing certificate does not match the signing key/operation | Raises `error:certificate_key_mismatch`. |
| Present KeyInfo has missing/duplicate X509Data/certificate fields, invalid base64, or the certificate/V2 pair is incomplete | `{error, invalid_certificate_metadata}`. |
| Embedded certificate DER or public key is invalid/unsupported | `{error, invalid_certificate}`. |
| Malformed/duplicate SigningCertificateV2 fields | `{error, invalid_signing_certificate_v2}` or `{error, duplicate_property}`. |
| Certificate digest or digest method mismatch | `{error, cert_digest_mismatch}`. |
| Present issuer/serial metadata does not match the embedded certificate | `{error, cert_issuer_mismatch}`. |
| Embedded certificate key does not verify the otherwise valid signature | `{error, certificate_key_mismatch}`. |

Already-signed input, duplicate signing identities and a mismatched supplied
signing certificate raise the explicit Signerl error reasons shown above. They abort signature construction and propagate to the
caller; they are not returned error tuples.

An otherwise valid but unrelated RSA key produces `false`. A supplied RSA/EC key
whose algorithm disagrees with SignatureMethod produces
`{error, invalid_signature_structure}`. Invalid OTP key terms,
malformed DER supplied as a certificate argument, or malformed data inside a PEM
entry may raise native Erlang/OTP errors. These low-level crypto inputs are the
caller's responsibility; Signerl does not catch and rewrap every OTP failure.
Unsupported argument types can also raise native errors. For malformed crypto
material, the native error reason/stack depends on OTP and is not a stable library
error atom. The function specifications describe supported values and normal
returns, not a guarantee
that every invalid argument returns an error tuple.

Do not depend on which error wins when several inputs are invalid. Public tests
exercise one invalid condition after a passing control. A future public failure
policy change must be explicit; the ownership refactor in #58 must preserve this
contract rather than silently translate exceptions.

## Compatibility and retained XAdES decisions

Reference rules (#52) and certificate binding (#54) are implemented. Known-property
decisions still constrain #55.

- **Reference compatibility (#52):** new signatures declare document transforms
  `[enveloped-signature, c14n11]` and SignedProperties transforms `[c14n11]`.
  Verification preserves the previous complete reference pair as a narrow
  compatibility case: document transforms contain
  enveloped-signature removal only, and SignedProperties has no Transforms.
  That legacy case retains the project's existing implicit C14N 1.1 processing;
  it is not general support for omitted transforms or all XMLDSig defaults.
  Only the complete new pair or complete legacy pair is accepted; mixtures,
  extra/reordered transforms, duplicate/empty Transforms containers and transform
  parameters are rejected. Whitespace and namespace declarations are permitted.
  SignedInfo separately supports C14N 1.1 or parameterless Exclusive C14N.
  Exactly two references are required: `URI=""` with no Type, and `URI="#actual-id"`
  with the required SignedProperties Type. Reference order may vary; external,
  unknown and additional references are rejected without dereferencing them.
  Signature/@Id and SignedProperties/@Id must be nonempty, unique document-wide,
  and agree with QualifyingProperties/@Target and the properties reference.
  Unqualified `Id` and `xml:id` values share the collision checks. Only one
  XMLDSig Signature is allowed, directly under the document element; signing
  rejects any existing Signature at any depth. Lookalikes in other namespaces
  remain ordinary signed content. Generated IDs use the usual names when free,
  or a deterministic numeric suffix when payload IDs reserve those names.
  SHA-256 digest methods and the signature method must agree with the actual
  hash/key operation in both formats; legacy compatibility has no validation
  exemption.
- **Certificate binding (#54):** certificate-bearing signatures require exactly
  one embedded X509Certificate in one X509Data/KeyInfo, paired with exactly one
  SigningCertificateV2/Cert. KeyInfo and X509Data accept only their selected child
  plus formatting whitespace; extra key fields or nested certificate containers
  are rejected. Present malformed, duplicate or one-sided metadata is
  rejected. The embedded value must be a complete DER certificate, with no ignored
  trailing bytes, containing an rsaEncryption or id-ecPublicKey key for the
  selected operation; restricted RSA-PSS keys are rejected for PKCS#1 signatures.
  Its SHA-256 digest
  must match the signed property. IssuerSerialV2 is optional; when present it must
  decode and exactly match the DER issuer/directoryName and serial from that
  certificate. Malformed or duplicate issuer data is not treated as absence.
  The signature is verified with both the caller's key and the certificate key;
  declaring a method alone does not establish key binding. Signing also checks
  the produced signature against the supplied certificate and raises an explicit
  error on mismatch. An unrelated caller RSA key still returns `false`.
  Both metadata components absent is the valid certificate-less path. The legacy
  SigningCertificate marker alone cannot substitute for the required pair.
  Invalid embedded DER/key errors become certificate errors; invalid caller
  key/DER inputs retain the native-failure policy above. Successful verification
  does not establish certificate-chain trust, validity periods or revocation.
- **Optional properties (#37/#55):** 1.0 promises supported structural handling,
  not policy-material digest verification, certified-role certification or full
  URI/MIME/referenced-object semantics. Those semantic extensions are deferred
  beyond 1.0. #55 must reject malformed/ambiguous known containers and fields;
  unknown extensions may be ignored semantically while remaining part of the
  signed bytes. Neither extraction nor a presence marker proves semantic checks.

XAdES SignedProperties, SigningTime and the existing certificate properties stay.
The legacy SigningCertificate presence marker alone is not proof of certificate
binding. Generic XML implementation and tests remain in xmlan.

## Example and read order

With loaded RSA key terms and an optional DER certificate:

```erlang
Input = <<"<?xml version='1.0'?><invoice><amount>42.00</amount></invoice>">>,
Time = <<"2024-02-29T03:04:05Z">>,
Signed = signerl:sign(Input, sha256, PrivateKey, CertDer, Time),
true = signerl:verify(Signed, sha256, PublicKey),
Tampered = binary:replace(Signed, <<"42.00">>, <<"43.00">>),
false = signerl:verify(Tampered, sha256, PublicKey),
false = signerl:verify(Signed, sha256, UnrelatedRsaPublicKey).
```

Set `CertDer` to `undefined` for no certificate. Examples assume valid loaded key
material; no separate application or dependency-installation test is required.
The tracked `priv/key.pem` is public legacy test data, used by the API regression
suite; it is not a private application credential. Generated keys/certificates
are described in [the fixture guide](../test/certs/README.md).

Read `src/signerl.erl` for the public binary/file boundary and orchestration,
`signerl_signature` for construction, and `signerl_verify` for reference and
signature extraction/checking. `signerl_signed_properties` and `signerl_xades_xml`
handle XAdES values/paths; `signerl_cert`, `signerl_dsig_utils` and `signerl_utils`
supply certificate, signature and key/time helpers. Follow xmlan's APIs for the
XML operations. #58 will simplify this ownership and update the read-order guide.
