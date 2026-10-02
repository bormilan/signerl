# Independent signature fixtures

These RSA-SHA256 signatures were produced and verified with `xmlsec1 1.2.41
(openssl)` (Debian package `1.2.41-1+b1`) on 2026-09-30. SignErl did not compute
their digest or signature values. Each verification reported `OK` and
`SignedInfo References (ok/all): 2/2`.

- `c14n11.xml`: SignedInfo uses Canonical XML 1.1.
- `exclusive.xml`: SignedInfo uses Exclusive Canonicalization without comments.
  Its unused namespace declaration makes inclusive and exclusive canonicalization
  produce different SignedInfo bytes.
- `rsa-public.pem`: the public key used to verify both fixtures.
- `*-template.xml`: unsigned inputs for reproducing the fixtures.

Both signatures cover the invoice via an enveloped reference and SignedProperties
via its ID. They contain a fixed SigningTime and omit KeyInfo; verification uses
the supplied public key. The tests verify the original and a parse/export round
trip, then independently change the amount and SigningTime and expect rejection.
Ordinary test runs only read these files and do not require `xmlsec1`.

## Scope

The fixtures deliberately use explicit namespace declarations on SignedInfo and
SignedProperties, ASCII content, and no inter-element indentation. This keeps
their namespace context available to the current fragment canonicalizer. The
Exclusive C14N setting applies to SignedInfo; neither fixture adds an Exclusive
C14N transform to its references.

These are bounded interoperability regressions, not a claim of full XMLDSig or
XAdES conformance. They do not resolve inherited namespace handling (#41), UTF-8
handling (#49), or whitespace handling (#50). The bidirectional third-party CI
pipeline remains separate post-1.0 work (#40).

## Verify the committed fixtures

With `xmlsec1` installed, run from this directory:

```sh
for profile in c14n11 exclusive; do
  xmlsec1 --verify --pubkey-pem rsa-public.pem \
    --id-attr:Id SignedProperties "$profile.xml"
done
```

## Regenerate in a temporary directory

Run from this directory with OpenSSL and `xmlsec1` installed. A new key produces
different signature values; verify all outputs before deliberately replacing
the committed public key and two signed XML files together. Do not commit the
private key or pretty-print the signed XML.

```sh
fixture_tmp=$(mktemp -d)
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
  -out "$fixture_tmp/test-only-key.pem"
openssl pkey -in "$fixture_tmp/test-only-key.pem" -pubout \
  -out "$fixture_tmp/rsa-public.pem"
for profile in c14n11 exclusive; do
  xmlsec1 --sign --privkey-pem "$fixture_tmp/test-only-key.pem" \
    --id-attr:Id SignedProperties --output "$fixture_tmp/$profile.xml" \
    "$profile-template.xml"
  xmlsec1 --verify --pubkey-pem "$fixture_tmp/rsa-public.pem" \
    --id-attr:Id SignedProperties "$fixture_tmp/$profile.xml"
done
```
