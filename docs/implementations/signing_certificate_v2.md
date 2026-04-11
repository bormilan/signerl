# SigningCertificateV2 Property (Issue #36)

## What Changed

### New module: `src/signerl_cert.erl`
Certificate operations for XAdES SigningCertificateV2:
- `cert_digest_base64/2` — computes `base64(hash(CertDER))` for a given hash algorithm
- `issuer_serial_v2_base64/1` — encodes `IssuerSerial` (RFC 5035) as `base64(DER(SEQUENCE{GeneralNames, CertificateSerialNumber}))` using manual DER encoding (OTP lacks the `IssuerSerial` ASN.1 type)

### Modified: `src/signerl_signature.erl`
- `signed_properties/1` → `signed_properties/4` now accepts `HashAlgorithm`, `DigestMethodUri`, and `CertDer`
- Added `signing_certificate_v2_elements/3` to emit the `xades:SigningCertificateV2` XML element when `CertDer` is provided; returns `[]` when `CertDer` is `undefined` (backward compat)

### Modified: `src/signerl_signed_properties.erl`
- Replaced placeholder `SigningCertificateV2` validator with full structural validation
- `validate_signing_certificate_v2/1` parses `xades:Cert > xades:CertDigest` (digest method + value) and optional `xades:IssuerSerialV2`
- Returns structured map: `#{digest_method, digest_value, issuer_serial_v2?}`
- Added helpers: `validate_cert_element/1`, `extract_cert_digest/1`, `validate_cert_digest/1`, `extract_issuer_serial_v2/1`, `find_element/2`, `decode_base64_text/1`, `decode_base64_value/1`

### Modified: `src/signerl_verify.erl`
- Added `verify_cert_digest/3` with three clauses:
  1. Both `SigningCertificateV2` and `KeyInfo` cert present → cross-check digest
  2. `SigningCertificateV2` present but no `KeyInfo` cert → pass (can't verify)
  3. No `SigningCertificateV2` → pass (backward compat)
- `verify_reference_digests` pattern now includes `signed_properties` and `key_info` fields
- `else` clause propagates `{error, cert_digest_mismatch}` specifically

### Modified: `elvis.config`
- Added `signerl_cert` to `atom_naming_convention` ignore list (uses OTP ASN.1 record field names like `tbsCertificate`, `serialNumber`)

### Modified: `scripts/gen_certs.sh`
- Added step 8: generates `high_serial.cert.pem` with serial 0xFF for DER integer padding coverage

### New test cert: `priv/certs/high_serial.cert.pem` / `high_serial.key.pem`
- Self-signed RSA cert with serial number 255 (0xFF) — exercises DER integer high-bit padding branch

### Test changes
- `test/signerl_signed_properties_SUITE.erl`: 13 → 20 tests (+7 edge-case tests for decode_base64, find_element, invalid issuer serial, missing digest method, binary values)
- `test/signerl_SUITE.erl`: added 6 tests to `keyinfo_group` (cert v2 presence, absence, digest extraction, high-serial encoding, cert-v2-without-keyinfo, mismatched digest method)
- `test/signerl_cert_helpers.erl`: added `high_serial_cert_path/0`

## Why This Solves the Task

XAdES Baseline-B requires `SigningCertificateV2` to cryptographically bind the signature to a specific certificate. This implementation:
- **Builds** the element during signing (`sign/4` path) using the same hash algorithm as the signature
- **Validates** the element during verification by cross-checking the embedded cert digest against the actual certificate from `KeyInfo`
- **Preserves backward compatibility**: `sign/3` (no cert) omits the element; verification passes when the element is absent
- Follows RFC 5035 for `IssuerSerial` DER encoding

## Validation

| Gate | Result |
|------|--------|
| `rebar3 eunit` | 14 tests, 0 failures |
| `rebar3 ct` | 149 tests, 0 failures |
| `rebar3 as test cover` | 100% total coverage |
| `rebar3 flint` | Clean |
| `rebar3 dialyzer` | Clean |

## Documentation

No public API changes (`sign/4` and `verify/3` signatures unchanged). The `SigningCertificateV2` element is automatically included/validated when a certificate is provided. No README update required.
