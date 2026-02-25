# Test Overview

This document lists the current tests, why they exist, and what you should learn
from each one.

## Test Suite: `signerl_SUITE.erl`

- `add_signature_element_inserts_signature_value/1`
  Why: Validates signature insertion on the XML tree.
  Learn: Signature bytes are stored as base64 under `ds:SignatureValue`.

- `add_signature_element_inserts_signed_properties/1`
  Why: Validates that signing metadata is present in signature XML.
  Learn: Signed output includes `ds:Object/xades:QualifyingProperties/xades:SignedProperties` with `xades:SigningTime`.

- `add_signature_element_extracts_signature_value/1`
  Why: Validates extraction after insertion.
  Learn: Extractor returns original signature bytes and unsigned message.

- `add_signature_element_extract_binary_and_rejects_empty/1`
  Why: Validates edge cases for `ds:SignatureValue` content shape.
  Learn: Binary values decode successfully while empty values are rejected.

- `sign/1`
  Why: Basic sign/verify loop using an explicitly loaded private key.
  Learn: `sign/3` returns signed XML and `verify/3` consumes it correctly for both binary and file-based inputs.

- `sign_with_chain_leaf_rsa/1`
  Why: Sign using the leaf RSA key from a certificate chain and verify with the
  public key extracted from the leaf certificate.
  Learn: Leaf certificates can be used for signing, and certificate parsing
  yields a valid RSA public key for verification.

- `sign_with_self_signed_rsa/1`
  Why: Sign using a self-signed RSA certificate and verify with its public key.
  Learn: Self-signed certificates work for local testing without a CA chain.

- `sign_with_self_signed_ecdsa/1`
  Why: Sign using an ECDSA key and verify with the public key extracted from its
  certificate.
  Learn: Non-RSA keys work with the same sign/verify APIs.

- `sign_deterministic/1`
  Why: Signs the same XML twice with the same RSA key and compares outputs.
  Learn: The signed XML output is deterministic (important for repeatable tests).

- `verify_returns_error_without_signature_element/1`
  Why: Verify should reject invalid signature structure.
  Learn: Missing and duplicated `ds:Signature` are mapped to `{error, invalid_signature}`.

- `verify_returns_error_without_signature_value/1`
  Why: Verify should reject signatures without `ds:SignatureValue`.
  Learn: Missing signature value maps to `{error, invalid_signature}`.

- `verify_returns_error_with_empty_signature_value/1`
  Why: Verify should reject empty signature values.
  Learn: Empty signature value maps to `{error, invalid_signature}`.

- `verify_returns_error_with_invalid_base64_signature_value/1`
  Why: Verify should reject non-base64 signature values.
  Learn: Invalid base64 maps to `{error, invalid_signature}`.

- `verify_returns_error_with_self_closing_signature_value/1`
  Why: Verify should reject self-closing `ds:SignatureValue`.
  Learn: Self-closing value maps to `{error, invalid_signature}`.

- `verify_returns_error_without_signed_properties/1`
  Why: Signed-properties are mandatory in current profile.
  Learn: Missing `xades:SignedProperties` maps to `{error, invalid_signature}`.

- `verify_returns_error_without_object/1`
  Why: XAdES properties wrapper object is required.
  Learn: Missing `ds:Object` maps to `{error, invalid_signature}`.

- `verify_returns_error_without_qualifying_properties/1`
  Why: Qualifying-properties wrapper is required.
  Learn: Missing `xades:QualifyingProperties` maps to `{error, invalid_signature}`.

- `verify_returns_error_without_signed_signature_properties/1`
  Why: Nested signed-signature-properties container is required.
  Learn: Missing `xades:SignedSignatureProperties` maps to `{error, invalid_signature}`.

- `verify_returns_error_without_signing_time/1`
  Why: Signing time must be present.
  Learn: Missing `xades:SigningTime` maps to `{error, invalid_signature}`.

- `verify_returns_error_with_invalid_signing_time/1`
  Why: Signing time format must be strict UTC.
  Learn: Invalid timestamp format maps to `{error, invalid_signature}`.

- `verify_returns_error_with_self_closing_signing_time/1`
  Why: Self-closing signing-time element is malformed.
  Learn: Self-closing `xades:SigningTime` maps to `{error, invalid_signature}`.

- `verify_returns_false_with_wrong_signature_value/1`
  Why: Verify should return `false` for present-but-wrong signature bytes.
  Learn: Cryptographic mismatch is distinct from malformed signature structure.

- `verify_fails_on_modified_message/1`
  Why: Verify fails when the signed XML is modified.
  Learn: Signatures are bound to the exact message content.

- `verify_fails_on_modified_signing_time/1`
  Why: Verify fails when `xades:SigningTime` is changed.
  Learn: Signed-properties are cryptographically bound to the signature payload.

- `verify_fails_with_wrong_keys/1`
  Why: Verify fails with both wrong RSA public key and wrong key type for ECDSA signatures.
  Learn: Verification is correctly tied to both key identity and key algorithm compatibility.

## Test Suite: `signerl_signed_properties_SUITE.erl`

- `extract_accepts_optional_signed_signature_properties/1`
  Why: Validates the dedicated signed-properties module accepts optional known XAdES properties.
  Learn: Known optional signed-signature properties are parsed into the properties map and preserved.

- `extract_ignores_unknown_signed_signature_properties/1`
  Why: Validates forward-compatible behavior for unknown properties.
  Learn: Unknown signed-signature properties are ignored rather than causing verification failure.

- `extract_returns_error_with_duplicate_signing_time_property/1`
  Why: Ensures required known properties are unique.
  Learn: Duplicate `xades:SigningTime` is treated as invalid.

- `extract_returns_error_without_signing_time/1`
  Why: Confirms required-property enforcement in the dedicated module.
  Learn: Missing `xades:SigningTime` returns `error`.

## Helpers: `test_helpers.erl`

These are not tests, but they are used by the suite:

- `rsa_public_key_from_cert/1`
  Why: Extracts the RSA public key from a certificate using PKIX decoding.
  Learn: How to safely parse RSA public keys from X.509 certs.

- `ecdsa_public_key_from_cert/1`
  Why: Extracts the EC public key and curve parameters from a certificate.
  Learn: How ECDSA public keys are represented in OTP records.
