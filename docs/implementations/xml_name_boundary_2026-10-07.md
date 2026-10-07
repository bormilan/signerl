# XML names without atom allocation (#61)

## Investigation and tests first

The SAX callback converts arbitrary element/attribute names to atoms. Namespace
declaration names pass through the same conversion. Names are now UTF-8
binaries throughout parsing, builders, lookup, export, and canonicalization.
The tuple shape and text/attribute values remain unchanged. The public XML
sign/verify API remains unchanged; lower-level Erlang tuple callers must migrate
name literals to binaries. Namespace URI matching remains #41.

Tests added before implementation cover exact Unicode binary names and names
longer than the atom length limit. A fresh-VM Common Test probe warms parsing,
export, both canonicalizers, signing and verification, then measures two batches
of 25 fresh name sets. Each includes ordinary/prefixed element and attribute
names, namespace declarations, and a malformed-input name. The separate VM
isolates the measurement, not production parsing. Before the fix, the two new
unit cases failed and each measured batch added 150 atoms (`[150,150]`). After
the fix, both batches add zero atoms (`[0,0]`).

## Implementation and review

- `src/signerl_xml.erl`: encode SAX names with `unicode:characters_to_binary/1`,
  retain UTF-8 names in export, and change the transparent tuple/lookup specs.
- `src/signerl_signature.erl`, `signerl_verify.erl`, `signerl_xades_xml.erl`, and
  `signerl_signed_properties.erl`: migrate XML-name literals and patterns to
  the consistent binary representation. A shared private digest-method
  constructor removes a repeated XML tuple. Error atoms, map keys, values, and
  signature/reference validation logic are unchanged.
- `src/signerl_c14n.erl`: decode binary names as Unicode character lists for
  existing namespace sorting/rendering. Canonical UTF-8 byte assertions remain.
- Existing tuple-based tests and `test_helpers.erl`: migrate XML names to binaries,
  preserving the previous observable XML/signature assertions. Raw XML and
  independent signature fixtures are unchanged.
- `README.md` and `test/TESTS.md`: document the lower-level API migration, test
  boundary, and interaction with entity and resource policies.

Review found no remaining arbitrary atom conversions in production SignErl.
Installed xmerl's UTF-8 SAX implementation keeps XML names as character lists;
its standalone conversion is restricted to `yes`/`no`, and its URI-scheme atom
conversion lies behind external DTD/entity processing that #39 rejects.
The matrix regression exercises the supported runtime versions rather than
assuming identical parser internals. An existing atom table lookup or a hybrid
atom/binary vocabulary is not used. Tuple shape, character values, qualified
prefix spelling, and canonical byte order remain stable.

The probe uses the application's disk ebin directory so parent-process coverage
instrumentation does not alter the child VM's code path. Export retains its
existing tail-recursive work stack; the now-redundant name conversion assignment
was removed. Lint identified larger duplicate ASTs after binary literal
expansion: the digest-method constructor and small test fixture helpers now
share those repeated structures. Missing/ambiguous lookup assertions are named
cases in one generator, increasing the EUnit count by one without changing the
assertions. No lint rule was suppressed. No unrelated recursion, namespace, or
validation refactor is included.

This intentionally changes lower-level XML tuple names and lookup arguments from
atoms to binaries. It does not add size/depth quotas or namespace URI matching
(#41). #39's DTD rejection and zero custom-entity expansion policy are retained.

Reference: [xmerl SAX name events](https://www.erlang.org/doc/apps/xmerl/xmerl_sax_parser.html#event/0).

## Validation

Native validation used OTP 28.4.2 and the repository-pinned rebar3 3.25.1,
erlfmt 1.8.0, and rebar3_lint/Elvis 5.0.4. The local OTP patch version differs
from the pinned CI OTP 28.5.0.7; compatibility is also checked by the six GitHub
jobs for OTP 26/27/28 on Ubuntu and Windows before merge.

- Tests first: `rebar3 eunit --module=signerl_xml_test` failed the two new name
  cases; the focused atom-growth Common Test failed with `[150,150]`.
- After implementation: `rebar3 eunit` and `rebar3 ct` passed. After lint/review
  adjustments, `rebar3 test` passed **221 EUnit + 82 CT = 303 cases**, no skips.
- `rebar3 as test cover`: **100%** for every production module and in total.
- `rebar3 flint`: passed after removing repeated structures and formatting the
  Unicode fixture. `rebar3 dialyzer`: passed with no project findings.
- Final native `rebar3 tall`: passed all **303 cases**, **100% coverage**,
  formatting/lint, Xref, and Dialyzer, with no skipped tests or suite errors.
- The bounded fresh-VM probe passed under normal CT and the aggregate coverage
  run. Existing independent signature fixtures and all nine `xmllint`
  canonicalization interoperability cases passed without fixture changes.
- Documentation links/counts and `git diff --check`: passed.

GitHub matrix results and the exact tested commit are recorded in the PR after
publication. The PR must not be merged until all six jobs pass on its latest
commit.

## Recovery

Persistent worktree: `/Users/milanbor/.codex/worktrees/signerl-issue-61/signerl`.
Recovery diff, untracked sources and logs:
`/Users/milanbor/projects/signerl/.recovery/issue-61`.
