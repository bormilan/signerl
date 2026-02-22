# Task: return_signed_message

## 1. Goal
Return the signed XML message from `sign/3`, and make verification consume that signed XML directly.

## 2. Scope
- In scope: modify `sign/3` in `src/signerl.erl` to return a signed message binary.
- In scope: change verification API from `verify/4` to `verify/3`:
  - `verify(SignedMessage, HashAlgorithm, Key)`
- In scope: parse `SignedMessage` into `{SignatureValue, MessageWithoutSignature}` in verify flow.
- In scope: add `<ds:SignatureValue>` under existing `<ds:Signature>` element.
- Out of scope: unrelated signature algorithm changes.

## 3. Constraints
- Backward compatibility is not required for this task.
- Keep implementation simple; do not add broad refactors.

## 4. Acceptance Criteria
1. `sign/3` returns signed XML message binary, not raw digest.
2. Signed XML contains `<ds:Signature><ds:SignatureValue>...</ds:SignatureValue></ds:Signature>`.
   - `<ds:SignatureValue>` stores base64-encoded signature bytes.
3. `verify/3` extracts signature value and message (message must exclude `<ds:Signature>` subtree).
4. `verify/3` calls `public_key:verify(MessageWithoutSignature, HashAlgorithm, SignatureValue, Key)`.
5. `verify/3` behavior for invalid signature shapes:
   - no `<ds:Signature>` element -> `{error, invalid_signature}`
   - `<ds:Signature>` without `<ds:SignatureValue>` -> `{error, invalid_signature}`
   - empty `<ds:SignatureValue>` -> `{error, invalid_signature}`
   - non-base64 `<ds:SignatureValue>` -> `{error, invalid_signature}`
6. If `<ds:SignatureValue>` is present but does not match message digest/key, `verify/3` returns `false`.
7. Existing sign tests are updated for new return contract; no additional sign-only coverage required.
8. Tests pass: `rebar3 eunit` and `rebar3 ct`.
9. Lint/quality check passes: `rebar3 flint`.
10. Static analysis passes: `rebar3 dialyzer`.

## 5. Public API Change
- `verify/4` is removed/replaced by `verify/3`.
- Callers now pass signed XML into `verify/3` instead of `(Message, Digest)` pair.
- This is an intentional breaking change.

## 6. Signing and Verification Flow
### Signing (`sign/3`)
1. Parse and validate input message into signable message form (existing prolog rules still apply).
2. Compute signature bytes over the whole message without any signature element.
3. Insert `<ds:Signature>` with child `<ds:SignatureValue>` carrying computed signature bytes.
   - signature bytes must be base64-encoded before insertion.
4. Export full XML as signed message and return it.

### Verification (`verify/3`)
1. Parse signed message.
2. Extract `<ds:SignatureValue>` and remove `<ds:Signature>` from message to reconstruct `MessageWithoutSignature`.
3. Validate signature shape (signature/value presence and non-empty value).
4. Base64-decode `SignatureValue` and run `public_key:verify(MessageWithoutSignature, HashAlgorithm, SignatureBytes, Key)`.
5. Return `true | false` for cryptographic result, or `{error, invalid_signature}` for malformed signature structure.

## 7. Iteration Plan
### Iteration 1
- Update tests first:
  - migrate call sites from `verify/4` to `verify/3`
  - update existing sign tests to assert signed message contract
  - add verify fixture coverage for:
    - missing signature element
    - signature element missing signature value
    - empty signature value
    - present signature value but invalid digest bytes for the message/key

### Iteration 2
- Implement change:
  - modify `sign/3` in `src/signerl.erl` to return signed message
  - replace `verify/4` with `verify/3`
  - add signature insertion/parsing helpers in signature/xml modules as needed

### Iteration 3
- Run quality gates:
  - `rebar3 eunit`
  - `rebar3 ct`
  - `rebar3 flint`
  - `rebar3 dialyzer`

## 8. Risks and Edge Cases
- Intentional API break for existing callers.
- Canonicalization consistency: sign and verify must reconstruct identical `MessageWithoutSignature` bytes.
- Namespace handling for `ds:Signature` and `ds:SignatureValue` should remain deterministic.
- Prolog handling must remain consistent with existing `{error, invalid_prolog}` contract.

## 9. Done Definition
- [ ] Tests updated and passing
- [ ] Quality gates pass
- [ ] Implementation log added/updated in `docs/implementations/`
- [ ] Public docs updated for API break (`README.md`, relevant test/docs files)
