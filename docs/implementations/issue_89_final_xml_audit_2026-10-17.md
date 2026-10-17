# Finish XML extraction and remove generic XML maintenance — #89

Tracking: https://github.com/bormilan/signerl/issues/89

## Scope and implementation

The user clarified that Signerl must not test or maintain xmlan's generic XML
behavior. This supersedes the earlier compatibility/consumer/ownership-test scope.

- Removed `src/signerl_xml.erl`, `src/signerl_c14n.erl` and the forwarded
  `include/signerl_xml.hrl`, including all generic delegates and type aliases.
- Moved only namespace-aware signature recognition and enveloped-signature
  removal into the existing `signerl_dsig_utils` module. Updated verifier/XAdES
  callers and moved their ten protocol-only EUnit cases to its test module.
- Deleted the XML contract, equivalence, ownership and atom-growth suites,
  `xmlan_audit.hrl`, migration golden corpus/manifests, historical baseline script
  and CI preparation step. No assertions from those suites are relocated.
- Removed the canonicalizer-idempotence case and direct parse-file assertions
  from the public API suite. The remaining cases exercise Signerl behavior.
- Moved UTF-8/content inputs to `test/examples/payloads`; they support actual
  signing/verification/tampering rather than standalone XML tests.
- Removed obsolete generic XML contract/equivalence guides, lint exceptions,
  fixture attributes and the parser-maintenance skill. Removed obsolete XML-only
  implementation reports and the parser task note; Git history preserves the prior
  work. Updated README, test map, acceptance report and issue/milestone/PR scope.

Generic callers now use xmlan's API/types directly. Removing the former generic
compatibility APIs/header is an intentional scope change requested by the user.
Public signing/verification interfaces, algorithms, certificates, supported
signature behavior and the immutable xmlan dependency pin are unchanged.

## Validation

Before implementation, the ten signature-only tests failed with `undef` against
their new utility-module location. The removal probe also failed on the generic
modules/header/tests/fixtures and baseline CI wiring, proving they were present.

After implementation, all ten signature-only unit cases pass. The removal probe
passes, payload files are byte-identical after their directory move, and current
document links are valid. Review confirms eight signature production modules,
one signature header, no direct xmerl use and no calls to removed modules.

Native clean/test/cover/flint/Dialyzer/final tall all pass: **150 EUnit + 70 CT =
220 cases, 100% coverage of every production module and total, no skips**. The
removed test-profile cache was reset so deleted suites cannot be loaded. No test
of dependency internals was added to restore coverage. The final six-job CI
result is recorded in PR #93 after publishing this revision.

## Recovery

Persistent implementation worktree:
`/Users/milanbor/.codex/worktrees/signerl-issue-56/signerl`, branch
`codex/issue-89-final-xml-audit`.

Recovery outside temporary storage:
`/Users/milanbor/projects/signerl/.recovery/issue-89/xml-cleanup/` holds tracked
changes, untracked source, source archive, removal probe and validation logs.
The earlier `remove-consumer/` recovery retains previous history/evidence. The
ignored historical baseline checkout is moved into this recovery directory;
there is no historical parser source left under Signerl's `priv/` directory.
Original-checkout user changes remain untouched. PR #93 targets dev; issue and
milestone closure wait for a confirmed merge and actual state verification.
