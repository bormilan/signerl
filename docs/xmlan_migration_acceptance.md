# Final XML migration acceptance report — #89

Signerl now owns signature logic and consumes generic XML functionality from
[xmlan](https://github.com/bormilan/xmlan). Its source configuration and generated
lockfile both pin the immutable Git revision
[`1fe39f6d414217584f514e70e43b8e7b4171f1ef`](https://github.com/bormilan/xmlan/tree/1fe39f6d414217584f514e70e43b8e7b4171f1ef)
over HTTPS. The application version is `0.1.0`; the validated Git revision is the
consumer's identity. Hex publication or a new release is not required.

The acceptance baseline is Signerl
[`5927e41bab8674b875c51df1a1ec956d42676992`](https://github.com/bormilan/signerl/tree/5927e41bab8674b875c51df1a1ec956d42676992).
The [extraction contract](xmlan_migration_contract.md) and
[equivalence/security report](xmlan_equivalence_report.md) preserve the supported
profile, public APIs, error boundaries, canonical bytes, and fixed-time RSA output.
No behavior difference was found and no production change is needed in #89.

## Source and compiled ownership

| Repository/source | Owned behavior |
| --- | --- |
| xmlan `src/xmlan.erl`, `include/xmlan.hrl` | Parsing/prologs, strict UTF-8, full-input and DTD/PI restrictions, serialization/escaping, tree/value helpers, and namespace validation/resolution/context/projection. |
| xmlan `src/xmlan_c14n.erl` | Generic C14N 1.1 and Exclusive canonicalization. |
| Signerl `src/signerl.erl` | Public key/file dispatch and signing/verification workflows. |
| Signerl signature/verifier/XAdES/certificate/utils modules | XMLDSig/XAdES identities/builders/rules, reference digests, certificate properties, algorithm routing, dates/time, and cryptography. |
| Signerl `src/signerl_xml.erl` | Sixteen single-call generic delegates and five transparent aliases; two signature-identity predicates remain local. |
| Signerl `src/signerl_c14n.erl` | Two direct canonicalization delegates and a transparent mode alias; immediate-child enveloped-signature removal remains local. |
| Signerl `include/signerl_xml.hrl` | Only a forwarding include of dependency-owned `xmlan.hrl`. |
| Signerl `include/signerl_dsig.hrl` | Signature/XAdES constants and identifiers. |

The final audit covers all ten Signerl production modules, both local headers,
application/dependency configuration, and both xmlan production modules. All 41
original generic XML functions and 30 generic C14N functions have the same
preprocessed function AST in xmlan. All 104 functions in Signerl's other eight
production modules match the baseline after retargeting generic public calls.
The two compatibility modules have only the documented 18 direct delegates and
three protocol functions. There is no maintained parser/serializer/namespace/
canonicalizer or fallback copy in Signerl production source.

The permanent `signerl_xmlan_ownership_SUITE` checks exact compatibility function
inventories, clause/argument-preserving direct delegates, all six transparent
exported type aliases, and the forwarding header. It examines compiled imports:
Signerl has no xmerl or dynamic apply import; internal compatibility calls are
limited to signature identity/removal, and every xmlan call resolves to an actual
public dependency export. xmlan has no Signerl import/application/dependency;
its only runtime applications are OTP kernel/stdlib/xmerl. Its own native gate
and CI run without Signerl. No private xmlan implementation access is needed.
These seam checks complement the complete source review; they are not a claim to
classify arbitrary future algorithms automatically.

## Clean external consumer

From a checkout with the pinned OTP/rebar3 toolchain, Bash and HTTPS Git access:

```sh
scripts/check_external_consumer.sh <published-Signerl-full-SHA> <new-directory>
```

The directory must not exist. The script creates an ordinary rebar3 application
with a single HTTPS/Git Signerl dependency at the supplied full SHA. xmlan is
resolved transitively through Signerl's committed configuration/lockfile. It
clears inherited Erlang paths/flags and rebar overrides, uses empty global
configuration and its own cache, and copies only the two public consumer test
modules into its own `src/`. It uses no local checkout dependency, source link,
patch, test-helper code path, or private library function.

`rebar3 compile`, actual runtime assertions, and the consumer's own
`rebar3 dialyzer` must pass. The consumer directly uses Signerl/xmlan/public_key,
so its application metadata declares those runtime applications; its dependency
configuration still names only Signerl. Fetched Git HEADs, HTTPS remotes, both
lock levels, and clean dependency working trees are checked. Signerl's public
headers/types are resolved from the fetched package.

The consumer exercises `sign/3`, `sign/4`, `sign/5`, and `verify/3` with binary/file
XML, fresh in-memory RSA keys and a matching certificate. It verifies valid and
reconstructed documents before requiring tampering and wrong-key rejection. It
also runs the original frozen consumer: every compatibility export, six public
transparent types, the forwarding include, exact parsed/exported/canonical bytes,
frozen signature verification, and fixed-time fresh signing. No private key is
written or published. Independent fixtures and ECDSA remain in the full native/
CI equivalence suite. CI runs the clean external consumer after tall on every
OTP 26/27/28 Ubuntu/Windows job using the actual published PR head.

Native clean-fetch validation first used merged Signerl
`cf4fd4f80822d30e7c1154e43b73941d7ecd7e55`. Production/configuration are unchanged
by #89. The PR records the repeat against its exact published head and all six
CI consumer results. A separate opaque-only compatibility copy makes the same
external Dialyzer consumer fail with actual opacity findings; the positive fetch
remains unmodified.

## Test ownership and final gates

The [complete 257-entry baseline map](../test/examples/xmlan_migration/ownership.term)
and its executable inventory check cover all original 426 tests. Split parser/
C14N contracts explicitly list both owners. See [Signerl test responsibilities](../test/TESTS.md)
and [xmlan's tests](https://github.com/bormilan/xmlan/blob/1fe39f6d414217584f514e70e43b8e7b4171f1ef/test/TESTS.md).

- Signerl: 150 EUnit + 86 CT = **236 cases**; all ten production modules and total
  **100% coverage**. Native test/cover/flint/Dialyzer/final tall pass with no skips.
- Exact-pin xmlan: 236 EUnit + 23 CT = **259 cases**, both modules/total **100%**;
  native tall and all six [final CI jobs](https://github.com/bormilan/xmlan/actions/runs/39013046603)
  pass, including xmllint. The Signerl pin equals that tested revision exactly.
- Four temporary ownership mutations fail the new gates: a hidden helper, altered
  delegate arguments, direct xmerl import, and private dependency call. The opaque
  control fails external Dialyzer. All are restored/isolated before final gates.
- All six latest-head Signerl jobs must pass tall **and** the clean consumer,
  without skipped required checks. Exact-head job logs and consumer/type results
  are recorded in the PR and persistent implementation recovery.

No coverage exclusions, weakened assertions, skipped required checks, duplicate
engines, signature-profile/algorithm/certificate/failure-policy redesign, or new
XML feature guarantees are introduced. Historical sources under ignored
`priv/xml-baseline` serve only the immutable isolated #88 test oracle; they never
enter the production application or its code path.

## Merge and milestone closure

GitHub actual state was checked after the prerequisite merges: #83 through #88
are completed/closed, including merged Signerl PR #92 and xmlan PRs #1–#3.
[Milestone #6](https://github.com/bormilan/signerl/milestone/6) has exactly one
remaining open issue, #89. This PR supplies its final acceptance evidence.

Keep the milestone open until #89 is merged. After merge, verify the merged
implementation and latest checks, confirm/close #89 as completed if needed
(`dev` is not the default branch), confirm all seven linked issues are closed,
then close the milestone. No PR is automatically merged and the default branch
is unchanged. The remaining step at review time is this merge/closure procedure.

Implementation details and recovery:
[issue #89 log](implementations/issue_89_final_xml_audit_2026-10-17.md).
