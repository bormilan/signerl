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
Digest = signerl:sign(RawMessage, sha256, PrivateKey).

% Verify:
true = signerl:verify(RawMessage, sha256, Digest, PublicKey).
```

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
