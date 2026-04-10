# Phase 1 Completion: KeyInfo, Exclusive C14N, Dedup

## What Changed

### Files and Behavior

**`src/signerl.erl`**
- Added `sign/4` accepting optional `CertDer :: binary()` parameter for embedding X.509 certificates.
- `sign/3` delegates to `sign/4` with `undefined`.
- Both `sign/3` and `sign/4` support file path convenience clauses for message and key paths.
- `verify/3` now auto-detects C14N mode from the signature's `CanonicalizationMethod` algorithm URI.

**`src/signerl_signature.erl`**
- `build_signature_element/3` → `/4` with optional `CertDer`.
- Added `key_info/1` helper that builds `ds:KeyInfo > ds:X509Data > ds:X509Certificate` or returns `[]` when `CertDer` is `undefined`.
- `add_signature_value/2` handles variable children count (with/without KeyInfo).

**`src/signerl_verify.erl`**
- Removed local `is_signature_element/1` (consolidated to `signerl_xml`).
- Added `c14n_mode/1` to resolve C14N mode from signature data (supports C14N 1.1 and Exclusive C14N).
- Added `extract_key_info/1` and `extract_x509_certificate/1` for parsing `ds:KeyInfo` from signatures.
- Added `is_supported_c14n/1` recognizing both `?DSIG_C14N11_ALGO_URI` and `?DSIG_EXC_C14N_ALGO_URI`.
- Exported `c14n_mode/1`.

**`src/signerl_c14n.erl`**
- Major restructure: split into `c14n11_element/2` (C14N 1.1) and `exc_element/3` (Exclusive C14N) code paths.
- Added `exc_needed_decls/3` to determine which namespace declarations to emit based on visible utilization.
- Added `visibly_used_prefixes/2`, `extract_prefix/1`, `prefix_to_ns_decl/1` helpers.
- Exported `c14n_mode()` type.

**`src/signerl_xml.erl`**
- Added `is_signature_element/1` (consolidated from `signerl_verify` and `signerl_c14n`).

**`include/signerl_dsig.hrl`**
- Added `?DSIG_EXC_C14N_ALGO_URI` macro.

### Tests

**`test/signerl_SUITE.erl`**
- Updated all `build_signature_element/3` calls to `/4` with `undefined`.
- Added `keyinfo_group` (7 tests): sign with/without cert, roundtrip RSA/ECDSA, file path convenience clauses, KeyInfo extraction, absent KeyInfo.
- Added `interop_smoke_group` (2 tests): C14N idempotency, `is_signature_element` shared.
- Added standalone tests: `c14n_mode` for exc_c14n, `extract_x509_certificate` error paths, `sign/4` file error paths, exc_c14n algorithm acceptance.

**`test/signerl_c14n_SUITE.erl`**
- Added `exc_c14n_group` (8 tests): omits unused ns, keeps visibly used ns, propagates ns to children, binary text child, default namespace, ns already in output scope, C14N 1.1 comparison, `canonicalize/1` defaults.

**`test/test_helpers.erl`**
- Added `cert_der/1` helper for loading raw DER from PEM certificate files.

## Why This Solves the Task

This completes all remaining Phase 1 roadmap items:
- **#35 Exclusive C14N**: Full implementation with separate code path, proper visible utilization tracking, and comprehensive tests.
- **KeyInfo/X.509**: `sign/4` embeds certificate in `ds:KeyInfo`, verification extracts and returns it.
- **Dedup `is_signature_element/1`**: Consolidated to `signerl_xml`, eliminating code duplication.
- **Dead code removal**: Verified no dead code remains after C14N restructure.

## Validation

| Gate | Result |
|------|--------|
| `rebar3 eunit` | 14 tests, 0 failures |
| `rebar3 ct` | 124 tests, 0 failures |
| `rebar3 as test cover` | 100% total coverage |
| `rebar3 flint` | Clean |
| `rebar3 dialyzer` | Clean |

## Documentation

No public-facing documentation updates required — `sign/4` follows the existing `sign/3` convention and the README already references the signing API. Exclusive C14N is an internal capability used by the verification pipeline.

## CI Cover Fix

**Root cause:** The `test` alias in `rebar.config` ran `erlfmt` (write mode) between `eunit` and `ct --cover`. This reformatted source files mid-run, causing eunit and ct to cover-compile different source versions. When the coverdata was merged, phantom uncovered lines appeared (e.g., `signerl_c14n` dropped to 82% on OTP 27/28).

**Fix:** Moved `fmt` before `cover --reset` in both `test` and `tall` aliases, ensuring both eunit and ct instrument the same post-format source. Also removed temporary CI artifact upload step and let `erlfmt` normalize `render_element` formatting.
