# Issue #54 — certificate metadata and key binding

## Scope and investigation

Implement the settled certificate-bearing profile: valid embedded X509Certificate
paired with SigningCertificateV2, certificate digest/issuer checks and binding to
the supplied signing/verification key. Both absent remains certificate-less signing.
Certificate chain trust, validity periods and revocation remain outside scope.

PR #96 merged into dev as 3194b685e450e714113efc1e3e660197503f02f8.
Its tree matches validated head c2c9ad0cc4850dcdaa46e3fc444d07812a6ad98d;
all six latest-head jobs passed. #52 is already closed as completed.
Read #54, the API/profile decisions, certificate builder, verifier, signed-property
readers and existing unit/integration tests. No CodeGraph index exists here.

Tests are added before changing the implementation. Shared signature mutation
and direct OTP re-signing helpers move into test_helpers so both policy suites
use the same passing controls without depending on another suite.
## Implementation and behavior

- signerl_cert decodes one complete DER certificate, extracts its public key and
  issuer/serial once, and checks the supported SubjectPublicKeyInfo algorithm.
  rsaEncryption and id-ecPublicKey are supported for the existing operations;
  RSA-PSS key restrictions cannot be silently discarded for PKCS#1 signatures.
  The existing IssuerSerial encoding is reused, with its exact ASN.1 unit control.
- signerl_signature checks its produced signature against the supplied certificate
  key and raises certificate_key_mismatch on disagreement. Invalid caller DER/key
  material remains native failure; no broad catch wraps the signing operation.
- signerl_verify distinguishes absent, malformed and valid KeyInfo metadata.
  Exactly one selected child is required at each KeyInfo/X509Data level; formatting
  whitespace is allowed, extra key fields/nested certificate containers rejected.
  Malformed base64/DER and duplicate/missing metadata do not become undefined.
  The certificate/V2 pair is required when either component is present. The
  certificate digest and optional DER issuer/serial must match. Final verification
  checks both caller and certificate keys against the signature. The narrow catch
  for malformed embedded crypto keys excludes the caller-key operation.
- signerl_signed_properties rejects ambiguous CertDigest/DigestMethod/DigestValue
  and IssuerSerialV2 fields. Malformed present issuer data no longer becomes
  absence. IssuerSerialV2 remains optional; omission has a passing public control.
- include/signerl_dsig.hrl names the supported and negative-fixture key OIDs.
- New signerl_certificate_binding_SUITE has 13 public policy cases. Mutations
  refresh reference digests and re-sign SignedInfo directly with OTP; each rejected
  structure retains a successful direct signature control. Tests include same-key
  and cross-algorithm certificate substitutions, invalid DER/trailing bytes,
  malformed RSA/EC public keys, algorithm restrictions, duplicates, one-sided
  metadata, issuer/digest mismatch, namespaces and certificate-less arities.
- Existing tests that accepted absent-on-malformed certificates/issuer data and
  one-sided metadata now require errors. test_helpers owns the shared stack-based
  mutation/re-signing controls; policy suites do not depend on each other. Test
  certificate reconstruction belongs in signerl_cert_helpers.
- README, API contract, signing profile, property-gap map and test responsibility
  map describe the public changes. These updates are required because the
  certificate-bearing verification guarantee and failure behavior changed.
  No generic XML implementation, dependency tests or consumer application is added.

## Validation and review

- Initial public regressions: 8 failures / 2 passes. Reproduced true for invalid
  embedded base64, duplicate/missing KeyInfo, duplicate certificate digest,
  inconsistent issuer data and unrelated certificates. Signing with an unrelated
  certificate also succeeded before enforcement. See ct-red.log.
- Review found an invalid embedded EC point could escape as an OTP crypto error;
  the focused test failed first, then passed with the scoped metadata boundary.
  Caller-key/DER native-failure regressions remain passing.
- Review also reproduced acceptance of an RSA-PSS-restricted certificate for a
  PKCS#1 operation, and extra/nested key-container contents. Focused red/green logs
  document both fixes before the final full suite.
- rebar3 test: PASS, 150 EUnit + 97 CT = 247 cases; all eight production modules
  and total coverage 100%. No failures or skipped cases.
- rebar3 flint: PASS; no disabled lint/format rules. Shared fixture setup and
  duplicated mutation functions were simplified in response to lint findings.
- rebar3 dialyzer: PASS, all eight production modules analyzed.
- Applied ferike: no blocking findings after fixing the key restrictions and
  metadata boundaries. Certificate parsing is owned by signerl_cert, signature
  policy by the verifier/builder, and test fixture mutation by test helpers.
  Remaining known-property structural work is #55; ownership cleanup is #58;
  ECDSA wire format remains #53. Certificate chain trust, dates and revocation
  remain deliberately outside this boolean verifier.
- Native runs use OTP 28.4.2 / rebar3 3.25.1, normal project builds/caches and the
  documented empty REBAR_GLOBAL_CONFIG_DIR under recovery storage. Project
  plugins/checks remain enabled; user-global settings were not modified.
- rebar3 as test cover and final native rebar3 tall: PASS, 247 tests,
  all eight modules/total coverage 100%, formatting/lint, Xref and Dialyzer.
  No failed or skipped checks. Markdown links/fences, test-map counts and
  git diff --check: PASS.
- All six latest-head OTP 26/27/28 Ubuntu/Windows tall jobs must pass before merge;
  their immutable run/commit evidence is saved in recovery after pushing.

IssuerSerialV2 binding uses the certificate issuer/directoryName and serial
encoding described by RFC 5035: https://www.rfc-editor.org/rfc/rfc5035.
Optional issuer presence and the exact paired/single-certificate restrictions
are recorded in the public profile; binding does not imply certificate trust.

## Persistence

Persistent worktree: /Users/milanbor/.codex/worktrees/signerl-issue-56/signerl.
Recovery snapshots, source copies, diffs and command logs are kept outside temporary
storage at /Users/milanbor/projects/signerl/.recovery/issue-54-certificate-binding/.
The local roadmap-sync audit note was stashed before switching branches and
restored; it is retained outside the issue #54 commit.

## CI compatibility correction

The first matrix run (40468371625, head 5e7f7ec) reproduced an OTP 26/27 compile
failure: ECPoint is not defined by their narrower OTP-PUB-KEY.hrl. The local
OTP 28 header layout had allowed that reference. Use the documented public
public_key.hrl header, which supplies the public-key records across supported
OTP releases. No gate or test is disabled. After correction, native test,
flint, Dialyzer and final tall pass again: 150 EUnit + 97 CT, all eight
modules/total coverage 100%, no failures/skips. All six latest-head CI jobs must
pass again after pushing; immutable evidence is retained in recovery storage.
