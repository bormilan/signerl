# Deterministic signing time and Gregorian dates (#56)

## Changes and acceptance criteria

`signerl:sign/5` and `signerl_signature:build_signature_element/5` accept an explicit
UTC timestamp binary. Existing signing arities capture the current UTC second
once, then use the same implementation, including file/key loading. The fixed
time is validated before signature construction and included in signed metadata.
Invalid signing times return `{error, invalid_signing_time}`.

`signerl_utils:valid_utc_timestamp/1` now checks real Gregorian dates with
`calendar:valid_date/1`, including century leap-year rules, and years 0001–9999.
The existing strict UTC seconds-only representation remains. The extracted
`format_utc_timestamp/1` formats a valid UTC datetime independently of the clock;
fixed boundary expectations cover zero padding reliably.

README explains deterministic normalization versus metadata-dependent RSA
output and randomized ECDSA signatures. `test/TESTS.md` records the new utility
suite and controlled-time workflow cases.

## Validation and review

Before implementation, the utility regressions ran 25 cases with nine failures:
six impossible dates were accepted and three formatting calls were unavailable.
After generating test certificates, the API sign group ran 27 cases with three
failures from the missing controlled-time API; 24 existing cases passed.
An earlier prerequisite run skipped the group because this fresh worktree had
no generated certificates; it is superseded by the actual baseline and final runs.

Focused utility/builder/property EUnit: 96 cases passed. Public signing CT group:
27 cases passed with no skips. Fixed-time RSA signatures verify and are identical;
a different time changes the output and still verifies. File/key/certificate
entry points preserve the fixed time. ECDSA is only checked by verification.
Verification rejects a mutation to an impossible signing date before reporting
cryptographic success. The ferike checklist found no blocking behavior issues;
public arity wrappers preserve compatibility while sharing file/error handling.

Full native `rebar3 test`: 246 EUnit + 84 CT = 330 cases passed, no skips,
100% total coverage. `rebar3 as test cover`, `rebar3 flint`, `rebar3 dialyzer`,
and final native `rebar3 tall` all passed. `git diff --check` passed.
Native toolchain: installed OTP 28.4.2 and pinned rebar3 3.25.1 with isolated
empty global configuration; CI uses pinned OTP 28.5.0.7 plus OTP 26/27.
CI compatibility matrix: pending publication.

## Persistence

Worktree: `/Users/milanbor/.codex/worktrees/signerl-issue-56/signerl`.
Branch: `codex/issue-56-deterministic-time`.
Recovery diffs, untracked sources, and command logs:
`/Users/milanbor/projects/signerl/.recovery/issue-56`.
