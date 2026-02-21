# Test Overview

This document lists the current tests, why they exist, and what you should learn
from each one.

## Test Suite: `signerl_SUITE.erl`

- `add_signature_element/1`
  Why: Validates signature insertion and extraction on the XML tree.
  Learn: Signature bytes are stored as base64 and extracted back together with
  the unsigned message shape.

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

- `verify_returns_error_on_missing_or_empty_signature_value/1`
  Why: Verify should reject malformed `ds:SignatureValue` forms.
  Learn: Missing, empty, invalid-base64, and self-closing values map to `{error, invalid_signature}`.

- `verify_returns_false_with_wrong_signature_value/1`
  Why: Verify should return `false` for present-but-wrong signature bytes.
  Learn: Cryptographic mismatch is distinct from malformed signature structure.

- `verify_fails_on_modified_message/1`
  Why: Verify fails when the signed XML is modified.
  Learn: Signatures are bound to the exact message content.

- `verify_fails_with_wrong_keys/1`
  Why: Verify fails with both wrong RSA public key and wrong key type for ECDSA signatures.
  Learn: Verification is correctly tied to both key identity and key algorithm compatibility.

## Helpers: `test_helpers.erl`

These are not tests, but they are used by the suite:

- `rsa_public_key_from_cert/1`
  Why: Extracts the RSA public key from a certificate using PKIX decoding.
  Learn: How to safely parse RSA public keys from X.509 certs.

- `ecdsa_public_key_from_cert/1`
  Why: Extracts the EC public key and curve parameters from a certificate.
  Learn: How ECDSA public keys are represented in OTP records.
