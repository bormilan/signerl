# Task: add_local_docker_otp_matrix_checks

## 1. Goal
Provide a local Docker-based workflow to run CI-equivalent checks for Linux OTP versions (26 and 27): tests, lint, and dialyzer.

## 2. Scope
- In scope: add Docker assets and scripts to run local checks for OTP 26 and OTP 27.
- In scope: run local check sequence equivalent to CI quality gates:
  - `scripts/gen_certs.sh`
  - `rebar3 test`
  - `rebar3 lint`
  - `rebar3 dialyzer`
- In scope: include persistent cache strategy for `_build` and rebar3 cache to reduce repeated run time.
- In scope: document usage and expected behavior.
- Out of scope: emulating Windows runner behavior locally.
- Out of scope: replacing GitHub Actions matrix as source of truth.

## 3. Constraints
- Keep implementation simple and deterministic.
- Reuse official Erlang Docker images when possible.
- Keep OTP version list explicit and easy to update.
- Avoid broad CI refactors; this is a local workflow enhancement.

## 4. Acceptance Criteria
1. A single local command runs checks for OTP 26 and OTP 27 in Docker.
2. For each OTP version, the workflow runs:
   - `scripts/gen_certs.sh`
   - `rebar3 test`
   - `rebar3 lint`
   - `rebar3 dialyzer`
3. If any step fails for any OTP version, the local workflow exits non-zero.
4. Docker cache volumes are used for `_build` and `~/.cache/rebar3` (per OTP) to improve repeated runs.
5. Documentation explains prerequisites, usage command, and known limits (Linux-only parity; no Windows emulation).

## 5. Iteration Plan
### Iteration 1
- Design local runner layout:
  - decide between `docker-compose` and shell-only runner (preferred minimal path: shell script with `docker run`).
  - define version matrix in one place (for example `OTP_VERSIONS="26 27"`).

### Iteration 2
- Implement Docker workflow assets:
  - add Docker runner script (for example `scripts/ci_local_docker.sh`).
  - use official Erlang images for OTP 26 and OTP 27.
  - mount workspace + per-OTP cache volumes.
  - execute command sequence in deterministic order.

### Iteration 3
- Validate locally:
  - run local Docker workflow end-to-end.
  - confirm pass/fail behavior and cache reuse on second run.
- Update docs and implementation log:
  - usage instructions
  - constraints/limitations
  - validation commands and outcomes

## 6. Risks and Edge Cases
- First `dialyzer` run may be slow due to PLT/cold caches.
- Container UID/GID mismatch can create host file ownership issues if not handled.
- Network/download failures may affect first-time image pull and dependency setup.
- Local Docker checks can mirror Linux CI behavior only; Windows-specific issues remain CI-only.

## 7. Open Questions
- Should the runner support optional subset execution (for example only OTP 27) via flags?
  - Proposed: yes, optional flag can be a follow-up unless trivial to add now.
- Should the workflow run versions sequentially (default) or parallel (faster, higher host load)?
  - Proposed default: sequential for predictable logs/resource usage.

## 8. Done Definition
- [ ] Local Docker OTP matrix runner added
- [ ] OTP 26 and OTP 27 checks run via one command
- [ ] Cache volumes configured and documented
- [ ] Docs updated with usage and limits
- [ ] Implementation log added/updated in `docs/implementations/`
