# Test Overview

This document lists the current tests, why they exist, and what you should learn
from each one.

## Test Suite: `signerl_SUITE.erl`

- `add_signature_element/1`
  Why: Validates that a signature placeholder element can be inserted into the
  XML tree. This is a base capability for later XML-DSig work.
  Learn: The XML helper functions handle element insertion as expected.

- `sign/1`
  Why: Basic sign/verify loop using an explicitly loaded private key.
  Learn: The core sign/verify APIs work correctly with in-memory keys.

- `sign_from_file/1`
  Why: Sign and verify while loading both XML and key from files.
  Learn: File-based flows (common in real usage) behave correctly.

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
  Why: Signs the same XML twice with the same RSA key and compares signatures.
  Learn: The signing flow is deterministic (important for repeatable tests).

- `verify_fails_on_modified_message/1`
  Why: Verify fails when the signed XML is modified.
  Learn: Signatures are bound to the exact message content.

- `verify_fails_with_wrong_key/1`
  Why: Verify fails when using a different RSA key than the signer’s key.
  Learn: Verification is correctly tied to the signer’s public key.

- `verify_fails_with_wrong_ecdsa_key/1`
  Why: Verify fails when an ECDSA signature is checked with an RSA public key.
  Learn: Algorithm/key mismatches are rejected by verification.

## Helpers: `test_helpers.erl`

These are not tests, but they are used by the suite:

- `rsa_public_key_from_cert/1`
  Why: Extracts the RSA public key from a certificate using PKIX decoding.
  Learn: How to safely parse RSA public keys from X.509 certs.

- `ecdsa_public_key_from_cert/1`
  Why: Extracts the EC public key and curve parameters from a certificate.
  Learn: How ECDSA public keys are represented in OTP records.

