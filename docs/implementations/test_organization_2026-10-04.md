# Issue #67: tests organized by responsibility

## Change and rationale

The merged #57 baseline (`4113361`) contained 14 EUnit tests and 198 CT cases.
The main CT suite mixed public workflows with low-level contracts and XML
utilities. Its coverage alias ignored EUnit results, preventing a useful split.

- `rebar.config` now collects EUnit coverage as well as CT coverage. The existing
  reset still runs exactly once before both frameworks, and the final aggregate
  threshold remains 100%. The `tall` and CI entrypoints are unchanged.
- Pure canonicalization and signed-properties tests moved to focused EUnit
  modules. Builder, verifier, certificate encoding, and XAdES lookup contracts
  also have modules matching the production responsibility. EUnit setup cases
  retain explicit scenario names and the original proplist fixture values.
- `signerl_api_SUITE` retains public signing/verification, key/file inputs,
  certificate wiring, tamper workflows, and the independent signature fixtures.
  The verifier's duplicate-attribute rejection remains with the verifier's
  named contract cases, including its public-API assertion and positive control.
- `signerl_c14n_interop_SUITE` retains all seven xmllint comparisons and the
  production parsing path. `signerl_xml_SUITE` owns the single isolated file
  round-trip. XML utility contracts live in `signerl_xml_test`.
- Two existing assertion helpers shared by API and verifier cases moved into
  `test_helpers` without changing their behavior. Other fixture construction,
  assertion semantics, input XML, and independent signatures are unchanged.
- Removed the obsolete `signerl_SUITE` god-module lint exemption. Updated
  `README.md` and `test/TESTS.md` with responsibilities and run commands.

The result is **146 EUnit + 62 CT = 208 cases**. The difference from 212 is
exactly four duplicate XML cases; each retained assertion is mapped below.
No production source, supported signature profile, timestamp behavior, or
third-party CI workflow changed. Fixture/assertion cleanup remains #68.

## Validation-first coverage experiment

A disposable rebar application used two production functions: `double/1`,
asserted only by EUnit, and `greet/1`, asserted only by CT. It used this repo's
`test` alias and plugins. No custom runner was added to the repository.

| Probe | Coverage | Expected result |
| --- | ---: | --- |
| Original alias, EUnit coverage disabled | 50% | Failed the 100% threshold despite both tests passing. |
| Enable EUnit coverage | 100% | Passed using both `eunit.coverdata` and `ct.coverdata`. |
| Repeat with the existing build cache | 100% | Passed. |
| Add a genuinely untested third function | 66% | Failed the threshold. |
| Restore the two-function application | 100% | Passed; seeded cached results. |
| Disable EUnit collection and omit the reset in the disposable config | 100% | Demonstrated a false pass from stale EUnit data. |
| Restore the reset, leaving EUnit collection disabled in the probe | 50% | Failed correctly; stale EUnit data was removed. |

Only the one-line EUnit coverage change was made in the actual repository.
The reset and threshold were never weakened there.

## Migration review

- Token comparison checked 194 moved/retained CT case bodies plus the 15
  existing XML EUnit functions/helpers: all 209 matched after accounting for
  entrypoint naming, proplist access, shared-helper qualification, and the
  high-serial certificate fixture moving into its owning unit test. A further
  60 helper comparisons also matched (269 comparisons in total).
- All 198 original CT cases have a destination below. The four duplicate cases
  map to existing EUnit assertions; all original EUnit cases remain.
- A disposable verifier-module copy with one deliberately incorrect assertion
  reported the explicit `signature_reconstruction_preserves_valid_baseline`
  scenario name, one failure, and 19 passes. The actual module was unchanged.
- Self-review using the repository's `ferike` checklist found no blocking
  findings. The only lint findings were two 101-character descriptor lines;
  splitting those calls fixed them and the affected verifier tests were rerun.
  The final diff preserves production code, XML fixtures, encoding/prolog cases,
  namespace/canonicalization assertions, and the #57 positive/no-op controls.
- Simplification review removed the obsolete god-module exemption and shares
  only the two assertion helpers used by both API and verifier tests. Existing
  fixture builders and shallow map access stay unchanged for this move; the
  broader fixture/helper cleanup belongs to #68. The existing clock-dependent
  determinism case remains a known #56 risk, not a newly corrected behavior.
- Recovered the prior migration scripts into persistent storage, preserving the
  previously identified fixture-overload and CT teardown fixes. Fresh EUnit and
  CT runs validate the recovered implementation rather than relying on old logs.
- Helpers remain local to their owning modules except the two genuinely shared
  assertions. Named fixture descriptors use standard EUnit setup rather than a
  configurable test framework. Broader fixture simplification is deferred to #68.

## Quality gates

Fresh validation used host OTP 28.4.2 and rebar3 3.25.1, with an isolated
`REBAR_GLOBAL_CONFIG_DIR` to avoid unrelated user-global plugins.

- `rebar3 eunit`: 146 passed; focused verifier command: 23 passed.
- `rebar3 ct`: 62 passed, with no skipped cases or callback failures.
- Final `rebar3 test`: 146 EUnit + 62 CT passed; 100% combined coverage across
  all ten production modules. Both coverage data files contributed.
- `rebar3 as test cover`: 100% aggregate coverage.
- `rebar3 flint`: passed after the two descriptor line wraps.
- `rebar3 dialyzer`: passed with no project findings.
- Final `rebar3 tall`: passed, including all tests, 100% combined coverage,
  formatting/lint, Xref, and Dialyzer.
- All coverage probes in the table above were rerun successfully in this task.
- The first Docker run exposed stale copied source files for removed suites in
  all three existing build volumes. Rebar returned success and reported 62 cases,
  but also logged `error_in_suite`; this run was rejected. Native
  `rebar3 as test clean` removed BEAM files but left the copied Erlang sources.
  This matches [Rebar's cleanup implementation](https://github.com/erlang/rebar3/blob/3.25.1/apps/rebar/src/rebar_prv_clean.erl).
  Reset only the generated `test` profile in each build volume, retaining default
  builds, PLTs, and dependency caches. Documented the one-time migration cleanup
  in `test/TESTS.md`. No generated file contents were patched.
- `make ci-local` passed after the profile reset and again with those rebuilt
  caches unchanged. Linux OTP 26.2.5.16, 27.3.4.6, 28.3.1 each ran the full
  `tall` gate: 146 EUnit + 62 CT, no skipped cases or suite-loading failures,
  100% combined coverage, formatting/lint, Xref, and Dialyzer. Log inspection was
  required in addition to zero exit status. Docker used an isolated client
  configuration for the public images; user Docker configuration was unchanged.
- `git diff --check`: passed. Runtime/CI configurations discover the migrated
  modules without a manually maintained list. No tracked XML fixture changed.

## Recovery storage

Work continues in the persistent managed worktree
`/Users/milanbor/.codex/worktrees/signerl-issue-67/signerl`.
Prior commands, migration tools, validation logs, and a recovery snapshot of
tracked diffs/untracked sources are stored under
`/Users/milanbor/projects/signerl/.recovery/issue-67/`.
The snapshot is refreshed after substantive edits and before yielding.

## Before/after case map

The old module names refer to the merged #57 baseline. A `_test` suffix denotes
an ordinary EUnit test; unchanged names in EUnit modules are named setup cases.
Existing `signerl_xml_test` functions are unchanged, with one additional moved
signature-element recognition case.

### signerl_SUITE

| Original case | Destination |
| --- | --- |
| `add_signature_element_inserts_signature_value` | `signerl_signature_test:add_signature_element_inserts_signature_value` |
| `add_signature_element_inserts_signed_properties` | `signerl_signature_test:add_signature_element_inserts_signed_properties` |
| `add_signature_element_extracts_signature_value` | `signerl_signature_test:add_signature_element_extracts_signature_value` |
| `build_signature_element_rsa_and_ecdsa` | `signerl_signature_test:build_signature_element_rsa_and_ecdsa` |
| `build_signature_element_returns_error_with_invalid_hash_or_key` | `signerl_signature_test:build_signature_element_returns_error_with_invalid_hash_or_key` |
| `signature_reconstruction_preserves_valid_baseline` | `signerl_verify_test:signature_reconstruction_preserves_valid_baseline` |
| `verify_returns_error_with_non_text_signature_value_in_signedinfo` | `signerl_verify_test:verify_returns_error_with_non_text_signature_value_in_signedinfo` |
| `verify_returns_error_with_non_byte_list_signature_value_in_signedinfo` | `signerl_verify_test:verify_returns_error_with_non_byte_list_signature_value_in_signedinfo` |
| `verify_returns_error_with_empty_binary_signature_value_in_signedinfo` | `signerl_verify_test:verify_returns_error_with_empty_binary_signature_value_in_signedinfo` |
| `verify_returns_error_without_signed_info` | `signerl_verify_test:verify_returns_error_without_signed_info` |
| `extract_signature_data_returns_error_with_missing_c14n` | `signerl_verify_test:extract_signature_data_returns_error_with_missing_c14n` |
| `verify_reference_digests_returns_error_with_invalid_c14n_algorithm` | `signerl_verify_test:verify_reference_digests_returns_error_with_invalid_c14n_algorithm` |
| `reference_digests_are_independent_of_signed_info_c14n` | `signerl_verify_test:reference_digests_are_independent_of_signed_info_c14n` |
| `verify_reference_digests_returns_error_with_invalid_signature_method_algorithm` | `signerl_verify_test:verify_reference_digests_returns_error_with_invalid_signature_method_algorithm` |
| `extract_signature_data_returns_error_with_missing_reference_uri` | `signerl_verify_test:extract_signature_data_returns_error_with_missing_reference_uri` |
| `extract_signature_data_returns_error_with_invalid_reference_payload` | `signerl_verify_test:extract_signature_data_returns_error_with_invalid_reference_payload` |
| `verify_reference_digests_returns_error_with_missing_document_transforms` | `signerl_verify_test:verify_reference_digests_returns_error_with_missing_document_transforms` |
| `verify_reference_digests_returns_error_with_invalid_document_transform_algorithm` | `signerl_verify_test:verify_reference_digests_returns_error_with_invalid_document_transform_algorithm` |
| `verify_reference_digests_returns_error_with_transform_without_algorithm` | `signerl_verify_test:verify_reference_digests_returns_error_with_transform_without_algorithm` |
| `verify_reference_digests_returns_error_with_invalid_transform_element` | `signerl_verify_test:verify_reference_digests_returns_error_with_invalid_transform_element` |
| `verify_rejects_duplicate_reference_attributes` | `signerl_verify_test:verify_rejects_duplicate_reference_attributes` |
| `verify_reference_digests_returns_error_with_missing_signed_properties_element` | `signerl_verify_test:verify_reference_digests_returns_error_with_missing_signed_properties_element` |
| `verify_reference_digests_returns_error_with_invalid_document_reference` | `signerl_verify_test:verify_reference_digests_returns_error_with_invalid_document_reference` |
| `verify_reference_digests_returns_error_with_invalid_signed_properties_reference` | `signerl_verify_test:verify_reference_digests_returns_error_with_invalid_signed_properties_reference` |
| `verify_reference_digests_returns_error_with_invalid_signature_data` | `signerl_verify_test:verify_reference_digests_returns_error_with_invalid_signature_data` |
| `extract_signature_returns_error_without_signature_element_direct` | `signerl_verify_test:extract_signature_returns_error_without_signature_element_direct_test` |
| `c14n_mode_returns_exc_for_exc_c14n_algorithm` | `signerl_verify_test:c14n_mode_returns_exc_for_exc_c14n_algorithm_test` |
| `extract_x509_certificate_returns_undefined_for_invalid_cert` | `signerl_verify_test:extract_x509_certificate_returns_undefined_for_invalid_cert_test` |
| `sign` | `signerl_api_SUITE:sign` |
| `sign_with_chain_leaf_rsa` | `signerl_api_SUITE:sign_with_chain_leaf_rsa` |
| `sign_with_self_signed_rsa` | `signerl_api_SUITE:sign_with_self_signed_rsa` |
| `sign_with_self_signed_ecdsa` | `signerl_api_SUITE:sign_with_self_signed_ecdsa` |
| `sign_deterministic` | `signerl_api_SUITE:sign_deterministic` |
| `sign_uses_input_prolog_binary_and_file` | `signerl_api_SUITE:sign_uses_input_prolog_binary_and_file` |
| `sign_missing_prolog_binary_returns_error` | `signerl_api_SUITE:sign_missing_prolog_binary_returns_error` |
| `sign_invalid_prolog_file_returns_error` | `signerl_api_SUITE:sign_invalid_prolog_file_returns_error` |
| `sign_returns_error_with_unsupported_hash` | `signerl_api_SUITE:sign_returns_error_with_unsupported_hash` |
| `sign_returns_error_with_unsupported_key` | `signerl_api_SUITE:sign_returns_error_with_unsupported_key` |
| `sign_returns_file_error_with_missing_message_file` | `signerl_api_SUITE:sign_returns_file_error_with_missing_message_file` |
| `sign_returns_file_error_with_missing_key_file` | `signerl_api_SUITE:sign_returns_file_error_with_missing_key_file` |
| `sign_returns_error_with_invalid_pem_key_file` | `signerl_api_SUITE:sign_returns_error_with_invalid_pem_key_file` |
| `sign4_returns_file_error_with_missing_message_file` | `signerl_api_SUITE:sign4_returns_file_error_with_missing_message_file` |
| `sign4_returns_file_error_with_missing_key_file` | `signerl_api_SUITE:sign4_returns_file_error_with_missing_key_file` |
| `verify_missing_prolog_binary_returns_error` | `signerl_api_SUITE:verify_missing_prolog_binary_returns_error` |
| `verify_invalid_prolog_file_returns_error` | `signerl_api_SUITE:verify_invalid_prolog_file_returns_error` |
| `verify_returns_error_without_signature_element` | `signerl_api_SUITE:verify_returns_error_without_signature_element` |
| `verify_returns_error_without_signature_value` | `signerl_api_SUITE:verify_returns_error_without_signature_value` |
| `verify_returns_error_with_empty_signature_value` | `signerl_api_SUITE:verify_returns_error_with_empty_signature_value` |
| `verify_returns_error_with_invalid_base64_signature_value` | `signerl_api_SUITE:verify_returns_error_with_invalid_base64_signature_value` |
| `verify_returns_error_with_self_closing_signature_value` | `signerl_api_SUITE:verify_returns_error_with_self_closing_signature_value` |
| `verify_returns_error_without_object` | `signerl_api_SUITE:verify_returns_error_without_object` |
| `verify_returns_error_without_qualifying_properties` | `signerl_api_SUITE:verify_returns_error_without_qualifying_properties` |
| `verify_returns_error_without_signed_properties` | `signerl_api_SUITE:verify_returns_error_without_signed_properties` |
| `verify_returns_error_without_signed_signature_properties` | `signerl_api_SUITE:verify_returns_error_without_signed_signature_properties` |
| `verify_returns_error_without_signing_time` | `signerl_api_SUITE:verify_returns_error_without_signing_time` |
| `verify_returns_error_with_invalid_signing_time` | `signerl_api_SUITE:verify_returns_error_with_invalid_signing_time` |
| `verify_returns_error_with_self_closing_signing_time` | `signerl_api_SUITE:verify_returns_error_with_self_closing_signing_time` |
| `verify_returns_error_with_unsupported_hash` | `signerl_api_SUITE:verify_returns_error_with_unsupported_hash` |
| `verify_returns_file_error_with_missing_signed_message_file` | `signerl_api_SUITE:verify_returns_file_error_with_missing_signed_message_file` |
| `verify_returns_file_error_with_missing_key_file` | `signerl_api_SUITE:verify_returns_file_error_with_missing_key_file` |
| `verify_returns_error_with_invalid_pem_key_file` | `signerl_api_SUITE:verify_returns_error_with_invalid_pem_key_file` |
| `verify_returns_false_with_wrong_signature_value` | `signerl_api_SUITE:verify_returns_false_with_wrong_signature_value` |
| `verify_fails_on_modified_message` | `signerl_api_SUITE:verify_fails_on_modified_message` |
| `verify_fails_on_modified_signing_time` | `signerl_api_SUITE:verify_fails_on_modified_signing_time` |
| `verify_fails_with_wrong_keys` | `signerl_api_SUITE:verify_fails_with_wrong_keys` |
| `sign_with_certificate_includes_keyinfo` | `signerl_api_SUITE:sign_with_certificate_includes_keyinfo` |
| `sign_without_certificate_omits_keyinfo` | `signerl_api_SUITE:sign_without_certificate_omits_keyinfo` |
| `sign_with_certificate_roundtrip_rsa` | `signerl_api_SUITE:sign_with_certificate_roundtrip_rsa` |
| `sign_with_certificate_roundtrip_ecdsa` | `signerl_api_SUITE:sign_with_certificate_roundtrip_ecdsa` |
| `sign_with_certificate_from_key_file` | `signerl_api_SUITE:sign_with_certificate_from_key_file` |
| `sign_with_certificate_from_message_file` | `signerl_api_SUITE:sign_with_certificate_from_message_file` |
| `verify_extracts_certificate_from_keyinfo` | `signerl_api_SUITE:verify_extracts_certificate_from_keyinfo` |
| `verify_extracts_no_keyinfo_when_absent` | `signerl_api_SUITE:verify_extracts_no_keyinfo_when_absent` |
| `sign_with_certificate_includes_signing_certificate_v2` | `signerl_api_SUITE:sign_with_certificate_includes_signing_certificate_v2` |
| `sign_without_certificate_omits_signing_certificate_v2` | `signerl_api_SUITE:sign_without_certificate_omits_signing_certificate_v2` |
| `sign_with_certificate_extracts_cert_digest` | `signerl_api_SUITE:sign_with_certificate_extracts_cert_digest` |
| `verify_fails_with_tampered_cert_digest` | `signerl_api_SUITE:verify_fails_with_tampered_cert_digest` |
| `verify_succeeds_with_cert_v2_but_no_keyinfo_cert` | `signerl_api_SUITE:verify_succeeds_with_cert_v2_but_no_keyinfo_cert` |
| `verify_fails_with_mismatched_cert_digest_method` | `signerl_api_SUITE:verify_fails_with_mismatched_cert_digest_method` |
| `verify_independent_c14n11_signature` | `signerl_api_SUITE:verify_independent_c14n11_signature` |
| `verify_independent_exc_c14n_signature` | `signerl_api_SUITE:verify_independent_exc_c14n_signature` |
| `c14n_idempotent_after_sign` | `signerl_api_SUITE:c14n_idempotent_after_sign` |
| `sign_with_high_serial_cert_encodes_issuer_serial` | `signerl_cert_test:sign_with_high_serial_cert_encodes_issuer_serial_test` |
| `xades_xml_returns_error_with_non_signature_input` | `signerl_xades_xml_test:xades_xml_returns_error_with_non_signature_input_test` |
| `is_signature_element_shared` | `signerl_xml_test:is_signature_element_shared_test` |
| `to_file_writes_and_reads_back` | `signerl_xml_SUITE:to_file_writes_and_reads_back` |
| `export_fragment_returns_binary` | `signerl_xml_test:export_fragment_returns_binary_test` (existing duplicate) |
| `parse_prolog_rejects_bom` | `signerl_xml_test:parse_prolog_rejects_bom_test` (existing duplicate) |
| `single_text_returns_binary_and_list` | `signerl_xml_test:single_text_handles_binary_list_and_invalid_shapes_test` (existing duplicate) |
| `single_text_returns_not_found` | `signerl_xml_test:single_text_handles_binary_list_and_invalid_shapes_test` (existing duplicate) |

### signerl_c14n_SUITE

| Original case | Destination |
| --- | --- |
| `empty_element_expansion` | `signerl_c14n_test:empty_element_expansion_test` |
| `self_closing_to_start_end` | `signerl_c14n_test:self_closing_to_start_end_test` |
| `preserves_text_content` | `signerl_c14n_test:preserves_text_content_test` |
| `preserves_whitespace_in_text` | `signerl_c14n_test:preserves_whitespace_in_text_test` |
| `nested_elements` | `signerl_c14n_test:nested_elements_test` |
| `multiple_children` | `signerl_c14n_test:multiple_children_test` |
| `sorts_namespace_declarations` | `signerl_c14n_test:sorts_namespace_declarations_test` |
| `eliminates_superfluous_ns_decls` | `signerl_c14n_test:eliminates_superfluous_ns_decls_test` |
| `namespace_inheritance` | `signerl_c14n_test:namespace_inheritance_test` |
| `default_namespace` | `signerl_c14n_test:default_namespace_test` |
| `attribute_sorting_by_ns_uri` | `signerl_c14n_test:attribute_sorting_by_ns_uri_test` |
| `mixed_ns_and_regular_attrs` | `signerl_c14n_test:mixed_ns_and_regular_attrs_test` |
| `unprefixed_attrs_sort_before_prefixed` | `signerl_c14n_test:unprefixed_attrs_sort_before_prefixed_test` |
| `escapes_text_ampersand` | `signerl_c14n_test:escapes_text_ampersand_test` |
| `escapes_text_lt` | `signerl_c14n_test:escapes_text_lt_test` |
| `escapes_text_gt` | `signerl_c14n_test:escapes_text_gt_test` |
| `escapes_text_cr` | `signerl_c14n_test:escapes_text_cr_test` |
| `escapes_attr_ampersand` | `signerl_c14n_test:escapes_attr_ampersand_test` |
| `escapes_attr_lt` | `signerl_c14n_test:escapes_attr_lt_test` |
| `escapes_attr_quot` | `signerl_c14n_test:escapes_attr_quot_test` |
| `escapes_attr_whitespace_chars` | `signerl_c14n_test:escapes_attr_whitespace_chars_test` |
| `no_xml_declaration` | `signerl_c14n_test:no_xml_declaration_test` |
| `binary_text_child` | `signerl_c14n_test:binary_text_child_test` |
| `attr_value_types` | `signerl_c14n_test:attr_value_types_test` |
| `remove_signature_from_root` | `signerl_c14n_test:remove_signature_from_root_test` |
| `remove_signature_preserves_other_children` | `signerl_c14n_test:remove_signature_preserves_other_children_test` |
| `remove_signature_no_signature_present` | `signerl_c14n_test:remove_signature_no_signature_present_test` |
| `exc_c14n_omits_unused_ns` | `signerl_c14n_test:exc_c14n_omits_unused_ns_test` |
| `exc_c14n_keeps_visibly_used_ns` | `signerl_c14n_test:exc_c14n_keeps_visibly_used_ns_test` |
| `exc_c14n_propagates_ns_to_children` | `signerl_c14n_test:exc_c14n_propagates_ns_to_children_test` |
| `exc_c14n_binary_text_child` | `signerl_c14n_test:exc_c14n_binary_text_child_test` |
| `exc_c14n_default_namespace` | `signerl_c14n_test:exc_c14n_default_namespace_test` |
| `exc_c14n_ns_already_in_output_scope` | `signerl_c14n_test:exc_c14n_ns_already_in_output_scope_test` |
| `c14n11_emits_all_ns_decls` | `signerl_c14n_test:c14n11_emits_all_ns_decls_test` |
| `canonicalize_1_defaults_to_c14n11` | `signerl_c14n_test:canonicalize_1_defaults_to_c14n11_test` |
| `interop_simple_attrs` | `signerl_c14n_interop_SUITE:interop_simple_attrs` |
| `interop_namespaces` | `signerl_c14n_interop_SUITE:interop_namespaces` |
| `interop_nested_ns` | `signerl_c14n_interop_SUITE:interop_nested_ns` |
| `interop_escaping` | `signerl_c14n_interop_SUITE:interop_escaping` |
| `interop_default_ns` | `signerl_c14n_interop_SUITE:interop_default_ns` |
| `interop_mixed_content` | `signerl_c14n_interop_SUITE:interop_mixed_content` |
| `interop_dsig_like` | `signerl_c14n_interop_SUITE:interop_dsig_like` |

### signerl_signed_properties_SUITE

| Original case | Destination |
| --- | --- |
| `extract_accepts_binary_signing_time` | `signerl_signed_properties_test:extract_accepts_binary_signing_time_test` |
| `extract_returns_error_with_non_byte_list_signing_time` | `signerl_signed_properties_test:extract_returns_error_with_non_byte_list_signing_time_test` |
| `extract_returns_error_with_non_text_signing_time` | `signerl_signed_properties_test:extract_returns_error_with_non_text_signing_time_test` |
| `extract_returns_error_with_duplicate_signing_time_property` | `signerl_signed_properties_test:extract_returns_error_with_duplicate_signing_time_property_test` |
| `extract_returns_error_without_signing_time` | `signerl_signed_properties_test:extract_returns_error_without_signing_time_test` |
| `extract_accepts_signing_certificate_v2_with_issuer_serial` | `signerl_signed_properties_test:extract_accepts_signing_certificate_v2_with_issuer_serial_test` |
| `extract_accepts_signing_certificate_v2_without_issuer_serial` | `signerl_signed_properties_test:extract_accepts_signing_certificate_v2_without_issuer_serial_test` |
| `extract_returns_error_with_empty_signing_certificate_v2` | `signerl_signed_properties_test:extract_returns_error_with_empty_signing_certificate_v2_test` |
| `extract_returns_error_with_missing_cert_digest` | `signerl_signed_properties_test:extract_returns_error_with_missing_cert_digest_test` |
| `extract_returns_error_with_invalid_digest_value` | `signerl_signed_properties_test:extract_returns_error_with_invalid_digest_value_test` |
| `extract_returns_error_with_duplicate_signing_certificate_v2` | `signerl_signed_properties_test:extract_returns_error_with_duplicate_signing_certificate_v2_test` |
| `extract_returns_error_with_missing_digest_method` | `signerl_signed_properties_test:extract_returns_error_with_missing_digest_method_test` |
| `extract_accepts_binary_digest_value` | `signerl_signed_properties_test:extract_accepts_binary_digest_value_test` |
| `extract_returns_error_with_non_byte_list_digest_value` | `signerl_signed_properties_test:extract_returns_error_with_non_byte_list_digest_value_test` |
| `extract_returns_error_with_non_text_digest_value` | `signerl_signed_properties_test:extract_returns_error_with_non_text_digest_value_test` |
| `extract_returns_error_with_empty_binary_digest_value` | `signerl_signed_properties_test:extract_returns_error_with_empty_binary_digest_value_test` |
| `extract_returns_error_with_invalid_base64_digest_value` | `signerl_signed_properties_test:extract_returns_error_with_invalid_base64_digest_value_test` |
| `extract_ignores_invalid_base64_issuer_serial_v2` | `signerl_signed_properties_test:extract_ignores_invalid_base64_issuer_serial_v2_test` |
| `extract_accepts_implied_policy` | `signerl_signed_properties_test:extract_accepts_implied_policy_test` |
| `extract_accepts_explicit_policy_with_digest` | `signerl_signed_properties_test:extract_accepts_explicit_policy_with_digest_test` |
| `extract_accepts_explicit_policy_with_description` | `signerl_signed_properties_test:extract_accepts_explicit_policy_with_description_test` |
| `extract_accepts_explicit_policy_with_binary_identifier` | `signerl_signed_properties_test:extract_accepts_explicit_policy_with_binary_identifier_test` |
| `extract_returns_error_with_empty_policy_identifier` | `signerl_signed_properties_test:extract_returns_error_with_empty_policy_identifier_test` |
| `extract_returns_error_with_missing_policy_id` | `signerl_signed_properties_test:extract_returns_error_with_missing_policy_id_test` |
| `extract_returns_error_with_missing_policy_hash` | `signerl_signed_properties_test:extract_returns_error_with_missing_policy_hash_test` |
| `extract_returns_error_with_malformed_policy_hash` | `signerl_signed_properties_test:extract_returns_error_with_malformed_policy_hash_test` |
| `extract_returns_error_with_missing_policy_identifier_text` | `signerl_signed_properties_test:extract_returns_error_with_missing_policy_identifier_text_test` |
| `extract_returns_error_with_non_text_policy_identifier` | `signerl_signed_properties_test:extract_returns_error_with_non_text_policy_identifier_test` |
| `extract_ignores_non_text_policy_description` | `signerl_signed_properties_test:extract_ignores_non_text_policy_description_test` |
| `extract_accepts_binary_policy_description` | `signerl_signed_properties_test:extract_accepts_binary_policy_description_test` |
| `extract_returns_error_with_duplicate_policy` | `signerl_signed_properties_test:extract_returns_error_with_duplicate_policy_test` |
| `extract_accepts_full_production_place` | `signerl_signed_properties_test:extract_accepts_full_production_place_test` |
| `extract_accepts_partial_production_place` | `signerl_signed_properties_test:extract_accepts_partial_production_place_test` |
| `extract_accepts_empty_production_place` | `signerl_signed_properties_test:extract_accepts_empty_production_place_test` |
| `extract_accepts_binary_production_place` | `signerl_signed_properties_test:extract_accepts_binary_production_place_test` |
| `extract_skips_non_text_place_fields` | `signerl_signed_properties_test:extract_skips_non_text_place_fields_test` |
| `extract_skips_non_byte_list_place_fields` | `signerl_signed_properties_test:extract_skips_non_byte_list_place_fields_test` |
| `extract_skips_unknown_place_elements` | `signerl_signed_properties_test:extract_skips_unknown_place_elements_test` |
| `extract_returns_error_with_duplicate_production_place` | `signerl_signed_properties_test:extract_returns_error_with_duplicate_production_place_test` |
| `extract_accepts_claimed_roles` | `signerl_signed_properties_test:extract_accepts_claimed_roles_test` |
| `extract_accepts_certified_roles` | `signerl_signed_properties_test:extract_accepts_certified_roles_test` |
| `extract_accepts_both_role_types` | `signerl_signed_properties_test:extract_accepts_both_role_types_test` |
| `extract_skips_non_text_role_items` | `signerl_signed_properties_test:extract_skips_non_text_role_items_test` |
| `extract_skips_non_matching_role_items` | `signerl_signed_properties_test:extract_skips_non_matching_role_items_test` |
| `extract_returns_error_with_empty_signer_role` | `signerl_signed_properties_test:extract_returns_error_with_empty_signer_role_test` |
| `extract_returns_error_with_duplicate_signer_role` | `signerl_signed_properties_test:extract_returns_error_with_duplicate_signer_role_test` |
| `extract_accepts_data_object_format_with_mime_type` | `signerl_signed_properties_test:extract_accepts_data_object_format_with_mime_type_test` |
| `extract_accepts_data_object_format_minimal` | `signerl_signed_properties_test:extract_accepts_data_object_format_minimal_test` |
| `extract_accepts_multiple_data_object_formats` | `signerl_signed_properties_test:extract_accepts_multiple_data_object_formats_test` |
| `extract_returns_error_with_missing_object_reference` | `signerl_signed_properties_test:extract_returns_error_with_missing_object_reference_test` |
| `extract_accepts_data_object_format_with_all_fields` | `signerl_signed_properties_test:extract_accepts_data_object_format_with_all_fields_test` |
| `extract_skips_non_text_format_fields` | `signerl_signed_properties_test:extract_skips_non_text_format_fields_test` |
| `extract_ignores_unknown_data_object_elements` | `signerl_signed_properties_test:extract_ignores_unknown_data_object_elements_test` |
| `extract_accepts_commitment_type_with_all_scope` | `signerl_signed_properties_test:extract_accepts_commitment_type_with_all_scope_test` |
| `extract_accepts_commitment_type_with_references` | `signerl_signed_properties_test:extract_accepts_commitment_type_with_references_test` |
| `extract_accepts_commitment_type_minimal` | `signerl_signed_properties_test:extract_accepts_commitment_type_minimal_test` |
| `extract_accepts_multiple_commitment_types` | `signerl_signed_properties_test:extract_accepts_multiple_commitment_types_test` |
| `extract_returns_error_with_missing_commitment_type_id` | `signerl_signed_properties_test:extract_returns_error_with_missing_commitment_type_id_test` |
| `extract_returns_error_with_missing_commitment_identifier_text` | `signerl_signed_properties_test:extract_returns_error_with_missing_commitment_identifier_text_test` |
| `extract_accepts_all_optional_properties` | `signerl_signed_properties_test:extract_accepts_all_optional_properties_test` |
| `extract_ignores_unknown_signed_signature_properties` | `signerl_signed_properties_test:extract_ignores_unknown_signed_signature_properties_test` |
| `extract_returns_error_with_invalid_signature_element` | `signerl_signed_properties_test:extract_returns_error_with_invalid_signature_element_test` |
| `extract_ignores_unknown_data_object_property_types` | `signerl_signed_properties_test:extract_ignores_unknown_data_object_property_types_test` |
| `extract_ignores_non_tuple_data_object_elements` | `signerl_signed_properties_test:extract_ignores_non_tuple_data_object_elements_test` |
| `extract_returns_error_with_non_byte_list_policy_identifier` | `signerl_signed_properties_test:extract_returns_error_with_non_byte_list_policy_identifier_test` |
| `find_data_obj_props_returns_error_for_non_signature` | `signerl_signed_properties_test:find_data_obj_props_returns_error_for_non_signature_test` |
