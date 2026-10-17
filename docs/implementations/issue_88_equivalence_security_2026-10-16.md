# XML extraction equivalence/security — #88

Tracking: https://github.com/bormilan/signerl/issues/88

## Changes and reasoning

`test/signerl_xmlan_equivalence_SUITE.erl` adds eight mandatory CT cases against
baseline `5927e41bab8674b875c51df1a1ec956d42676992` and the actual pinned xmlan
`1fe39f6d414217584f514e70e43b8e7b4171f1ef`. A separate VM runs hash-checked
historical modules; current observation helpers call xmlan/xmlan_c14n directly.
Five representative inputs compare parsed/prolog/export/canonical values and
reference digests. Fresh in-memory RSA keys/certificates and fixed time require
complete byte equality, including SignatureValue, with/without a certificate and
through binary/file inputs. EC signatures cross-verify. Both independent xmlsec1
fixtures and their actual canonical/reference observations are checked in both
implementations. No private key fixture or alternate XML implementation is added.

Public invalid-input/error results are compared in both versions. File and HTTP
canaries exercise public binary/file sign/verify paths for SYSTEM/PUBLIC DTDs,
general/parameter entities, and relative file entities. File-read/open tracing
and an actual HTTP request establish positive controls. No resource fetch occurs
in the rejected pipeline. Existing zero-name-atom, malformed metadata, date,
wrong-key, independent signature, reconstruction, and tamper cases remain.

`baseline_sources.term` hashes the 25 original production/header/test files.
`ownership.term` exhaustively maps all 257 baseline test functions/generators/CT
cases (the original 426 executed cases) to executable current owners. Three
parser/C14N split contracts explicitly map to both new owners. The suite derives
the old inventory from original sources and verifies exact mapping completeness,
no duplicates, and runnable targets in actual dependency/current sources.

`scripts/prepare_xml_baseline.sh` fetches the immutable original source into
ignored persistent `priv/xml-baseline`; reuse requires the exact clean revision.
CI invokes it before tall on all six platforms. Missing/changed source fails;
there is no skipped comparison. LF attributes keep the Git Bash script portable. `elvis.config` extends its existing
OTP-name exception to the test suite for the required OTP `namedCurve` atom;
other lint rules remain enabled.
The historical code is compiled only into CT-private output and loaded only in
its isolated peer. It is never committed, a dependency, or a production fallback.

`docs/xmlan_equivalence_report.md` records the reproducible report, detailed
comparison and ownership matrix, limitations, and evidence. `README.md`,
`test/TESTS.md`, the migration contract, and fixture provenance document the new
baseline preparation/test workflow. Public behavior is unchanged; no production
or dependency pin changes are required. Signature/profile/failure-policy redesign
and the final #89 ownership/consumer audit remain separate.

## Validation and review

- Test first: absent baseline manifest/source made the new suite fail, proving
  the historical comparison cannot silently skip.
- All eight new CT cases pass after source setup. Review added file parity,
  independent signature comparison, split-owner mappings, positive controls for
  both file trace functions, strict hash-only compilation, and peer cleanup.
- Five negative controls reject a changed RSA byte, changed canonical byte,
  missing ownership entry, extra canary read, and changed historical source.
  Each temporary mutation was restored. No original golden was changed.
- Native full test: 150 EUnit + 84 CT = 234 passed; no skipped tests.
- Native coverage: every Signerl production module and total at 100%.
- Native formatting/lint, Xref, Dialyzer, final tall: passed after review changes;
  recorded in recovery logs.
- Standalone exact-pin xmlan native tall: 259 passed, 100%, xmllint/lint/Xref/
  Dialyzer clean, no skipped required tests. Fresh xmlan run `38940721803` passed
  all six jobs at the exact pinned SHA; each saved job log confirms 259 tests,
  100%, tall and xmllint. All latest-head Signerl jobs must also pass before readiness.
- Review confirms `src/`, `include/`, `rebar.config`, `rebar.lock`, and original
  fixture/golden bytes are unchanged. No behavior differences were discovered.

## Recovery

Persistent attached implementation worktree:
`/Users/milanbor/.codex/worktrees/signerl-issue-56/signerl`, branch
`codex/issue-88-equivalence-security`.

Recovery outside temporary storage:
`/Users/milanbor/projects/signerl/.recovery/issue-88/` contains tracked diffs,
untracked source archive, gate logs, negative-control outcomes, both repositories'
CI evidence, and the final Git bundle/patch. Generated keys/certificates, baseline
checkout, build output, and diagnostics containing private arguments are excluded
from recovery source archives and commits. Peer-call failures redact arguments.
Unrelated user changes in the original Signerl checkout remain preserved.
