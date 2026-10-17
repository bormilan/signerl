# XML migration acceptance — #89

Generic XML parsing, serialization, tree/value helpers, namespace handling and
canonicalization are owned by [xmlan](https://github.com/bormilan/xmlan).
Signerl depends on the immutable Git revision
`1fe39f6d414217584f514e70e43b8e7b4171f1ef` in both `rebar.config` and `rebar.lock`.

## Final ownership

Signerl contains eight production modules for signing/verification, signature
construction/extraction, XMLDSig/XAdES rules, signed properties, certificates,
cryptography and time/file utilities. Its only local header is
`include/signerl_dsig.hrl`, containing signature identifiers/constants.

`signerl_dsig_utils` owns signature recognition by namespace URI/local name and
immediate-child enveloped-signature removal. These operations use xmlan's public
helpers; they do not implement a generic parser or canonicalizer.

The generic `signerl_xml` and `signerl_c14n` compatibility modules, their exported
type aliases and the `signerl_xml.hrl` forwarding include are removed. Code using
those generic APIs must call xmlan/xmlan_c14n and refer to xmlan's types directly.
The public `sign/3`, `sign/4`, `sign/5` and `verify/3` behavior is unchanged.

## Validation ownership

Signerl keeps tests of signing, verification, references, certificate properties,
signing time, signed-content preservation, tampering, independent signatures and
public API error propagation. xmlan is used to construct/inspect test documents.

The XML contract, equivalence, source-ownership and atom-growth suites, generic
frozen outputs/type probes, historical parser checkout/preparation script, external
application and related CI steps are removed. Generic XML tests are not moved
into another Signerl suite. Obsolete XML-only guides, implementation reports
and the parser task note are removed; earlier work remains in Git history.

The [test map](../test/TESTS.md) describes the remaining 150 EUnit and 70 Common
Test cases. Required local gates remain complete tests, 100% Signerl coverage,
flint, Dialyzer and final native tall; these pass locally with 220 cases and
100% coverage, without skips. All six OTP 26/27/28 Ubuntu/Windows jobs
must pass tall on the final PR head. xmlan's source and pinned revision are
unchanged by this cleanup; its own quality gates belong to that repository.

## Completion

Issues #83–#88 are already closed. Keep #89 and
[milestone #6](https://github.com/bormilan/signerl/milestone/6) open until this PR
merges. Then verify the merged implementation/checks, close #89 as completed if
needed (`dev` is not the default branch), confirm all linked issues are closed,
and close the milestone. No PR is automatically merged.

See the [implementation log](implementations/issue_89_final_xml_audit_2026-10-17.md)
for changes, validation and persistent recovery.
