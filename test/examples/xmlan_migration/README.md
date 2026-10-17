# Frozen XML migration corpus

Captured on 14 October 2026 from unchanged Signerl `dev` commit
`5927e41bab8674b875c51df1a1ec956d42676992`, using native OTP 28.4.2.

- `input.xml`: hand-written UTF-8 mixed content, Unicode text/attributes, implicit
  `xml:space`, unused/inherited namespaces, default undeclaration, prefix rebinding,
  character references, CDATA, and a legal trailing comment.
- `parsed.term`: the exact parsed transparent tuple/value representation.
- `export.xml` and `fragment.xml`: exact baseline serialization, including prolog,
  escaping, element ordering, and the differing final-newline contracts.
- `c14n11.xml` and `exclusive.xml`: exact baseline bytes in both supported modes.
- `signed-rsa.xml`: exact Signerl RSA-SHA256 output for `input.xml`, a generated test
  key, no certificate (`undefined`), and `2026-10-13T12:34:56Z`.
- `rsa-public.pem`: the public key for verifying the frozen signature. Its
  private key is absent from the repository. The Common Test suite generates a
  fresh RSA key in memory, verifies the new signature, proves fixed-input determinism, and
  compares every output byte except its necessarily different SignatureValue
  against the frozen result. No generated key is persisted by the tests.
- `SHA256SUMS`: the original artifact hashes. Golden bytes are read as files;
  the tests do not regenerate them from the implementation being tested.

These outputs freeze existing behavior; they are not independent conformance
oracles. Keep the independent xmlsec signatures and xmllint comparisons alongside
this regression. Certificate and ECDSA behavior remain covered by the existing
API tests; ECDSA output is verified rather than compared byte-for-byte.

Run the probe with `rebar3 ct --suite test/signerl_xmlan_contract_SUITE`.
Changing a frozen artifact during extraction requires investigating the behavior
difference rather than automatically replacing the expected result.

The #88 historical comparison also uses `baseline_sources.term` (SHA-256 of all
25 original production/header/test sources) and `ownership.term` (all 257 original
test functions/generators/cases, with explicit multiple owners for split contracts).
These are source/inventory manifests, not replacements for the frozen outputs or
new private-key fixtures. Run `scripts/prepare_xml_baseline.sh`, then
`rebar3 ct --suite test/signerl_xmlan_equivalence_SUITE`; see the
[reproducible report](../../../docs/xmlan_equivalence_report.md).

The [final migration acceptance report](../../../docs/xmlan_migration_acceptance.md)
records source/compiled ownership and regression results for the pinned library.
The original frozen bytes and hashes remain unchanged through the final audit.
