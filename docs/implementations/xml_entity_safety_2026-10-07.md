# XML DTD and entity safety (#39)

## Investigation

The shared SAX parser explicitly enabled all external entities and ignored DTD
callbacks. All public XML inputs eventually use it. xmerl sends `startDTD` before
processing an internal/external subset, but a bare `<!DOCTYPE root>` sends only
`endDTD`. Both forms must reject. Entity declarations and external resolution
are also disabled in the parser options. This policy permits zero custom
entity expansion depth and zero expanded bytes; predefined entities and numeric
character references remain supported.

## Changes and review

- `src/signerl_xml.erl`: use `disallow_entities`, `{external_entities, none}`,
  `{entity_recurse_limit, 0}`, and `{fail_undeclared_ref, true}`; reject both
  `startDTD` and `endDTD`. The remainder validator shares these options.
- `include/signerl_xml.hrl`: name the zero custom-entity recursion policy.
- `test/signerl_xml_test.erl`: DTD forms, undeclared references, two safely bounded
  expansion shapes, and positive predefined/numeric-reference and text controls.
- `test/signerl_xml_SUITE.erl`: generated file canaries and a loopback HTTP canary
  with a positive request control and no-request assertions for external DTDs,
  PUBLIC identifiers, general entities, and parameter entities.
- `test/signerl_api_SUITE.erl`: DTD insertion into a previously verified signature,
  signing rejection, and a focused file boundary test.
- `README.md` and `test/TESTS.md`: document behavior, limits, compatibility, and tests.

Rejecting all DTDs gives a strict zero-depth/zero-byte custom expansion bound.
There is no permitted custom replacement text that needs a positive size quota.
Predefined/numeric references do not recursively expand custom entities. Parser
options independently disable declarations and external reads; this does not
silently skip a DTD and report success. Review checked callback order in installed
OTP 28.4.2 xmerl source: `startDTD` precedes subset processing/fetches, while a bare
DOCTYPE has only `endDTD`. Both rejection paths have behavioral tests.

The public API and error shapes are preserved. DTD-dependent documents are now
rejected intentionally. Ordinary document size/depth and concurrency are not
bounded here, file APIs still read the full file, and XML name atom growth is
separately tracked in #61. No regex scans or tree model changes are needed.

References: [xmerl SAX controls](https://www.erlang.org/doc/apps/xmerl/xmerl_sax_parser.html#options/0)
and [OWASP guidance](https://cheatsheetseries.owasp.org/cheatsheets/XML_External_Entity_Prevention_Cheat_Sheet.html#general-guidance).

## Tests first

Added bounded exponential/quadratic fixtures, DTD forms and positive controls,
controlled external file and HTTP canaries, and public sign/verify rejection
starting with a passing signature. A focused file-input regression covers the
shared parser boundary. Before the fix: 77 XML EUnit cases ran with nine expected
failures; the two new XML CT cases and two public API CT cases also failed. The file canary was read,
the HTTP canary observed requests, and bounded expansion payloads were expanded.
The production change now rejects both DTD events and sets explicit no-entity
parser options. After the fix, all 77 XML EUnit cases and 72 focused CT cases
passed. Initial lint found two overlong test literals; splitting them preserved
the fixture bytes, and the XML unit tests passed again.

## Final native validation

- `scripts/gen_certs.sh`: generated test-only certificates.
- `rebar3 test`: 218 EUnit + 81 Common Test = 299 cases passed with no skips
  or suite-loading errors, and 100% combined production-module coverage.
- `rebar3 as test cover`: all ten production modules and total coverage at 100%.
- `rebar3 flint`: formatting and lint passed after the test-literal formatting fix.
- `rebar3 dialyzer`: passed with no project findings. Initial PLT construction
  printed missing-spec warnings from installed OTP xmerl sources.
- Final `rebar3 tall`: 299 cases, no skips, 100% coverage, formatting, lint,
  Xref, and Dialyzer passed.
- `git diff --check`, document links, and documented test counts: passed.

Native validation used installed OTP 28.4.2 with pinned rebar3 3.25.1 and an
empty global rebar config. GitHub checks OTP 26/27 and pinned OTP 28.5.0.7 on
Ubuntu and Windows. All six jobs must pass on the PR head before merge; their
verified results are recorded in the PR description.

## Recovery

Persistent worktree: `/Users/milanbor/.codex/worktrees/signerl-issue-39/signerl`.
Recovery diff, untracked sources and command logs:
`/Users/milanbor/projects/signerl/.recovery/issue-39`.
