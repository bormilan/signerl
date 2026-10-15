# xmlan extraction boundary and baseline (#83)

## Changes and acceptance criteria

Started the approved extraction milestone from merged `dev` commit
`5927e41bab8674b875c51df1a1ec956d42676992`. The clean attached managed worktree
was reused on `codex/issue-83-xmlan-contract`; the original project checkout and
its local changes remain untouched. CodeGraph was consulted at the indexed
project root; this managed worktree has no index, so its current source was
read directly.

- `docs/xmlan_migration_contract.md` maps all 74 functions in the two baseline XML
  modules, nine XML macros, exported types, production callers, test families,
  and the future `xmlan` / `xmlan_c14n` APIs. Generic XML implementation moves;
  signature identity/removal, XMLDSig/XAdES, references, metadata, and crypto stay.
- The contract preserves existing exported helpers through direct delegates and
  transparent type aliases. It records current errors, argument order, prolog/BOM
  distinctions, namespace restrictions/context, both canonical modes, exact
  fixed-time RSA behavior, and the immutable dependency/merge sequence.
- Added `test/xmlan_contract_consumer.erl` and CT cases to run a real consumer
  using only exported Signerl/XML APIs and ordinary OTP services. The source also
  compiles/runs outside the test VM and exercises transparent tuple construction.
- Added `test/examples/xmlan_migration/` with a hand-written UTF-8/context/content
  corpus and frozen parsed/export/canonical/signed outputs captured from the
  unchanged production baseline. Only the verification public key is included.
  The consumer generates a fresh signing key in memory, verifies both the frozen
  and new signatures, proves determinism, and compares output outside SignatureValue.
  #88 requires exact before/after RSA bytes using the same fresh key in one run.
  SHA256SUMS records the original artifact bytes; tests never recapture outputs.
- `.gitattributes` preserves the XML goldens byte-for-byte across operating
  systems. README and `test/TESTS.md` document migration status and the new probe.

No production XML/signature behavior, dependency configuration, or xmlan source
changed in #83. The standalone library and implementation moves are #84–#87.
The full equivalence and final clean-consumer/source audits remain #88/#89.

## Validation-first and review

The contract probe was added and passed against unchanged baseline production
code before writing the ownership/API design. Frozen expectations are complemented
by existing independent signatures, xmllint comparisons, parser resource canaries,
and isolated atom-growth tests. Review covers immediate-child signature removal,
local namespace overrides, contextual detached fragments, transparent mixed
values, unsupported encoding/prologs, and exception/file-error compatibility.

Review confirmed that signature removal is intentionally limited to immediate
children and generic projections must retain lexical attributes. The intentional
unsupported-mode check lives in the runtime CT case; the external typed consumer
uses valid key-file/type inputs even when exercising missing-message failures.
The complete helper/macro map and document links were checked against current
source, and frozen hashes verified. No production files changed.

## Native validation before the fixture adjustment

- Focused contract CT: 2 cases passed.
- Standalone consumer: compiled with debug info and passed outside rebar's test VM,
  without test_helpers or generated certificates.
- Changed exported-byte golden: the consumer failed with its expected assertion
  and exit 1; it cannot recapture an oracle silently.
- External consumer Dialyzer: passed against production BEAMs and the full
  dependency PLT. An opaque-only task-owned source copy produced the expected
  tuple-construction/opacity warnings and exit 2. Production types were untouched.
- `rebar3 test`: 336 EUnit + 92 CT = 428 tests passed, no skips, 100% total coverage.
- `rebar3 as test cover`: 100% total production coverage.
- `rebar3 flint`: formatting and lint passed.
- `rebar3 dialyzer`: passed.
- Final native `rebar3 tall`: all 428 tests, 100% coverage, formatting, lint, Xref,
  and Dialyzer passed. Independent signatures, all 10 xmllint cases, and the
  isolated atom-growth probe ran without skips.
- Document validation: all 74 functions and nine macros mapped; local links,
  whitespace, frozen SHA-256 hashes, and `git diff --check` passed.

Both consumer negative controls have saved diagnostics. The full dependency PLT
is used for external checking; the OTP base PLT alone lacks public_key/xmerl types.
Automatic approval review rejected the initial commit/push because it included a
private RSA fixture without explicit publication authorization. The fixture was
removed from the PR. Signing now generates keys only in memory; only public key
and signed output remain. The native/consumer gates are rerun after that change.
The ASN.1 naming exception includes the consumer's ordinary OTP RSA record fields.
The latest-commit six-job CI matrix will be checked after PR publication.
No automatic merge is authorized; #84 follows the reviewed/merged #83 contract.

## Persistence

Managed worktree: `/Users/milanbor/.codex/worktrees/signerl-issue-56/signerl`.
Branch: `codex/issue-83-xmlan-contract`.
Recovery diffs, untracked source archive, frozen-source capture/probes, and native
validation logs: `/Users/milanbor/projects/signerl/.recovery/issue-83/`.
The earlier work on #56 is merged and its original recovery snapshots remain.
Native commands use pinned rebar3 3.25.1, installed OTP 28.4.2, and an isolated
empty global config; CI checks the pinned OTP 28 patch plus OTP 26/27 on both OSes.

## Final validation after the fixture adjustment

The public-fixture/in-memory-key implementation passed all rerun gates:
`test`, `as test cover`, `flint`, `dialyzer`, and final native `tall`.
There are 336 EUnit + 92 CT = 428 passing cases, no skips, and 100% coverage.
The standalone consumer and full-PLT Dialyzer analysis pass. Changed-golden and
opaque-only controls still fail with their intended assertion/opacity diagnostics.
All eight retained artifact hashes and document links/whitespace pass. The staged
payload was checked and contains no private-key PEM. Final logs use `*-safe.log`.
