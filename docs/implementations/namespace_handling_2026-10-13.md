# Namespace-aware XML handling (#41)

## Changes and reasoning

XML tuple names stay lexical UTF-8 binaries. `signerl_xml` adds URI/local-name
selectors and a tail-recursive expanded-name projection for metadata validation.
Namespace selectors return fragments with inherited declarations so detaching
`SignedInfo` and `SignedProperties` retains their canonicalization context.
Signing hashes those contextual fragments while serializing the original tree.
Signature removal and extraction recognize XMLDSig by URI, preserving application
lookalikes and resolving local prefix/default-namespace redeclarations.

`signerl_verify`, `signerl_xades_xml`, and `signerl_signed_properties` use the
expanded names rather than fixed `ds:`/`xades:` spellings. Reference transforms
and certificate lookup preserve the namespace declarations on their containers.
Canonicalization starts with the implicit `xml` binding and empty default binding,
normalizes namespace value representations, and rejects relative namespace URIs.
Exclusive C14N reports missing prefix context rather than silently emitting an
undeclared name.

The SAX parser does not enforce all namespace constraints. An explicit tail
traversal validates declarations, qualified names, and expanded attribute
uniqueness before `parse_binary/1` accepts a document. Static Unicode NCName
patterns and URI constants live in `include/signerl_xml.hrl`. Original names,
attribute values, child order, and signed text are unchanged by this validation.

README documents namespace matching, parser failures, and contextual fragment
lookup. Test metadata fixtures now declare their namespaces. Independently signed
fixtures and hand-supplied canonical signature inputs validate prefix aliases,
default namespaces, inherited declarations, tampering, and wrong-URI lookalikes.
Both canonicalization modes are compared with xmllint for default undeclaration,
prefix rebinding, implicit XML attributes, and empty default context.

References: https://www.w3.org/TR/xml-names/ and XML 1.0 fifth-edition name productions.
Namespace URI matching uses exact, case-sensitive character sequences.

## Validation and review

Resumption baseline: XML tests reproduced 12 namespace-constraint failures.
Additional QName/reserved-prefix cases reproduced six more defects. The existing
integration failure was a non-unique fixture mutation; it now targets the signature
opening declaration. Idempotence uses a namespace selector to retain fragment context.
After parser validation, focused EUnit passed 281 cases; full tests passed
293 EUnit and 87 CT cases with no skips. Coverage exposed missing lexical-path and
malformed-transform cases; those regressions pass. A missing-context Exclusive C14N
regression failed before its fix. The clock-dependent padding branch is handled
separately in #56 rather than relying on the current second.

Dependencies: PR #80 resolves #56 and PR #81 resolves #27. The branch inherits
both exact validated commits (`d7b82a3`, then `4dc0599`) before the namespace
changes. All PRs target `dev`; merge #80, then #81, then the namespace PR. The constructor conflict was resolved by carrying both
ancestor namespace attributes and the supplied signing time. The namespace stash
is retained as an additional recovery copy until final validation.
Final native gates: passed; details below.
CI compatibility matrix: pending publication.

## Persistence

Worktree: `/Users/milanbor/.codex/worktrees/signerl-issue-41/signerl`.
Branch: `codex/issue-41-namespaces`.
Recovery snapshots and validation logs:
`/Users/milanbor/projects/signerl/.recovery/issue-41`.
Resumption snapshot: `resume-2026-10-13.patch`.


Review found that SAX also rewrites the invalid declaration `xmlns:` into `xmlns`,
losing the evidence needed by tree validation. A narrow lexical start-tag guard
rejects that spelling while consuming quoted attribute values and skipping
comments/CDATA. Three negative regressions and four literal-text positive controls
exercise this boundary; ordinary namespace declarations still use the tree walk.
The merged contract uses the shared exported attribute-value type for all XML
views and documents binary namespace values supported by this change.


The final review also found that the new C14N relative-URI rejection could escape
from public signing as an exception. Three parser regressions reproduced relative,
default-relative, and fragment namespace acceptance. Namespace declaration
validation now enforces absolute URIs (apart from default undeclaration), returning
`invalid_xml` through the public parser/sign/verify boundary. This is an explicit
supported-profile restriction documented in README. The lower-level canonicalizers
still reject relative namespace input supplied directly by tuple callers.


## Final validation

After all review fixes and prerequisite integration, native `rebar3 test` and
final `rebar3 tall` passed: 336 EUnit + 90 CT = 426 cases, no skips, 100% total
coverage. Separate `rebar3 as test cover`, `rebar3 flint`, and `rebar3 dialyzer`
passed. Formatting, lint, Xref, and project Dialyzer findings are clean.
The isolated production atom-growth regression ran; independent signature and
xmllint checks were not skipped. `git diff HEAD --check` passed.

Reviewed namespace lookup, reserved bindings, default/prefix redeclarations,
expanded attribute uniqueness, lexical QName information loss, inherited fragment
bindings, original-prefix hashing, encodings/prologs, and malformed transforms.
All actionable findings were fixed and retested. No blocking findings remain.
Fixture duplication and long literals were simplified; exported selector/context
types and the existing attribute-value type keep public contracts aligned.
The supported profile still uses one root-child signature and the existing
reference/property behavior; multi-signature/profile work remains in other issues.

Native runtime: installed OTP 28.4.2, pinned rebar3 3.25.1, isolated global config.
The six OTP 26/27/28 Ubuntu/Windows jobs will be verified after publication,
including the pinned OTP 28.5.0.7 runtime. The implementation log captures native
results at publication; final CI evidence is saved in the PR and recovery manifest.

Final recovery includes the tracked diff against `4dc0599`, untracked implementation
log archive, original named namespace stash, and command output in `.recovery/issue-41`.
