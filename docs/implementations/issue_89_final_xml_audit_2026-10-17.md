# Final xmlan ownership audit — #89

Tracking: https://github.com/bormilan/signerl/issues/89

## Changes and acceptance reasoning

`test/signerl_xmlan_ownership_SUITE.erl` adds two executable ownership checks to
native tall/CI. They require the compatibility modules to contain only 18 direct
argument-preserving delegates plus the three documented signature operations;
all six aliases remain exported and transparent. The legacy header only forwards
to the dependency. Compiled imports enforce no direct xmerl/dynamic apply, local
signature-only compatibility calls and public xmlan exports. Application/config/
lock checks enforce an immutable matching HTTPS pin and no reverse dependency.
`test/xmlan_audit.hrl` names the static public API/type inventories.

The acceptance report, README, migration contract, fixture provenance and test
responsibilities document source/test ownership, the exact revision, public
usage, validation and post-merge closure. Production sources, public behavior,
original goldens, dependency pin and lockfile are unchanged.

## Removal of standalone test application

The user requested complete removal of the external integration test. Removed
`test/signerl_external_consumer.erl`, `test/xmlan_contract_consumer.erl`,
`scripts/check_external_consumer.sh` and `scripts/check_dependency_tree.sh`, the
extra CI step and its matrix-strategy change, script attributes and obsolete
lint exemptions. No test application
is generated, no fresh Signerl installation is performed by CI, and no separate
external Dialyzer check remains.

The existing frozen regression assertions now run directly in
`signerl_xmlan_contract_SUITE`. Its startup case checks only installed application
startup in a fresh VM, without loading a standalone test module. The normal
public API, equivalence, compatibility and ownership suites retain their coverage.
Documentation and issue/PR scope are updated to remove the external gate.

## Investigation and validation

- Confirmed PR #92 merged at `cf4fd4f80822d30e7c1154e43b73941d7ecd7e55` and
  issue #88 actually closed. All #83–#88 issues are closed; only #89 remains.
  The exact validated xmlan pin is `1fe39f6d414217584f514e70e43b8e7b4171f1ef`.
- Four ownership negative probes reject a hidden helper, swapped delegate
  arguments, direct xmerl import and private xmlan import; all restored.
- Preprocessed AST audit confirms all 104 functions in the other eight Signerl
  modules match baseline after retargeting public XML calls. All 41 generic XML
  and 30 generic C14N functions are preserved in xmlan.
- The executable absence/reference probe failed before removal and passes after
  removal: all four files and their active CI/configuration/documentation wiring
  are absent; the normal CI tall gate remains. Updated document links are valid.
- Targeted Common Test: all six contract/ownership cases pass. Moving the frozen
  assertions into one suite exposed duplicated fixture-loading code in lint; a
  shared assertion helper resolves it without discarding assertions. The affected
  suites pass again after that change.
- Native complete tests, flint, Dialyzer, final tall and explicit test-profile
  cover pass: 150 EUnit + 86 CT = 236 cases, all ten production modules and total
  100% coverage, no skipped tests or required checks.
- All six latest-head Signerl CI jobs must pass tall before merge; their updated
  results are recorded in PR #93 after publishing this removal.
- Exact-pin xmlan is unchanged: native tall and all six jobs passed with 259
  tests, 100% coverage and no required skips (run `39013046603`).

## Recovery

Persistent attached worktree:
`/Users/milanbor/.codex/worktrees/signerl-issue-56/signerl`, branch
`codex/issue-89-final-xml-audit`.

Recovery outside temporary storage:
`/Users/milanbor/projects/signerl/.recovery/issue-89/` preserves the earlier
commits/evidence. The `remove-consumer/` directory holds this revision's tracked
diff, source archive and validation logs; the executable removal probe is
`remove-consumer-probe.py` in its parent. Recovery archives exclude generated
keys/certificates, the historical checkout and build output. The original
checkout's user changes remain untouched. Milestone closure waits for confirmed
merge and actual issue/check verification.
