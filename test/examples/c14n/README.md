# Signature API inputs

`utf8.xml` and `preserved_content.xml` remain here because Signerl's actual
sign/verify/tamper tests consume them. They are unchanged from the XML foundation
baseline `5927e41bab8674b875c51df1a1ec956d42676992`.

All nine original generic canonicalization fixtures and both-mode xmllint tests
are owned by xmlan at pinned commit `1fe39f6d414217584f514e70e43b8e7b4171f1ef`.
The other seven pure fixtures moved there in #86 and are removed from this
checkout in #87. Independently signed protocol fixtures remain in
`../independent/`; frozen migration contracts remain in `../xmlan_migration/`.
