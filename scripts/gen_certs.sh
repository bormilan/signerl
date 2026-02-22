#!/usr/bin/env bash
set -euo pipefail

# Generate test-only keys and certificates for SignerL.
# Output directory is priv/certs under the project root.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$ROOT_DIR/priv/certs"
mkdir -p "$OUT_DIR"
cd "$OUT_DIR"

# On Windows (Git Bash/MSYS), prevent path conversion of /C=... in -subj values.
if [[ "${OS:-}" == "Windows_NT" ]] || [[ "${MSYSTEM:-}" == MINGW* ]]; then
  export MSYS2_ARG_CONV_EXCL="*"
fi

# 1) OpenSSL config with extensions used below.
cat > openssl.cnf <<'CONF'
[ req ]
default_bits        = 2048
distinguished_name  = dn
prompt              = no
string_mask         = utf8only

[ dn ]
C  = US
ST = State
L  = City
O  = SignerL Test
OU = Dev
CN = placeholder

[ v3_root_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:1
keyUsage = critical, keyCertSign, cRLSign

[ v3_intermediate_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, keyCertSign, cRLSign

[ v3_leaf ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth

[ v3_signer_only ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
CONF

# 2) Root CA (self-signed)
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out root_ca.key.pem
openssl req -new -x509 -days 3650 -key root_ca.key.pem -out root_ca.cert.pem \
  -config openssl.cnf \
  -subj "/C=US/ST=State/L=City/O=SignerL Test/OU=Root/CN=SignerL Root CA" \
  -extensions v3_root_ca

# 3) Intermediate CA (signed by Root CA)
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out intermediate_ca.key.pem
openssl req -new -key intermediate_ca.key.pem -out intermediate_ca.csr.pem \
  -config openssl.cnf \
  -subj "/C=US/ST=State/L=City/O=SignerL Test/OU=Intermediate/CN=SignerL Intermediate CA"
openssl x509 -req -in intermediate_ca.csr.pem \
  -CA root_ca.cert.pem -CAkey root_ca.key.pem -CAcreateserial \
  -out intermediate_ca.cert.pem -days 1825 \
  -extfile openssl.cnf -extensions v3_intermediate_ca

# 4) Leaf (end-entity) certificate (signed by Intermediate CA)
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out leaf.key.pem
openssl req -new -key leaf.key.pem -out leaf.csr.pem \
  -config openssl.cnf \
  -subj "/C=US/ST=State/L=City/O=SignerL Test/OU=Leaf/CN=SignerL Leaf"
openssl x509 -req -in leaf.csr.pem \
  -CA intermediate_ca.cert.pem -CAkey intermediate_ca.key.pem -CAcreateserial \
  -out leaf.cert.pem -days 825 \
  -extfile openssl.cnf -extensions v3_leaf

# 5) Full chain bundle (leaf + intermediate + root)
cat leaf.cert.pem intermediate_ca.cert.pem root_ca.cert.pem > chain_full.cert.pem

# 6) Self-signed RSA signer certificate
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out signer_rsa.key.pem
openssl req -new -x509 -days 825 -key signer_rsa.key.pem -out signer_rsa.cert.pem \
  -config openssl.cnf \
  -subj "/C=US/ST=State/L=City/O=SignerL Test/OU=Signer/CN=SignerL Self-Signed RSA" \
  -extensions v3_signer_only

# 7) Self-signed ECDSA signer certificate (P-256)
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:prime256v1 -out signer_ecdsa.key.pem
openssl req -new -x509 -days 825 -key signer_ecdsa.key.pem -out signer_ecdsa.cert.pem \
  -config openssl.cnf \
  -subj "/C=US/ST=State/L=City/O=SignerL Test/OU=Signer/CN=SignerL Self-Signed ECDSA" \
  -extensions v3_signer_only

echo "Done. Generated test certs in $OUT_DIR"
