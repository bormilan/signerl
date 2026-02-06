# Test Certificates and Keys

These files are test-only artifacts generated with OpenSSL for XML signature experiments.
They are **not** intended for production use.

## Summary

This folder contains three kinds of certificate setups. The generated files live under
`priv/certs/` so they are not committed to git.

- A **certificate chain** (Root CA -> Intermediate CA -> Leaf).
- A **self-signed RSA signer** (standalone, no chain).
- A **self-signed ECDSA signer** (standalone, no chain).

## Certificate Chain (Root -> Intermediate -> Leaf)

Files (all under `priv/certs/`):

- `root_ca.key.pem` / `root_ca.cert.pem`
- `intermediate_ca.key.pem` / `intermediate_ca.csr.pem` / `intermediate_ca.cert.pem`
- `leaf.key.pem` / `leaf.csr.pem` / `leaf.cert.pem`
- `chain_full.cert.pem` (leaf + intermediate + root)
- `root_ca.cert.srl` / `intermediate_ca.cert.srl` (CA serial files)
- `openssl.cnf` (OpenSSL extensions config used by the script)

Purpose:

- **Root CA** signs the Intermediate CA. It is the trust anchor.
- **Intermediate CA** signs the Leaf certificate. It can be rotated without changing the Root.
- **Leaf** is what you actually use to sign XML.

Use notes:

- For verification, you typically trust `root_ca.cert.pem`,
  and provide `intermediate_ca.cert.pem` along with the leaf.
- `chain_full.cert.pem` is a convenience bundle containing the full chain.

## Self-Signed RSA Signer

Files (all under `priv/certs/`):

- `signer_rsa.key.pem`
- `signer_rsa.cert.pem`

Purpose:

- A simple RSA key + certificate pair that can sign XML directly.
- No chain. The certificate is self-signed.

Key properties:

- RSA 2048-bit key
- Key usage: `digitalSignature`

## Self-Signed ECDSA Signer

Files (all under `priv/certs/`):

- `signer_ecdsa.key.pem`
- `signer_ecdsa.cert.pem`

Purpose:

- A simple ECDSA (P-256) key + certificate pair that can sign XML directly.
- No chain. The certificate is self-signed.

Key properties:

- ECDSA P-256 key
- Key usage: `digitalSignature`

## How To Pick

- Use the **certificate chain** if you want to demonstrate full PKI-style validation.
- Use **self-signed RSA** if you want the simplest possible demo with RSA.
- Use **self-signed ECDSA** if you want to compare RSA vs ECDSA signatures.

## Notes

- All certificates use test subjects under `O=SignerL Test`.
- All certificates include basic key usage extensions.
- These are intentionally small and simple for learning and testing.

## Regenerate Everything

Run:

```bash
scripts/gen_certs.sh
```

## Where Each Artifact Is Generated (with Line Numbers)

The following references point to the exact command lines in `scripts/gen_certs.sh`.

- `openssl.cnf` is written at line 14.
- `root_ca.key.pem` is generated at line 56.
- `root_ca.cert.pem` is generated at lines 57-60.
- `intermediate_ca.key.pem` is generated at line 63.
- `intermediate_ca.csr.pem` is generated at lines 64-66.
- `intermediate_ca.cert.pem` is generated at lines 67-70.
- `leaf.key.pem` is generated at line 73.
- `leaf.csr.pem` is generated at lines 74-76.
- `leaf.cert.pem` is generated at lines 77-80.
- `chain_full.cert.pem` is generated at line 83.
- `signer_rsa.key.pem` is generated at line 86.
- `signer_rsa.cert.pem` is generated at lines 87-90.
- `signer_ecdsa.key.pem` is generated at line 93.
- `signer_ecdsa.cert.pem` is generated at lines 94-97.
