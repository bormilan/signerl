# Record the retained XAdES MVP profile — #64

## Decision and scope

The maintainer chose to keep XAdES signing-time and certificate properties.
Recorded the choice in issue #64 and milestone 0.3, replacing the pending
XMLDSig-versus-XAdES decision. Other incomplete acceptance criteria remain open.

Added `docs/signing_profile.md` and a README link. The contract selects one
enveloped RSA-SHA256 signature with SignedProperties/SigningTime, retained
certificate conveniences, explicit reference transforms and unique ID/target
relationships. It describes the existing signing/verification arities without
redesigning their failure policy. Current gaps and compatibility decisions are
explicitly assigned to #52/#54/#55/#58/#59; #56 is complete. ECDSA is not removed
or promoted to a complete XMLDSig implementation. xmlan retains generic XML work.

This is the profile-definition part of #64. It does not close #64 or claim to
implement the reference/certificate/property fixes owned by the other issues.
No production code, dependency pin, tests, fixtures or CI steps change.

## Investigation and validation

Read the public signing flow, builder, verifier, certificate/XAdES helpers,
existing protocol/API tests, and issues #52/#54/#55/#58/#64. Checked the W3C
XML Signature reference-processing and XAdES QualifyingProperties sources to
separate project profile choices from general standards requirements.

Document links and code fences pass validation. Reviewed current/target claims
against source and existing tests. Native full tests, explicit test-profile
coverage, flint, Dialyzer and final tall pass: **150 EUnit + 70 CT = 220 tests,
100% Signerl coverage, no skips**. Production code, dependency configuration,
tests, fixtures and CI are unchanged. All six latest-head CI results are recorded
in the PR after publishing. No artificial documentation-only unit test or external
consumer application is added.

## Recovery

Persistent attached worktree:
`/Users/milanbor/.codex/worktrees/signerl-issue-56/signerl`, branch
`codex/issue-64-xades-profile`.

Persistent recovery:
`/Users/milanbor/projects/signerl/.recovery/issue-64/` holds issue/milestone
updates, tracked diffs, untracked source archive and native/CI logs. Existing
original-checkout user changes remain untouched. The focused PR targets dev;
#64 stays open until all remaining profile criteria are implemented.
