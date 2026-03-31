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

- `build_signature_element_rsa_and_ecdsa/1`
  Why: Validates SignedInfo-based signature element construction for both key types.
  Learn: `build_signature_element/3` emits `ds:SignedInfo` for RSA and ECDSA keys.

- `build_signature_element_returns_error_with_invalid_hash_or_key/1`
  Why: Enforces current profile constraints at constructor level.
  Learn: Unsupported hash/key inputs return `{error, invalid_signature}`.

- `sign/1`
  Why: Basic sign/verify loop using an explicitly loaded private key.
  Learn: `sign/3` now emits `ds:SignedInfo` and `verify/3` validates reference digests before signature bytes.

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

- `verify_returns_error_with_non_text_signature_value_in_signedinfo/1`, `verify_returns_error_with_non_byte_list_signature_value_in_signedinfo/1`, `verify_returns_error_with_empty_binary_signature_value_in_signedinfo/1`
  Why: SignedInfo-era extraction still validates malformed `ds:SignatureValue` payload shapes.
  Learn: Non-text, invalid byte-list, and empty-binary signature values map to `{error, invalid_signature}`.

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

- `verify_returns_error_without_signed_info/1`
  Why: SignedInfo is mandatory in current profile.
  Learn: Missing `ds:SignedInfo` maps to `{error, invalid_signature}`.

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

- `sign_returns_error_with_unsupported_hash/1`, `sign_returns_error_with_unsupported_key/1`, `verify_returns_error_with_unsupported_hash/1`
  Why: Profile currently supports deterministic SHA-256 signing/verification only.
  Learn: Unsupported hash/key combinations return `{error, invalid_signature}`.

- `extract_signature_data_returns_error_with_missing_c14n/1`, `extract_signature_data_returns_error_with_missing_reference_uri/1`, `extract_signature_data_returns_error_with_invalid_reference_payload/1`
  Why: `ds:SignedInfo` structure and reference nodes are required.
  Learn: Malformed SignedInfo/reference layouts map to `{error, invalid_signature}`.

- `verify_reference_digests_returns_error_with_missing_signed_properties_element/1`, `verify_reference_digests_returns_error_with_invalid_document_reference/1`, `verify_reference_digests_returns_error_with_invalid_signed_properties_reference/1`
  Why: Reference metadata must match expected URI/type contract.
  Learn: Invalid reference metadata is rejected before cryptographic verification.

- `verify_reference_digests_returns_error_with_invalid_signature_data/1`
  Why: Verifier must reject malformed signature-data maps defensively.
  Learn: Non-conforming signature-data input returns `{error, invalid_signature}`.

- `xades_xml_returns_error_with_non_signature_input/1`
  Why: XAdES XML extractors should reject non-`ds:Signature` roots.
  Learn: Non-signature input returns `{error, invalid_signature}` from both extractor helpers.

## Test Suite: `signerl_signed_properties_SUITE.erl`

- `extract_accepts_optional_signed_signature_properties/1`
  Why: Validates the dedicated signed-properties module accepts optional known XAdES properties.
  Learn: Known optional signed-signature properties are parsed into the properties map and preserved.

- `extract_ignores_unknown_signed_signature_properties/1`
  Why: Validates forward-compatible behavior for unknown properties.
  Learn: Unknown signed-signature properties are ignored rather than causing verification failure.

- `extract_accepts_binary_signing_time/1`, `extract_returns_error_with_non_byte_list_signing_time/1`, `extract_returns_error_with_non_text_signing_time/1`
  Why: Validates accepted and rejected SigningTime value representations.
  Learn: Binary SigningTime is accepted; invalid list/non-text forms return `{error, invalid_signature}`.

- `extract_returns_error_with_duplicate_signing_time_property/1`
  Why: Ensures required known properties are unique.
  Learn: Duplicate `xades:SigningTime` is treated as invalid.

- `extract_returns_error_without_signing_time/1`
  Why: Confirms required-property enforcement in the dedicated module.
  Learn: Missing `xades:SigningTime` returns `{error, invalid_signature}`.

## Helpers: `test_helpers.erl`

These are not tests, but they are used by the suite:

- `rsa_public_key_from_cert/1`
  Why: Extracts the RSA public key from a certificate using PKIX decoding.
  Learn: How to safely parse RSA public keys from X.509 certs.

- `ecdsa_public_key_from_cert/1`
  Why: Extracts the EC public key and curve parameters from a certificate.
  Learn: How ECDSA public keys are represented in OTP records.
