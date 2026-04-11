# Signed Property Validators

**Issue:** #37  
**Branch:** `feature/signed-property-validators`

## What Changed

### Files and Behavior

**`src/signerl_signed_properties.erl`** — Complete rewrite of validator logic:
- Replaced 3 placeholder validators (`present` stubs) with real structural validation:
  - `SignaturePolicyIdentifier` — validates `SignaturePolicyImplied` or `SignaturePolicyId` (URI + digest + optional description)
  - `SignatureProductionPlace` — extracts optional City, StateOrProvince, PostalCode, CountryName
  - `SignerRole` — validates ClaimedRoles and/or CertifiedRoles (at least one container required)
- Added `SignedDataObjectProperties` pipeline for multi-valued properties:
  - `DataObjectFormat` — requires `ObjectReference` attribute, optional MimeType/Description/Encoding
  - `CommitmentTypeIndication` — requires `CommitmentTypeId/Identifier`, optional scope (all/references)
- Added shared `extract_digest/1` helper to DRY up digest extraction in cert and policy validators
- Renamed `validate_signed_properties` → `validate_signed_signature_properties` for clarity
- `extract/1` now chains both `SignedSignatureProperties` and `SignedDataObjectProperties` via `maybe`

**`src/signerl_xades_xml.erl`** — Added `find_signed_data_object_properties/1`:
- XPath lookup through `ds:Object/xades:QualifyingProperties/xades:SignedProperties/xades:SignedDataObjectProperties`

**`test/test_helpers.erl`** — Added `signature_element/2`:
- Builds signature XML with both `SignedSignatureProperties` and `SignedDataObjectProperties`

**`test/signerl_signed_properties_SUITE.erl`** — Complete rewrite:
- 8 test groups, 66 tests covering all 5 validators + edge cases
- Helper functions for building policy, place, role, format, and commitment XML

**`docs/signed_properties_scope_and_gaps.md`** — Updated to reflect completed validators.

### Error Atoms
- `invalid_signature_policy_identifier` — malformed policy element
- `invalid_signer_role` — no claimed or certified roles
- `invalid_data_object_format` — missing ObjectReference
- `invalid_commitment_type_indication` — missing or empty identifier

### Return Shapes
- Policy: `#{type => implied}` or `#{type => explicit, identifier, digest_method, digest_value, description?}`
- Place: `#{city?, state_or_province?, postal_code?, country_name?}`
- Role: `#{claimed_roles?, certified_roles?}` (at least one present)
- Format: `#{object_reference, mime_type?, description?, encoding?}` (list under `data_object_formats`)
- Commitment: `#{identifier, scope?}` (list under `commitment_type_indications`)

## Why This Solves the Task

Issue #37 required replacing 5 placeholder validators with real structural validation per XAdES v1.3.2.
All 5 validators now enforce the required elements/attributes per the spec while tolerating optional content.
The `SignedDataObjectProperties` pipeline was added as a new sibling extraction path because `DataObjectFormat` and `CommitmentTypeIndication` live under a different parent element than the signature-level properties.

## Validation

- **195 CT tests** pass (66 in `signerl_signed_properties_SUITE`, 87 in `signerl_SUITE`, 42 in `signerl_c14n_SUITE`)
- **14 eunit tests** pass
- **100% code coverage** across all modules
- **rebar3 flint** — clean (no DRY or style issues)
- **rebar3 dialyzer** — clean (no type issues)
- **make ci-local** — not run (Docker not available on this machine; CI will validate on push)

## Documentation

- Implementation log: this file
- Gap doc updated: `docs/signed_properties_scope_and_gaps.md`
- No public API changes (verification pipeline unchanged)
