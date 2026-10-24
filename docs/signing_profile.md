# Enveloped RSA-SHA256 with XAdES

The maintainer confirmed on 17 October 2026 that XAdES signing-time and
certificate properties stay in the 1.0 scope. This document records the selected
profile, the reference/identity/algorithm enforcement completed in #52 and the
certificate/property checks still unfinished below. [Issue #64](https://github.com/bormilan/signerl/issues/64)
is complete as profile definition. The 0.3 milestone and implementation tasks
below remain open until the selected behavior is implemented and validated.

## Selected profile

| Area | Contract |
| --- | --- |
| XML processing | UTF-8 input; xmlan owns parsing, namespaces, serialization and canonicalization. Signerl does not duplicate its implementation or tests. |
| Signature placement | One enveloped `ds:Signature`, directly under the document element. Signing an already-signed document must be rejected. Multiple/counter-signatures are outside this profile. |
| Signature method | RSA PKCS#1 v1.5 with SHA-256. The declared method must agree with the supplied key and actual operation. |
| Digests | SHA-256 for both supported references. |
| References | Exactly two: the whole document (`URI=""`) and the actual `xades:SignedProperties` element, with its required SignedProperties reference type. Unknown/additional references are rejected; no external dereferencing. |
| Reference transforms | New signatures use enveloped-signature removal followed by explicit C14N 1.1 for the document, and explicit C14N 1.1 for SignedProperties. Verification retains only the complete legacy pair as a compatibility case; both pairs require validated order/parameters and all ID/algorithm checks. See the API contract. |
| SignedInfo | New signatures use C14N 1.1. Existing tested Exclusive C14N SignedInfo verification remains separate from reference transforms; changing one must not silently change the other. |
| IDs and target | References resolve to unique actual IDs. `QualifyingProperties/@Target` identifies the containing signature. Missing, duplicate or mismatched relationships are rejected. |
| XAdES | SignedProperties and SignedSignatureProperties remain, including SigningTime. Existing certificate properties remain when a certificate is supplied. |
| Time | A valid UTC timestamp; callers may supply controlled time with `sign/5`. The signing time is covered by the SignedProperties digest. |
| Keys and files | Retain caller-supplied key terms, PEM key paths, binary XML and XML file paths. Verification uses the caller's supplied verification key. |
| Certificates | Retain optional certificate input, embedded X509Certificate and SigningCertificateV2 digest/issuer metadata. Present malformed metadata must not silently disable checks. Certificate binding is completed in #54. |

These restrictions select a small application profile; they are not a claim to
implement every XMLDSig or XAdES option. The existing ECDSA path is not removed
by this decision, but ECDSA XMLDSig wire-format correctness remains
[#53](https://github.com/bormilan/signerl/issues/53), outside the RSA MVP.
The legacy path stays callable, without a new rejection gate in this contract
pass, but is excluded from the supported 1.0 XMLDSig profile until #53 is fixed.

The distinction between SignedInfo canonicalization and reference processing
comes from [XML Signature processing](https://www.w3.org/TR/xmldsig-core1/#sec-ReferenceProcessingModel).
The XAdES object/target relationship is described in
[XAdES QualifyingProperties](https://www.w3.org/TR/XAdES/).
The exact two-reference and transform allowlists above are this project's profile.

## Public API retained

- `sign/3` signs using the current UTC time without a supplied certificate.
- `sign/4` adds certificate input and uses the current UTC time.
- `sign/5` accepts the certificate or `undefined` and an explicit UTC timestamp.
- `verify/3` verifies using the supplied key and hash selection.

Signing normally returns signed XML or `{error, Reason}`. Verification normally
returns `true`, `false` for a cryptographic mismatch, or `{error, Reason}` for a
rejected input/structure. Existing file errors retain `{error, {file_error, Reason}}`.
The [public API contract](api_contract.md) records supported inputs, specific
returned errors, explicit signing-policy exceptions and native failures for
invalid low-level crypto material. `sha256` is the only supported hash; both operations return
`{error, unsupported_hash}` for other hash atoms on otherwise valid inputs.
Malformed supplied DER/OTP key terms can raise native errors; public arities and
file/key conveniences remain. #59 tracks final alignment as correctness and
ownership work proceeds.

Given loaded RSA key terms and a DER certificate:

```erlang
Input = <<"<?xml version='1.0'?><invoice><amount>42.00</amount></invoice>">>,
Time = <<"2026-10-17T12:00:00Z">>,
Signed = signerl:sign(Input, sha256, PrivateKey, CertDer, Time),
true = signerl:verify(Signed, sha256, PublicKey),
Tampered = binary:replace(Signed, <<"42.00">>, <<"43.00">>),
false = signerl:verify(Tampered, sha256, PublicKey),
false = signerl:verify(Signed, sha256, UnrelatedPublicKey).
```

`CertDer` may be `undefined` to omit certificate material; SignedProperties and
SigningTime remain. This is an inline usage example, not a separate test
application or dependency-installation check.

## Implementation sequence and current gaps

1. [#59](https://github.com/bormilan/signerl/issues/59): the API contract records
   the algorithm/failure/compatibility decisions before correctness changes and
   refactoring. Optional semantic extensions in
   [#37](https://github.com/bormilan/signerl/issues/37) are deferred beyond 1.0;
   known-property structural fixes remain #55. Finish documentation against the
   implemented behavior later in this milestone.
2. [#52](https://github.com/bormilan/signerl/issues/52): enforce every reference,
   unique actual IDs/targets, declared algorithms/key agreement and transform
   chains: implemented. New output declares explicit C14N 1.1 for both references;
   existing implicit-reference signatures retain only the complete legacy pair
   described in the API contract. Both formats enforce the same reference,
   identity/target, method/key and placement checks. The full selected profile
   still needs the certificate/property work below.
3. [#54](https://github.com/bormilan/signerl/issues/54): distinguish absent,
   malformed and valid certificate metadata; complete key/certificate binding.
   A successful signature check alone does not establish chain trust, validity
   periods or revocation status.
4. [#55](https://github.com/bormilan/signerl/issues/55): reject ambiguous or
   malformed known signed-property containers. Keep unknown-extension policy
   separate from known-field validation. PR #48 supplied structural readers;
   remaining semantic extensions are explicitly deferred in #37, not completed.
5. [#58](https://github.com/bormilan/signerl/issues/58): simplify ownership after
   correctness fixes, while keeping these XAdES features. The timestamp work in
   [#56](https://github.com/bormilan/signerl/issues/56) is already complete.
6. Finish #59 documentation against the implemented behavior, then complete
   release acceptance in [#65](https://github.com/bormilan/signerl/issues/65).
   #65 confirms the supported RSA profile and ECDSA exclusion, release-branch
   integration and the initial distribution choice. Hex packaging in
   [#43](https://github.com/bormilan/signerl/issues/43) is required only if Hex
   is chosen and first needs a versioned xmlan Hex dependency.

The current [Signerl test map](../test/TESTS.md) covers signing, verification,
certificates, fixed time, tampering and independent fixtures. Required gates
remain full EUnit/Common Test, 100% Signerl coverage, flint, Dialyzer, native tall
and all six OTP 26/27/28 Ubuntu/Windows jobs. No generic XML suite is added here.
