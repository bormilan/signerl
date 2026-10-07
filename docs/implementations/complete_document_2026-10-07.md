# Complete XML document boundary (#51)

## Investigation and acceptance criteria

The original report showed `parse_binary/1` discarding input after the first
root and `verify/3` accepting a valid signature followed by a second root.
PR #76 already added remainder validation while rejecting trailing processing
instructions for #50. Its merged implementation uses the same parser for public
binary and file inputs. This task completes #51 with public API regression tests
and documentation; no production change is needed.

The new tests passed against the merged implementation before any production
edits. Accepted trailing XML whitespace/comments preserve signature validity;
a second root, non-XML data, or malformed trailing markup returns
`{error, invalid_xml}` from signing and verification. Processing instructions
remain intentionally unsupported, with existing rejection tests before, inside,
and after the root.

## Changes and review

- `test/signerl_xml_test.erl`: extend the suffix grammar cases with self-closing
  roots, text after comments, malformed comments/markup, CDATA/references outside
  the root, non-XML whitespace, and a misplaced BOM. Both SAX root-ending paths
  are covered by the self-closing and nonempty root fixtures.
- `test/signerl_api_SUITE.erl`: verify a real signature before appending each
  suffix. Legal whitespace/comments, including Unicode and markup-looking
  comment text, keep verification valid; invalid suffixes fail both signing
  and verification. One focused file case covers accepted trailing comments and
  second-root rejection through parsing, signing, and verification, without
  repeating the entire binary matrix for files.
- `README.md`: state the full-document policy and intentional suffix handling.
- `test/TESTS.md`: document the controls and update the case inventory.

Review checked that invalid verification cases start with passing signatures,
that positive cases cover the same append operation, and that file dispatch
has its own accepted/rejected controls. Public signing retains its existing
prolog requirement. Lower-level `parse_file/1` still raises for invalid XML;
public file APIs return `{error, invalid_xml}`. Resource/entity limits (#39),
namespace behavior (#41), and atom allocation (#61) remain separate work.

## Validation

- Test certificates generated with `scripts/gen_certs.sh`.
- `rebar3 fmt`: passed.
- `rebar3 eunit --module=signerl_xml_test`: 65 passed against unchanged production code.
- `rebar3 ct --suite=test/signerl_api_SUITE`: 62 passed against unchanged production code.
- `rebar3 test`: 206 EUnit + 77 Common Test = 283 cases passed, no skips or
  suite-loading errors, 100% combined production-module coverage.
- `rebar3 as test cover`: all ten production modules and total coverage at 100%.
- `rebar3 flint`: formatting and lint passed.
- `rebar3 dialyzer`: passed with no project findings. Initial PLT construction
  printed missing-spec warnings from the installed OTP xmerl sources.
- Final `rebar3 tall`: passed all 283 cases, 100% coverage, formatting, lint,
  Xref, and Dialyzer with no skipped tests.
- `git diff --check`, README/test-document relative links, and documented case
  totals: passed.

Native validation used installed OTP 28.4.2 and pinned rebar3 3.25.1, with an
empty global rebar config. The repository pins OTP 28.5.0.7; the GitHub matrix
checks that exact version plus OTP 26/27 on Ubuntu and Windows. All six jobs
must pass on the PR head before merge; the PR records their final results.

## Recovery

Persistent source: `/Users/milanbor/.codex/worktrees/signerl-issue-51/signerl`.
Recovery diff, untracked source archive and command logs:
`/Users/milanbor/projects/signerl/.recovery/issue-51`.
