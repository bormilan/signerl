# Final xmlan ownership and clean consumer audit — #89

Tracking: https://github.com/bormilan/signerl/issues/89

## Changes and acceptance reasoning

`test/signerl_xmlan_ownership_SUITE.erl` adds two executable ownership checks to
native tall/CI. They require the compatibility modules to contain only 18 direct
argument-preserving delegates plus the three documented signature operations;
all six aliases must remain exported and transparent. The legacy header must
only forward to the dependency. Compiled imports enforce no direct xmerl/dynamic
apply, local signature-only compatibility calls, and public xmlan exports.
Application/config/lock checks enforce one immutable matching HTTPS pin and no
reverse xmlan dependency/import. `test/xmlan_audit.hrl` names the static public
API/type inventories. The project-root lookup supports rebar's generated layout.

`test/signerl_external_consumer.erl` and the existing frozen consumer compile as
ordinary modules in a fresh external rebar3 application. They sign/verify through
all public arities with binary/file inputs, certificates and fresh in-memory
keys, require valid reconstruction and tamper/wrong-key rejection, and exercise
all legacy XML exports, six transparent aliases, forwarded include and frozen
byte/signature contracts. No generated private key is persisted.

`scripts/check_external_consumer.sh` creates that application in a new directory,
fetches only HTTPS Git dependencies at a supplied full Signerl SHA, clears global
configuration/overrides and Erlang path flags, and checks actual Git heads/remotes,
lock levels and unchanged tracked dependency files. It runs compile/runtime/Dialyzer. Directly
used runtime applications are declared by the consumer; there is only one rebar
package dependency, Signerl. No sibling checkout, patch, private API or local
source override is used. CI repeats the consumer on each actual PR head after
tall in all six jobs. LF attributes keep Git Bash execution portable.

The final acceptance report, README, migration contract, fixture provenance and
test responsibilities document source/test ownership, exact revision, public
usage, evidence and post-merge closure. `elvis.config` extends the existing OTP
ASN.1 name exception to the consumer's standard RSA record fields. Production
sources, public behavior, original goldens, dependency pin and lockfile do not
change. No additional XML/profile/algorithm/failure-policy work is included.

## Investigation and validation

- Confirmed PR #92 merged at `cf4fd4f80822d30e7c1154e43b73941d7ecd7e55` and
  issue #88 actually closed. All #83–#88 issues are closed; only #89 remains in
  the migration milestone. xmlan #3 is merged; exact validated pin remains `1fe39f6d414217584f514e70e43b8e7b4171f1ef`.
- New tests were written first. After handling rebar's generated application
  layout, both ownership cases pass. Four executable negative probes reject an
  added hidden helper, swapped delegate arguments, direct xmerl import, and
  private xmlan import. Source mutations are restored before final gates.
- One-time preprocessed AST audit: all 104 functions in the other eight Signerl
  modules match baseline after public XML target retargeting. All 41 generic XML
  and 30 generic C14N functions are preserved in xmlan. Compatibility source and
  header review confirms only the allowed local signature policy/delegates/types.
- Clean native HTTPS consumer of merged `cf4fd4f...`: runtime passed. The first
  Dialyzer probe exposed missing direct runtime application declarations in the
  consumer metadata; declaring its actual xmlan/public_key/crypto use resolved
  unknown functions/types. The clean repeat compiles/runs and passes Dialyzer.
- Separate opaque-only compatibility BEAMs make the external consumer fail
  Dialyzer with opacity findings (exit 2), while the positive dependency stays
  untouched. Compiled probe BEAMs include debug info for genuine type analysis.
- Native Signerl `rebar3 test`, `rebar3 as test cover`, `rebar3 flint`,
  `rebar3 dialyzer` and final `rebar3 tall`: passed after review.
  150 EUnit + 86 CT = 236; all ten production modules/total 100%, no skips.
- Final script/template repeat in a third clean native project passed compile,
  runtime and Dialyzer with empty global configuration and isolated cache.
- Exact-pin xmlan final native tall passes: 259 tests, 100%, no required skips,
  xmllint/lint/Xref/Dialyzer clean. Fresh six-job CI run `39013046603` at the exact
  pin passes; each final job log is checked before declaring readiness.
- Repeat the clean consumer at the published #89 head and require all six final
  Signerl jobs to pass tall plus the consumer. Verify saved PR metadata after
  creation/update. Do not close the milestone before this PR merges.

## CI follow-up

The initial matrix passed tall but failed a post-runtime consumer metadata guard
without identifying the assertion. Consumer checks now report the exact failed
revision/origin/working-tree check, without printing credentials or private keys.
The matrix keeps all six jobs running so a platform failure cannot cancel the
remaining required evidence. The diagnostic identified normal untracked `xmlan/ebin/` compiler output: the
pinned library does not ignore that directory. `check_dependency_tree.sh` now
checks every tracked file and allows only ordinary untracked root ebin BEAM/app
artifacts outside repository ignore rules. Host-wide excludes are disabled for
this audit; unexpected source/config additions still fail. No library ignore
file or source is patched and the validated pin stays unchanged. Executable
controls accept build output and reject tracked edits/untracked sources, including
files concealed by a host ignore rule. All seven source-tree probe outcomes matched expectations, the corrected clean
consumer passed compile/runtime/Dialyzer, and native flint/Dialyzer/tall passed
again (236 tests, 100%, no skips) before publishing.

## Recovery

Persistent attached source worktree:
`/Users/milanbor/.codex/worktrees/signerl-issue-56/signerl`, branch
`codex/issue-89-final-xml-audit`.

Persistent recovery outside temporary storage:
`/Users/milanbor/projects/signerl/.recovery/issue-89/` contains tracked diffs,
untracked source archive, source/compiled audit, negative-control results, clean
consumer projects/logs, native/CI evidence and final Git bundle/patch. Recovery
source archives exclude generated keys/certificates, historical checkout, and
build output. User changes in the original checkout remain untouched. Final
milestone closure waits for the user-confirmed merge and actual issue/check audit.
