# Issue #57: trustworthy signature regression controls

## Problem and evidence

The first added regression verified the original signature data, then reinserted
its unchanged Signature through the existing helper. The first reference check
passed and the second failed. The helper had reparsed `books.xml` with
`parse_file/1` whitespace normalization, changing the signed document.

Retaining the original unsigned tree made that regression pass and exposed two
misleading expectations: changing only SignedInfo's canonicalization algorithm
does not invalidate the reference digests, and the duplicate-Type test's false
result came from the invalid baseline.

## Changes and acceptance criteria

- `test/signerl_SUITE.erl`: reconstruction retains the extracted unsigned tree.
  Shared controls verify original and reconstructed messages before mutations;
  tree mutations assert a change and binary replacements assert one match.
  SignedInfo mode changes now explicitly preserve reference verification while
  invalidating signature verification. Wrong-key and certificate tests have
  positive controls too.
- Duplicate Type attributes are tested through real XML and the public API.
  Malformed certificate children now use XML-representable elements and pass
  through serialization/parsing. Distinct low-level decoder boundaries remain.
- `test/examples/independent/`: two full RSA-SHA256 signatures, their templates,
  public key, and provenance. `xmlsec1` independently computed and verified both
  digests and signatures. The exclusive fixture includes an unused namespace
  so incorrect inclusive canonicalization changes its SignedInfo bytes.
- `test/signerl_c14n_SUITE.erl`: xmllint comparisons use the same binary parsing
  path as production verification, retaining the independent xmllint output.
- `test/signerl_xml_test.erl`: export assertions run in memory; existing CT
  file-output assertions use `priv_dir`. No tracked fixture is rewritten.
- `test/TESTS.md` and the independent fixture README explain the controls,
  fixture generation, and limits. No public API or production behavior changed.

## Review

Reviewed the diff against issue #57 and the repository's `ferike` checklist.
The initial targeted run caught a CT working-directory assumption in the new
fixture loader and a mistaken certificate-map field name; both were corrected.
The focused suites then passed all 132 cases with no skips.

The helpers add assertions rather than a configurable mutation framework.
The incorrect duplicate-attribute tree builder was removed. Broader suite
organization and fixture/assertion cleanup remain #67 and #68.

The independent fixtures cover an explicit namespace arrangement and ASCII
content; they do not fix namespace inheritance, UTF-8, or whitespace issues
(#41, #49, #50). Bidirectional external signing/verification CI remains #40.

## Validation

- Before the fix: unchanged reconstruction regression failed, as expected.
- After retaining the original tree: reconstruction passed; the two previously
  misleading expectations failed, confirming the diagnostic.
- `xmlsec1 --verify` accepted both independently signed fixtures with 2/2
  references. SignErl also verified both complete signatures.
- Focused signature and canonicalization suites: 132 passed, none skipped.
- `rebar3 test`: 14 EUnit tests and 198 Common Test cases passed, none skipped;
  fresh CT coverage was 100% across all ten production modules.
- `rebar3 as test cover`: 100% total coverage.
- `rebar3 flint`: passed.
- `rebar3 dialyzer`: passed with no project findings. Initial PLT construction
  printed missing-spec compiler warnings from OTP's `xmerl_ucs`, not SignErl.
- `rebar3 tall`: passed, including Xref and all preceding gates.
- Native commands used OTP 28.4.2, rebar3 3.25.1, and an isolated
  `REBAR_GLOBAL_CONFIG_DIR` so unrelated global plugins did not affect the run.
- `make ci-local`: passed on Linux Docker OTP 26.2.5.16, 27.3.4.6, and 28.3.1.
  Each ran `tall`: 14 EUnit tests, 198 Common Test cases, no skips, 100% coverage,
  formatting/lint, Xref, and Dialyzer. A temporary empty Docker configuration
  avoided the host credential-helper hang without changing the user's config.
- `git diff --check`: passed. Only tests, independent fixtures, and documentation
  changed; generated outputs remained outside tracked fixture files.
