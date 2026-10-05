# Reproducible tooling and non-mutating format gates (#60)

## Changes and acceptance criteria

- `rebar.config` pins erlfmt 1.8.0, the stable release verified on 2026-10-05.
  It is also the formatter resolved by the previous successful builds. Keep
  rebar3_lint / Elvis 5.0.4 and the OTP/rebar3 pins established by #62/#63.
- `test` and `flint` call `fmt --check`. `tall` inherits the same check through
  `test`, once per invocation. Keep `rebar3 fmt` as the explicit developer
  write command. Formatting drift now fails validation without being repaired
  by a passing gate; tests, coverage, lint, Xref, and Dialyzer remain required.
- `.gitattributes` checks out `.erl`, `.hrl`, and `.app.src` files with LF, matching
  erlfmt output even under `core.autocrlf=true`. Scope is limited to formatter
  inputs; XML fixtures are not normalized by this change.
- README and `test/TESTS.md` describe the exact tool pins, deliberate update
  policy, developer/check commands, plugin cache upgrades, and a clean diagnostic
  build using separate build/cache directories plus empty global configuration.
  The diagnostic subshell stops on failure and does not modify user-global files.
- #63 already added `rebar.config` and `elvis.config` alongside `rebar.lock` to
  both CI cache hashes and tested a real cached lint 4.1.1-to-5.0.4 transition.
  This task reuses those merged changes. Resolved OTP/rebar3 versions and OS also
  participate in the keys; source/header/test paths additionally key `_build`.
  The formatter pin change therefore invalidates the prior CI caches.

Sources:
- https://github.com/WhatsApp/erlfmt/releases/tag/v1.8.0
- https://github.com/WhatsApp/erlfmt/blob/v1.8.0/README.md
- https://www.rebar3.org/docs/configuration/configuration/
- https://github.com/erlang/rebar3/blob/3.25.1/apps/rebar/src/rebar_dir.erl

## Validation-first evidence

Before implementation, a persistent repository snapshot with a deliberately
misformatted module passed `rebar3 test` and rewrote the file. This reproduces
the original defect without changing the implementation worktree.

After the configuration change:
- `fmt --check`, `test`, `flint`, and `tall` each reject that drift with nonzero
  status. Hashes confirm every Erlang source/header/application file is unchanged.
- Explicit `fmt` repairs the drift and a subsequent check passes.
- A real cached erlfmt 1.7.0 build remains at 1.7.0 after changing its declared
  pin. `plugins upgrade erlfmt` resolves 1.8.0; immediate and warm checks pass.
- An intentionally malformed global config in a task-owned directory causes a
  failure. The empty-global-config diagnostic build passes without modifying
  that control file or any actual user-global configuration.
- The diagnostic build uses fresh `REBAR_BASE_DIR` and `REBAR_CACHE_DIR` paths.
  Clean `tall`, coverage, `flint`, Dialyzer, and a warm final `tall` all pass:
  157 EUnit + 62 CT cases, 100% coverage across all ten production modules.
  Source hashes remain unchanged and the normal `_build` directory is absent.
  Compiled application metadata confirms erlfmt 1.8.0, lint/Elvis 5.0.4.
- A CRLF-formatted source fails erlfmt's check. A task-owned Git repository with
  `core.autocrlf=true` reproduces CRLF checkout before the attributes; with the
  new attributes it checks out LF and passes. Header/app patterns also resolve
  to LF; the XML fixture pattern remains unspecified.

Native runtime: installed OTP 28.4.2 with pinned rebar3 3.25.1. GitHub uses pinned
OTP 28.5.0.7 for OTP 28 and retains OTP 26/27 on Ubuntu and Windows. No Docker
commands or user-global configuration edits are involved. Documentation links
and shell snippets validate; inherited CI cache inputs are verified and
`git diff --check` is clean. The final reviewed `tall` rerun also passes all
219 cases with no skips or suite-loading failures, 100% coverage, lint, Xref,
and Dialyzer. Review found no blocking findings. GitHub results for the pushed
commit are recorded in the PR checks and validation summary; all six successful
jobs are required before merge.

## Review and persistence

Production code and test cases are unchanged. No formatting rule, lint rule,
coverage threshold, or supported OTP version is weakened. Existing XML fixture
bytes and scope are preserved.

Persistent worktree:
`/Users/milanbor/.codex/worktrees/signerl-issue-60/signerl`.
Recovery diffs, untracked-source archive, failure probes, clean/warm snapshots,
upstream references, and validation logs:
`/Users/milanbor/projects/signerl/.recovery/issue-60`.
