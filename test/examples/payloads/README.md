# Signing payloads

`utf8.xml` and `preserved_content.xml` are inputs for Signerl's signing,
verification and tampering tests. They exercise Unicode payloads, significant
whitespace, mixed content and attribute values while checking that signatures
verify and detect changes to the signed content.

These files are inputs rather than expected parser or canonicalizer output.
