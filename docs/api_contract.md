# Public signing and verification contract

This describes the public API and the decisions that guide the remaining 0.3
work. The [selected profile](signing_profile.md) separates its target checks from
implementation still tracked in #52/#54/#55. This contract does not claim those
unfinished checks already pass.

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

## Returned errors and native failures

| Condition, with other inputs valid | Public outcome |
| --- | --- |
| File read failure | `{error, {file_error, Reason}}`. |
| Key PEM decoder yields no entry or multiple entries | `{error, invalid_pem}`. |
| Signing declaration missing/unsupported | `{error, invalid_prolog}`. |
| Rejected XML | `{error, invalid_xml}` or another xmlan parse error propagated unchanged. |
| Unsupported hash atom | `{error, unsupported_hash}` in signing and verification. |
| Unsupported signing key kind | `{error, unsupported_key}`. |
| Invalid signing time | `{error, invalid_signing_time}`. |
| Document/reference digest or cryptographic signature mismatch | `false`. |
| Missing/malformed recognized signature structure | `{error, Reason}`, for example `missing_signature`, `missing_signature_value`, `invalid_base64`, `invalid_signed_info` or `invalid_signature_structure`. |
| Certificate digest mismatch | `{error, cert_digest_mismatch}`. |

An otherwise valid but unrelated RSA key produces `false`. Invalid OTP key terms,
malformed DER supplied as a certificate argument, or malformed data inside a PEM
entry may raise native Erlang/OTP errors. These low-level crypto inputs are the
caller's responsibility; Signerl does not catch and rewrap every OTP failure.
Unsupported argument types can also raise native errors. The exact native error
reason/stack depends on OTP and is not a stable library error atom. The function
specifications describe supported values and normal returns, not a guarantee
that every invalid argument returns an error tuple.

Do not depend on which error wins when several inputs are invalid. Public tests
exercise one invalid condition after a passing control. A future public failure
policy change must be explicit; the ownership refactor in #58 must preserve this
contract rather than silently translate exceptions.

## Compatibility and retained XAdES decisions

These decisions constrain follow-up implementation; they do not mark it complete.

- **Reference compatibility (#52):** generate explicit C14N 1.1 reference
  transforms for new signatures. Preserve verification of the previous fixed
  reference pair as a narrow compatibility case: document transforms contain
  enveloped-signature removal only, and SignedProperties has no Transforms.
  That legacy case retains the project's existing implicit C14N 1.1 processing;
  it is not general support for omitted transforms or all XMLDSig defaults.
  Accept only the complete new pair or complete legacy pair, not arbitrary
  mixtures/extra transforms. In either case, enforce every reference, unique
  actual IDs/targets, declared algorithms and signature placement/count. Legacy
  compatibility must not preserve acceptance of malformed signatures.
- **Certificate binding (#54):** the retained certificate-bearing profile pairs
  a valid embedded X509Certificate with SigningCertificateV2. Reject malformed,
  duplicate, missing or one-sided certificate metadata rather than report
  incomplete binding as success; check digest/issuer metadata and correspondence
  with the supplied signing/verification key. Both absent is the valid
  certificate-less path. Current permissive behavior is a known gap, not this
  target guarantee. No certificate-chain trust, validity-period or revocation
  decision follows from `true`.
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
