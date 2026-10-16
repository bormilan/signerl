# xmlan extraction contract (#83)

This is the implementation contract for [XML extraction into xmlan](https://github.com/bormilan/signerl/milestone/6).
The baseline is merged Signerl `dev` commit
`5927e41bab8674b875c51df1a1ec956d42676992` (PRs #80/#81/#82).
The extraction changes ownership, while preserving the supported public behavior.
No XML implementation has moved in #83.

## Public API and ownership

The Erlang application is `xmlan`. Its generic tree/parser/serializer module is
`xmlan`; its canonicalization module is `xmlan_c14n`. Retain current function
names, arities, argument order, return values, and transparent representations.
Signerl's existing exports remain available as direct delegates or type aliases.
xmlan production sources must not import Signerl or contain XMLDSig/XAdES names,
URIs, reference rules, or signature-removal policy.

| Existing export | Future implementation | Observable contract and callers |
| --- | --- | --- |
| `signerl_xml:parse_binary/1` | `xmlan:parse_binary/1` | `{ok, Tree}` or `{error, invalid_xml}`; signing/verification, XML/API/interop tests. |
| `signerl_xml:parse_file/1` | `xmlan:parse_file/1` | Returns a tree; failed reads/parses raise the existing badmatch. XML file tests and lower-level consumers. |
| `signerl_xml:parse_prolog/1` | `xmlan:parse_prolog/1` | Returns the original declaration as `{ok, [String]}` or `invalid_prolog`; `signerl:sign_impl/5`. |
| `signerl_xml:export/2` | `xmlan:export/2` | `(Prolog, Tree)` returns UTF-8 bytes with one appended LF; public signing and reconstruction tests. |
| `signerl_xml:export_fragment/1` | `xmlan:export_fragment/1` | Adds `<?xml version="1.0"?>`, without an appended LF; lower-level XML tests/consumers. |
| `signerl_xml:to_file/2` | `xmlan:to_file/2` | `(Path, Bytes)` returns the existing `file:write_file/2` result, including file errors; XML CT. |
| `signerl_xml:add_new_element/2` | `xmlan:add_new_element/2` | `(NewElement, Tree)` appends one child, preserving attributes/content/order; public signing. |
| `signerl_xml:find_path/2` | `xmlan:find_path/2` | A nonempty lexical-binary or expanded-name path selects unique direct children; absent/ambiguous nodes return `not_found`; verifier and XAdES lookups. |
| `signerl_xml:find_children/2` | `xmlan:find_children/2` | Expanded-name selector returns matching direct children with namespace context in order; reference extraction. |
| `signerl_xml:namespace_context/2` | `xmlan:namespace_context/2` | `(Attributes, ParentMap)` resolves declarations plus implicit XML/empty-default bindings; builders, extraction, transforms. |
| `signerl_xml:with_namespace_context/2` | `xmlan:with_namespace_context/2` | `(Tree, ParentMap)` appends missing nonempty inherited declarations; local bindings win; signed fragment construction/extraction. |
| `signerl_xml:expanded_name/2` | `xmlan:expanded_name/2` | `(Tree, ParentMap)` returns `{URI, Local}`; undeclared prefixes on caller-built trees yield `undefined`; transform and signature identity checks. |
| `signerl_xml:expanded_names/1` | `xmlan:expanded_names/1` | Projects element names with inherited bindings; attributes/text/order stay unchanged; SignedProperties metadata validation. |
| `signerl_xml:single_text/1` | `xmlan:single_text/1` | One binary/list text child becomes `{ok, UTF8Binary}`; other shapes return `not_found`; digest/text extraction. |
| `signerl_xml:attr_value/2` | `xmlan:attr_value/2` | `(BinaryKey, Attributes)` returns the first exact value or `missing_attribute`; reference/property extraction. |
| `signerl_xml:attr_value_or_undefined/2` | `xmlan:attr_value_or_undefined/2` | Same exact lookup with a direct value or `undefined`; optional reference metadata. |
| `signerl_c14n:canonicalize/1` | `xmlan_c14n:canonicalize/1` | Defaults to `c14n11`, returns canonical UTF-8 bytes; builder/digest calls and consumers. |
| `signerl_c14n:canonicalize/2` | `xmlan_c14n:canonicalize/2` | Supports `c14n11` and `exc_c14n`; existing invalid-input exceptions remain; SignedInfo verification. |
| `signerl_xml:is_signature_element/1` | Signerl, existing export | Uses empty parent context and XMLDSig expanded identity; XAdES root validation. |
| `signerl_xml:is_signature_element/2` | Signerl, existing export | Uses supplied parent context and local overrides; public signature extraction. Delegate generic name resolution to xmlan. |
| `signerl_c14n:remove_signature_elements/1` | Signerl, existing export | Removes only matching immediate children of the supplied root, resolving inherited/local namespaces; preserves text, nested descendants and lookalikes. Delegate context/identity helpers, retain the enveloped-transform policy. |

Keep `signerl:sign/3`, `sign/4`, `sign/5`, `verify/3`, and all other existing
Signerl module exports. Binary XML versus character-list file paths, decoded
keys versus key-file paths, certificate DER/`undefined`, controlled time, file
errors, malformed XML/prolog errors, and cryptographic boolean results retain
their current meanings. `sign/3` and `sign/4` still use current UTC time;
`sign/5` provides a reproducible timestamp. Do not change supported hashes,
RSA/ECDSA behavior, certificate/property rules, or failure precedence here.

## Transparent types and include compatibility

Alias these exported types without making them opaque:

| Signerl type | xmlan owner/type |
| --- | --- |
| `signerl_xml:simplified_xml/0` | `xmlan:simplified_xml/0` |
| `signerl_xml:attribute_value/0` | `xmlan:attribute_value/0` |
| `signerl_xml:expanded_xml/0` | `xmlan:expanded_xml/0` |
| `signerl_xml:expanded_name/0` | `xmlan:expanded_name/0` |
| `signerl_xml:namespace_context/0` | `xmlan:namespace_context/0` |
| `signerl_c14n:c14n_mode/0` | `xmlan_c14n:c14n_mode/0` |

A simplified tree is `{UTF8BinaryName, [{UTF8BinaryName, Value}], Children}`.
Values are Unicode character lists, UTF-8 binaries, integers, or atoms. Children
are trees, character lists, or binaries. Parsing produces character-list values;
caller-built trees preserve their representations until serialization. The
unexported recursive `simplified_xml_item/0` moves with the tree type. Expanded
names are `{BinaryURI | undefined, BinaryLocal}` and context maps have binary
prefixes/URIs. Preserve tuple construction, pattern matching, and external
Dialyzer compatibility through remote transparent aliases.

Move all generic constants to `xmlan/include/xmlan.hrl`. If consumers include
`signerl_xml.hrl`, preserve that path with a direct `include_lib` forwarding to
the dependency header; keep no copied regexes/algorithms. XMLDSig/XAdES constants
in `signerl_dsig.hrl` remain in Signerl.

## Complete private-helper map

The groups below enumerate every function in the two baseline modules, including
private helpers. Public functions are mapped above; these implementation helpers
move with their corresponding operation. Private names are not a new public API.

| Baseline module/group | Helpers and arities | Future owner |
| --- | --- | --- |
| XML parser | `parse_binary/2`, `scan_xml/2`, `validate_remainder/1`, `xml_event/3`, `prepend_content/2`, `qualified_name/1` | `xmlan` parser implementation |
| XML namespace validation | `validate_namespaces/3`, `validate_attributes/3`, `validated_attribute/3`, `validate_binding/2`, `validated_name/3`, `validate_ncname/1` | `xmlan` namespace implementation |
| Encoding/prolog | `utf8_encoding/1`, `valid_prolog/1` | `xmlan` parser/export implementation |
| Tree lookup/context/projection | `find_namespace_path/3`, `matching_children/3`, `namespace_binding/2`, `resolve_name/2`, `namespace_attribute/1`, `expand_content/4`, `find_unique_child/2` | `xmlan` tree implementation |
| XML serialization | `export_element/1`, `export_content/3`, `export_attribute/1`, `export_character/2` | `xmlan` serializer implementation |
| C14N traversal | `initial_namespaces/0`, `c14n11_element/2`, `c14n11_child/2`, `exc_element/3`, `exc_child/3` | `xmlan_c14n` |
| C14N namespace handling | `exc_needed_decls/3`, `exc_need_emit/3`, `prefix_to_ns_decl/1`, `partition_attrs/1`, `partition_attrs/3`, `is_ns_decl/1`, `namespace_uri/1`, `merge_namespaces/2`, `new_namespace_decls/2`, `ns_decl_prefix/1`, `visibly_used_prefixes/2`, `extract_prefix/1` | `xmlan_c14n` |
| C14N ordering/rendering | `sort_ns_decls/1`, `sort_attributes/2`, `attr_sort_key/2`, `render_element/4`, `render_ns_decls/1`, `render_attributes/1` | `xmlan_c14n` |
| C14N escaping/values | `escape_attr_value/1`, `escape_attr_value/2`, `escape_text/1`, `escape_text/2`, `value_to_string/1` | `xmlan_c14n` |

Every macro in `include/signerl_xml.hrl` moves to xmlan:
`XML_NAMESPACE_URI`, `XMLNS_NAMESPACE_URI`, `XML_NCNAME_START_RE`, `XML_NCNAME_RE`,
`XML_EMPTY_NAMESPACE_PREFIX_RE`, `XML_PROLOG_EXTRACT_RE`, `XML_PROLOG_VALID_RE`,
`XML_ENCODING_EXTRACT_RE`, and `XML_ENTITY_RECURSE_LIMIT`.
The baseline direct implementation dependencies are `xmerl_sax_parser:stream/2`
and `xmerl_lib:export_text/1` / `export_attribute/1`. xmlan owns their runtime
application requirement; Signerl replaces its direct xmerl application dependency
with xmlan after all direct calls move.

## Caller migration

| Caller | Changes during integration | Code that stays in Signerl |
| --- | --- | --- |
| `signerl` | Parsing/prolog, insertion/export, SignedInfo canonicalization call xmlan directly. | Key/file dispatch, signature workflow, signature verification. |
| `signerl_signature` | Canonicalization and namespace context/materialization call xmlan. | XMLDSig/XAdES element construction, reference digests, certificate properties, algorithm routing, cryptography. |
| `signerl_verify` | Generic path/child/attribute/text/context/expanded-name and canonicalization calls use xmlan. | Signature selection, reference/transform/algorithm validation, certificate extraction, digest comparison, canonicalization URI-to-mode choice. |
| `signerl_signed_properties` | Expanded projection and attribute lookup use xmlan. | Property identities/cardinalities, dates, certificate metadata and semantic validation. |
| `signerl_xades_xml` | Generic path/context lookup delegates to xmlan. | XAdES paths, signature-root requirement and `missing_element` mapping. |
| Compatibility modules | Generic bodies become one direct call or transparent alias. | Signature recognition and enveloped signature removal only. |
| Test helpers/consumers | Generic test calls switch to xmlan in moved tests; retained compatibility probes continue using existing Signerl exports. | Signature builders/mutations, certificate fixtures and public API controls. |

## Baseline contract and test ownership matrix

The baseline has 336 EUnit and 90 CT cases. Preserve contracts and meaningful
assertions when splitting suites; matching the old count in each repository is
not a completion condition. Keep pure XML and protocol tests separate.

| Contract | Existing executable evidence | Future owner/evidence |
| --- | --- | --- |
| Transparent values, UTF-8 parsing/export, prologs, exact escaping/order | `signerl_xml_test`: caller construction, value representations, UTF-8/prolog/export cases; new frozen consumer corpus. | xmlan pure contracts; Signerl type/delegate consumer and public API integration. |
| Whitespace/mixed content/CDATA, XML line endings and references, 10,000-level export | `signerl_xml_test`: content/order/deep-tree cases; `signerl_api_SUITE`: content-preservation mutations. | xmlan parsing/export; retain Signerl actual-signature preservation/tamper checks. No new arbitrary-depth canonicalization guarantee. |
| Full-document consumption, encoding/BOM and DTD/PI restrictions | `signerl_xml_test`; XML CT file entry points; API suffix/prolog/encoding/DTD cases. | xmlan generic parser/file cases; Signerl sign/verify error boundaries. Parsing accepts UTF-8 BOM where tested; prolog extraction/signing still reject it. |
| QName/declaration/expanded-attribute constraints and literal lexical guard | `signerl_xml_test`: namespace constraint, Unicode, duplicate, and literal-text matrices. | xmlan; preserve absolute URI policy (except empty default undeclaration) and no rewriting lexical prefixes. |
| Namespace selectors, context on detached fragments, expanded projection | `signerl_xml_test`: qualified lookup, contextual lookup and expanded projection. | xmlan generic helpers; Signerl inherited signature/property fragments and cryptographic bytes. |
| Signature identity/removal by URI, aliases/defaults/rebindings/lookalikes | `is_signature_element_shared_test`, `namespace_signature_recognition_test_`, four `remove_signature_*` tests; verify/API cases. | Signerl; xmlan receives only generic namespace machinery. |
| C14N 1.1/Exclusive bytes, namespace/value normalization, implicit XML/default bindings, sorting/escaping and errors | `signerl_c14n_test` excluding four signature-removal cases; all 10 `signerl_c14n_interop_SUITE` cases and `examples/c14n/`. | xmlan, with xmllint comparisons in both modes where currently covered. A DSig-like generic fixture is allowed; no protocol awareness in production. |
| File I/O errors and external-resource rejection | All `signerl_xml_SUITE` cases except the combined atom/signature probe; controlled file/HTTP canaries. | xmlan parser/serializer/file cases; Signerl public file/key error dispatch stays covered. |
| No XML-name atom growth | `fresh_xml_names_do_not_grow_atoms` / `atom_name_probe` exercise parse/export/both C14N modes/sign/verify in a warmed isolated VM. | Split generic xmlan probe from Signerl's real dependency-backed sign/verify probe; retain zero growth in both batches. |
| Fixed-time signing, key/certificate/file inputs, errors | `signerl_api_SUITE`, `signerl_signature_test`, `signerl_utils_test`, certificate helpers; new frozen RSA verification/fresh-key output probe. | Signerl. RSA bytes remain identical for fixed inputs/key/cert/time; ECDSA is checked by verification. |
| Independent signatures, reconstruction, digests, tampering and wrong keys | `examples/independent/`, API interop/tamper groups, `signerl_verify_test`. | Signerl; use actual serialized XML and pinned xmlan, never substitute precomputed canonical data. |
| XAdES/certificate/date/reference/algorithm behavior | `signerl_signed_properties_test`, `signerl_verify_test`, `signerl_xades_xml_test`, cert/utils/signature tests. | Signerl without profile or failure-policy redesign. |
| Frozen parsed/export/canonical/signed output and lower-level caller contracts | `signerl_xmlan_contract_SUITE`, `xmlan_contract_consumer`, `examples/xmlan_migration/`. | Retain a Signerl dependency-backed consumer; move generic fixture checks to xmlan as appropriate without regenerating the baseline. |

The new fixture [provenance](../test/examples/xmlan_migration/README.md) records
exact outputs captured before extraction and original hashes. Only its public
verification key is committed. The consumer verifies the frozen signature, signs
with a fresh in-memory key, checks deterministic repeated output and verification,
and compares all serialized bytes except SignatureValue against the baseline.
For #88, compare the old baseline and extracted implementation using the same
freshly generated key/certificate/time in one validation run to require exact RSA
signature bytes without publishing or persisting a private key. This baseline
probe complements existing independent conformance/interoperability checks.
Do not update a golden to hide a migration difference.

## Executable consumer probes

The consumer only uses exported functions/types and ordinary OTP services; it
can run outside rebar's test VM and without test_helpers or generated certificates.
After `rebar3 compile`, from the checkout root (POSIX shell):

```sh
consumer_probe_dir="$(mktemp -d)"
erlc -pa _build/default/lib/signerl/ebin -pa _build/default/lib/xmlan/ebin \
  +debug_info -o "$consumer_probe_dir" test/xmlan_contract_consumer.erl
erl -noshell -enable-feature maybe_expr -pa "$consumer_probe_dir" \
  _build/default/lib/signerl/ebin _build/default/lib/xmlan/ebin \
  -eval 'ok = xmlan_contract_consumer:run("test/examples/xmlan_migration"), halt().'
```

`rebar3 ct --suite test/signerl_xmlan_contract_SUITE` runs the same assertions in
CI. External Dialyzer checking of the compiled consumer against production BEAMs
must remain clean, including caller-built tuples; an opaque replacement must
fail the negative type probe. The integration issue repeats this check against
Signerl's remote xmlan type aliases. A modified exported-byte golden must make
the consumer fail; the check cannot silently recapture expected output.

## Immutable dependency and delivery sequence

1. Merge #83 into Signerl `dev` after review and all six latest-commit CI jobs.
2. #84 bootstraps xmlan with real tree types/primitives and full native/CI gates.
   Establish xmlan's own contribution/default-branch workflow without changing
   Signerl's `dev` target. Preserve Apache-2.0 attribution and fixture provenance.
3. #85/#86 migrate parser/namespace/export and generic canonicalization with
   their tests, preserving the reviewed API and all current supported restrictions.
   Validate xmlan independently without Signerl sources or global plugin overrides.
4. After the extracted implementation merges and its exact commit passes native
   tall/100% coverage and all six jobs, #87 adds a Git dependency pinned to that
   full commit SHA and commits rebar's lockfile. The intended configuration is
   `{xmlan, {git, "https://github.com/bormilan/xmlan.git", {ref, "<validated-full-SHA>"}}}`.
   Replace the placeholder during integration, never use a moving branch or
   sibling path. A later release/tag can document the same immutable revision;
   publishing to Hex is not required here.
5. #87 removes generic Signerl bodies/constants and direct xmerl usage, updates
   callers/app startup/types/docs, and validates against the actual dependency.
   Only direct compatibility delegates/aliases and protocol operations remain.
6. #88 compares the frozen contracts and full security/API corpus; #89 audits
   source/compiled calls, exact dependency revisions and an external clean consumer.

Each implementation issue has its own focused PR and mandatory local gates;
no PR is automatically merged. Both repositories require native `rebar3 tall`,
100% production coverage, and OTP 26/27/28 on Ubuntu/Windows with no skipped
required checks. Signerl's final pin must match the exact validated xmlan code.
Closing keywords against `dev` may not close Signerl issues automatically because
its default branch is `main`; verify/close completed issues after confirmed merges.

The milestone is complete only when Signerl production sources contain no generic
parser, serializer, namespace validator/resolver, canonicalizer, or fallback copy,
and clean consumers exhibit the same supported behavior. Compatibility delegates
must call xmlan directly; they cannot hide a second maintained implementation.
Broader XML standards support and #64/#58/#59 profile/API/failure redesign remain
separate. Any intentional API removal requires separately approved scope.

## Integrated dependency (#87)

Signerl's configuration and generated lockfile pin xmlan
`1fe39f6d414217584f514e70e43b8e7b4171f1ef`, the reviewed #86 implementation with
native tall, 100% coverage, and all six CI jobs verified. That commit is reachable
from merged xmlan `dev`; it is used directly so the dependency SHA equals the
validated implementation SHA. No branch/path override is used.

Generic production callers/types now refer to xmlan directly. Legacy generic
exports are single-call delegates; public types are transparent remote aliases,
and `signerl_xml.hrl` only forwards to the dependency header. The signature
identity predicates and immediate-child enveloped-signature removal stay local.
Signerl starts xmlan, which starts xmerl; Signerl has no direct xmerl calls or
application requirement. Pure generic test ownership moved in #85/#86; Signerl
retains the dependency-backed protocol/API/consumer checks in `test/TESTS.md`.
The [#88 equivalence/security report](xmlan_equivalence_report.md) documents the
same-key comparison, public security canaries, and complete executable baseline
test map. The final #89 ownership/consumer audit remains separate.
