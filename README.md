# SignerL

SignerL is a small Erlang library for signing XML messages. It currently supports
basic signing and verification over normalized XML. The project is early-stage
and evolving, but active.

## Status

Early development. APIs may change and XML-DSig compliance is not complete yet.

## Features

- Sign an XML message using a private key.
- Verify a signature using a public key.

## Quick Start

```erlang
% Sign from a binary message and a loaded key:
{ok, SignedMessage} = case signerl:sign(RawMessage, sha256, PrivateKey) of
    {error, invalid_prolog} -> {error, invalid_prolog};
    SignedXml -> {ok, SignedXml}
end.

% Verify:
true = signerl:verify(SignedMessage, sha256, PublicKey).
```

`sign/3` returns signed XML with `<ds:Signature><ds:SignatureValue>...</ds:SignatureValue></ds:Signature>`.

`verify/3` expects a signed XML message. It returns:
- `true` when signature verification succeeds
- `false` when signature bytes are present but do not match message/key
- `{error, invalid_prolog}` when XML prolog is missing/invalid
- `{error, invalid_signature}` when signature structure is missing or malformed

## Tests

Run tests with rebar3:

```bash
rebar3 test
```

## Test Certificates

Generate test-only keys and certificates:

```bash
scripts/gen_certs.sh
```

Docs for the generated artifacts:
`test/certs/README.md`

## Contributing

Issues and PRs are welcome. Keep changes small and focused.
