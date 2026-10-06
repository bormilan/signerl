# XML content preservation (#50)

## Problem and implementation

The previous parser removed whitespace-only text nodes, and file parsing also
collapsed whitespace within text. Export wrote attribute tab/LF/CR literally,
so XML attribute normalization changed the values on the next parse. Processing
instructions were silently dropped from the simplified tree.

- `src/signerl_xml.erl`: file and binary inputs share a SAX parsing boundary.
  Text and whitespace events become ordered children, namespace declarations
  become attributes, and qualified names retain the existing atom-based tree
  shape. UTF-8 is validated before parsing. NUL bytes are rejected (illegal in XML),
  preventing SAX from accepting BOM-less UTF-16/32 input through autodetection.
- OTP's `xmerl_scan` also converts text CR references to LF and fails to normalize
  literal CR in CDATA. Focused regressions demonstrated both; using the SAX parser
  preserves the XML character values rather than adding lexical replacements.
- SAX may stop at a nonempty root's closing tag. Its remainder is parsed after an
  empty sentinel root using the same callbacks; this validates legal XML Misc,
  rejects processing instructions, and rejects any further unconsumed content.
  Whitespace outside the root and comments remain outside the signed profile.
- Processing instructions are explicitly unsupported before/inside/after the
  root and return `invalid_xml`. Declarations remain supported, as does PI-looking
  text in CDATA/comments. This satisfies #50's explicit-rejection alternative.
- The serializer retains the existing prolog/newline, namespace, empty-element,
  and escaping behavior, adding character references for attribute tab/LF/CR and
  text CR. Escaping precedes reference insertion to preserve literal `&#x9;` text.
- XML tests now assert preserved indentation and append-to-mixed-content behavior.
  The old normalized `books_with_new.xml` fixture is replaced by a small explicit
  tree contract. `README.md` and `test/TESTS.md` document the content profile.

The behavior follows XML 1.0 [line-ending handling](https://www.w3.org/TR/REC-xml/#sec-line-ends)
and [attribute normalization](https://www.w3.org/TR/REC-xml/#AVNormalize), and
[canonical XML character handling](https://www.w3.org/TR/xml-c14n11/).

## Validation

Tests were added before implementation:

- Initial XML regressions: 43 EUnit cases, six failures; 74 CT cases, five failures.
- CR-reference and CDATA probes reproduced two further scanner defects.
- Remainder probes reproduced discarded processing instructions and trailing data.
- Focused final results: 52 XML EUnit cases and all 74 CT cases pass, no skips.
  Public tests cover unchanged binary/file signatures, preserved unsigned content,
  and five single-change mutations. `xmllint --c14n11` and `--exc-c14n` agree with
  production parsing/canonicalization and the reserialized content fixture.
- Full `rebar3 test`: 193 EUnit + 74 CT = 267 cases, no skips, 100% combined
  production-module coverage. `rebar3 flint` and `rebar3 dialyzer` pass.
- Review fixed lint findings and used SAX's binary interface to match its declared
  remainder type; affected/full tests were rerun. No checks were suppressed.
- Native validation uses OTP 28.4.2 and rebar3 3.25.1, with an isolated empty global
  rebar configuration and the existing dependency cache. The pinned OTP 28.5.0.7
  and OTP 26/27 compatibility matrix run in GitHub Actions.
- Final native `rebar3 tall`: passed on the reviewed implementation, including
  all 267 cases, 100% coverage, formatting/lint, Xref, and Dialyzer. No tests skipped.
- GitHub's six-job OTP 26/27/28 × Ubuntu/Windows matrix must pass on the published
  head before the PR is declared ready to merge; results are recorded in the PR.

## Windows comparison follow-up

The first matrix run passed all three Linux jobs but exposed CRLF in `xmllint`'s
Windows stdout where the canonicalizer emits LF. All public API cases passed;
the sole failed assertion was the new multiline interoperability comparison.
This is C stdio's [text-mode translation](https://learn.microsoft.com/en-us/cpp/c-runtime-library/reference/setmode):
LF becomes CRLF on output. A local probe confirmed `xmllint --c14n11 --output`
still emits canonical bytes to stdout rather than the requested file; its
[CLI documentation](https://gnome.pages.gitlab.gnome.org/libxml2/xmllint.html)
also specifies stdout for canonicalization.

The interop helper now reverses only Windows stdout CRLF translation. It does not
rewrite fixture XML, production output, or character references (`&#xD;` remains
literal canonical bytes). Comparisons remain exact after that transport step.
The first failing CI logs and subsequent validation are saved in the recovery
folder. The nine affected CT cases, `flint`, `dialyzer`, and final native `tall`
passed again (267 cases, no skips, 100% coverage). All six GitHub jobs must pass
on the follow-up head before merge.

## Review and limits

Production changes are confined to `signerl_xml`. Existing signature builders,
verification, canonicalization algorithms, and public API shapes remain in place.
Namespace declaration ordering may differ lexically, but canonical ordering and
qualified names are preserved. Character content, not CDATA/text-node boundaries,
is the supported contract. No regex rewrites XML to mask canonicalizer differences.

The existing external-entity allowance is retained; this is not a parser resource
hardening change (#39). XML names still become atoms (#61). Broader namespace and
signature-profile support remains #41. Remainder validation overlaps #51 because
PIs after the root must be rejected, but its wider public API trailing-input matrix
is left for that issue; this PR only claims closure of #50.

## Recovery

Persistent source: `/Users/milanbor/.codex/worktrees/signerl-issue-50/signerl`.
Recovery diff, untracked source archive and command logs:
`/Users/milanbor/projects/signerl/.recovery/issue-50`.
