# Linter upgrade and Elvis configuration migration (#63)

## Version and compatibility decision

Pin `rebar3_lint` 5.0.4, which pins `elvis_core` 5.0.4. Upstream GitHub release
metadata was checked on 2026-10-05. The latest stable version is 6.0.0, but its
minimum OTP is 27. Version 5.0.4 is the newest stable line compatible with the
retained OTP 26 target (both plugin and Elvis declare minimum OTP 26).
Keep the already selected rebar3 3.25.1 and the OTP 26/27/28 Ubuntu/Windows matrix.

Sources:
- https://github.com/project-fifo/rebar3_lint/releases/tag/5.0.4
- https://github.com/project-fifo/rebar3_lint/blob/5.0.4/rebar.config
- https://github.com/project-fifo/rebar3_lint/blob/6.0.0/rebar.config
- https://github.com/inaka/elvis_core/blob/5.0.4/MIGRATION.md
- https://github.com/inaka/elvis_core/blob/5.0.4/src/elvis_ruleset.erl

## Changes and rule review

- `rebar.config`: explicitly pin the compatible linter version.
- `elvis.config`: remove the old `elvis` wrapper; replace `dirs`/`filter` with
  `files` globs. Preserve the same source/test scope and `erl_files` ruleset.
  Remove the obsolete `elvis_config` ruleset: 5.x validates configuration
  directly, including unknown keys/rules/rulesets.
- Preserve the existing `private_data_types` exception for `signerl_xml` because
  callers inspect its exported simplified tree. Preserve the naming exception
  for `signerl_cert`, `signerl_cert_helpers`, and `signerl_cert_test` because
  OTP's ASN.1 records/fields have mandated mixed-case names. Add inline reasons.
  No new rule is disabled and tests retain the production ruleset.
- Review of 4.1.1 versus 5.0.4 defaults identified stricter consistent variable
  naming and new expression simplification, guard-operator, nonempty-list, and
  anonymous-function rules, plus renamed existing checks. The two resulting
  findings are fixed: use `fun extract_place_field/2` directly in signed-property
  extraction, and replace two duplicated verifier mutation helpers with one
  named-element removal helper. `lists:keytake` asserts that the target exists;
  the original positive controls and expected malformed-signature errors remain.
- `.github/workflows/erlang.yml`: include `rebar.config` and `elvis.config` in
  both cache hashes. This is the minimum invalidation needed to land the plugin
  upgrade without restoring a 4.x build. Formatter pinning, non-mutating formatting,
  and broader cache/global-plugin diagnostics remain #60; it is not closed here.
- README and `test/TESTS.md` document the chosen version and the tested native
  plugin upgrade command. Issue #63's obsolete Docker acceptance line is aligned
  with the native-before-push and six-GitHub-jobs-before-merge policy from #62.

## Validation and review

Before editing the implementation, an isolated 5.0.4 lint invocation with the
original configuration failed on the unknown `elvis` wrapper. After schema
migration it reported the two code findings above. Existing signed-property and
verifier tests passed before and after their fixes: 89 cases.

Focused tooling validation:
- Clean `flint` and repeated warm-cache `flint`: pass; compiled `.app` files
  confirm both `rebar3_lint` and `elvis_core` 5.0.4.
- Separate invalid-function-name probes in `src` and `test`: lint rejects each
  with the expected rule and file; restoring the clean sources passes again.
- A real 4.1.1 build passes with the original configuration. Replacing only the
  declared version/configuration reproduces a stale-cache failure. Rebar's
  `plugins upgrade rebar3_lint` resolves both components to 5.0.4; immediate and
  repeated warm-cache `flint` then pass. No generated files are edited manually.
- The previous workflow cache inputs excluded both changed configuration files;
  final cache-input checks pass, actionlint 1.7.12 passes (external shellcheck
  unavailable), documentation links resolve, and `git diff --check` is clean.

Final native `test`, `as test cover`, `flint`, `dialyzer`, and `tall` all pass:
157 EUnit + 62 CT cases, no skipped cases or suite-loading errors, 100% coverage
across all ten production modules. Review found no blocking findings; the
callback simplification preserves extraction behavior, and the mutation helper
retains the named missing-element cases and their passing controls.

Native validation uses installed OTP 28.4.2 with rebar3 3.25.1 and an empty
task-local global configuration. CI uses pinned OTP 28.5.0.7 for OTP 28. GitHub
matrix results for the pushed commit are recorded in the PR checks and validation
summary; all six successful jobs are required before merge.
No Docker commands are required or run, and no user-global settings change.

## Persistence

Persistent worktree:
`/Users/milanbor/.codex/worktrees/signerl-issue-63/signerl`.
Recovery diffs, untracked-source archive, source snapshots, failure probes,
upstream references, and validation logs:
`/Users/milanbor/projects/signerl/.recovery/issue-63`.
