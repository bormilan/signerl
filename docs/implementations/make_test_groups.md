# Implementation: make_test_groups

## What Changed

- Refactored `test/signerl_SUITE.erl`:
  - Split the single flat `sign_group` (47 tests) into 5 focused groups:
    - `build_group` (5 tests) — signature element building tests
    - `sign_group` (10 tests) — sign and sign-verify round-trip tests
    - `verify_fixture_error_group` (15 tests) — fixture-based verify error tests
    - `verify_signed_info_error_group` (18 tests) — SignedInfo structure manipulation tests
    - `verify_tamper_group` (4 tests) — tamper-then-verify tests
  - 2 standalone tests remain outside groups (`extract_signature_returns_error_without_signature_element_direct`, `xades_xml_returns_error_with_non_signature_input`)
  - Added `init_per_group` callbacks that preload shared test data per group:
    - base message, RSA/ECDSA keys, public keys, `valid_signature_data()`
  - Replaced inline key/message/cert loading in test functions with `?config(key, Config)` lookups
  - Added `-include_lib("common_test/include/ct.hrl")` for `?config` macro
  - Renamed internal helper `valid_signature_data/0` to `compute_valid_signature_data/0`

## Why This Solves The Task

- Eliminates heavy duplication: `signer_rsa_key()`, `rsa_public_key_from_cert()`, `file:read_file()`, and `valid_signature_data()` (sign→parse→extract) were each called 10–15 times across tests. Now they run once per group.
- Makes the test suite faster by sharing expensive setup across tests in the same group.
- Makes it easier to add new tests — just add to the right group and use Config.
- Preserves all existing test behavior (no assertion changes, no API changes).

## Validation

- `rebar3 eunit`: 13 tests, 0 failures
- `rebar3 ct`: 61 tests (54 grouped + 7 signed_properties_SUITE), 0 failures
- `rebar3 as test cover`: 100% total coverage
- `rebar3 flint`: clean
- `rebar3 dialyzer`: clean

## Documentation

- No public API or behavior changes; no docs updates required beyond this implementation log.
