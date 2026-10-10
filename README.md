# SignErl

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

`sign/3` returns signed XML with:
- `<ds:SignedInfo>` (deterministic internal profile)
- `<ds:SignatureValue>` containing base64 signature bytes over `ds:SignedInfo`
- `<ds:Object>/<xades:QualifyingProperties>/<xades:SignedProperties Id="SignedProperties-1">`
- `<xades:QualifyingProperties Target="#Signature-1">`

`SigningTime` is currently strict UTC in `YYYY-MM-DDThh:mm:ssZ` format.

`verify/3` expects a signed XML message. It returns:
- `true` when signature verification succeeds
- `false` when signature bytes are present but do not match message/key
- `{error, invalid_signature}` when signature structure/properties are missing or malformed

`verify/3` validates `ds:Reference` digest values (document + signed properties) before verifying
`ds:SignatureValue`.

## XML encoding

XML input and output use **UTF-8**. Text and attributes may contain Unicode,
including Hungarian accents, non-Latin scripts, and supplementary characters.
Canonicalization always emits UTF-8 bytes for both C14N 1.1 and Exclusive C14N.
Internally, parsed text and attribute values are Unicode character lists;
binary text/attribute values supplied to the canonicalizer must contain UTF-8.

`sign/3` and `sign/4` require an XML declaration at the start of the input,
without a byte-order mark (BOM). Its encoding may be omitted or specify UTF-8
(case-insensitively). The accepted declaration is preserved in the signed output.
Other declared encodings, including Latin-1 and UTF-16/32, return
`{error, invalid_prolog}`. Invalid UTF-8 after a valid declaration returns
`{error, invalid_xml}`.

`verify/3` accepts UTF-8 with or without an XML declaration or UTF-8 BOM. It
returns `{error, invalid_xml}` for malformed UTF-8 or unsupported encoding
labels. Binary and file public API inputs follow the same encoding policy.
There is no automatic transcoding of other input encodings.

The lower-level XML exporters also emit UTF-8; `export/2` raises if supplied
an incompatible encoding declaration. `parse_file/1` raises for missing files
or invalid input, while `parse_binary/1` returns `{error, invalid_xml}`.

## XML content profile

File and binary inputs share the same parser. Element content retains whitespace,
including indentation, spaces between child elements, mixed content, and
`xml:space="preserve"` content. XML line-ending normalization still applies:
literal CR/CRLF becomes LF, including inside CDATA, while `&#xD;` retains CR.
CDATA delimiters are not retained; their characters are preserved as text.

The exporters escape attribute tab, LF, and CR as `&#x9;`, `&#xA;`, and `&#xD;`,
and text CR as `&#xD;`. Reparsing signed output therefore preserves the character
values used for its digests. Changing signed whitespace can invalidate a signature.

Processing instructions are unsupported and return `{error, invalid_xml}` from
signing, verification, and `parse_binary/1`, whether before, inside, or after the
root. XML declarations follow the encoding rules above. Comments are omitted
under the existing canonicalization profile without comments.

Each input must contain exactly one document element. Signing, verification,
and `parse_binary/1` return `{error, invalid_xml}` for a second root, trailing
text, or malformed trailing markup. Legal XML whitespace (space, tab, CR, LF)
and well-formed comments after the root are accepted and omitted from the
parsed tree and signed output. Appending them to a valid signed document does
not change its verification result; appending invalid content rejects the input.
Binary and file inputs follow the same full-document policy.

Namespace/profile work remains tracked in #41.

## XML entity safety

DTDs and custom entities are unsupported. Otherwise supported inputs containing
a `DOCTYPE`, including an empty one, return `{error, invalid_xml}` from `sign/3`, `sign/4`, `verify/3`, and
`parse_binary/1`. The lower-level `parse_file/1` raises for invalid XML as before.
Both binary and file inputs use this policy, with no option to enable DTDs.
DTD-derived default attributes and custom entity values are therefore unavailable.

The parser disables external entity resolution and entity declarations, rejects
undeclared references, and sets the custom entity recursion limit to zero. DTD
rejection happens before processing internal/external subsets, so the custom
entity expansion budget is **zero levels and zero replacement bytes**. This
blocks file/HTTP external entities and exponential or quadratic custom entity
expansion. It does not fetch external DTDs.

The five predefined XML entities (`amp`, `lt`, `gt`, `quot`, `apos`) and numeric
character references remain supported. DTD-looking text inside comments or
CDATA is ordinary content, not a declaration. The policy follows
[OWASP's DTD rejection guidance](https://cheatsheetseries.owasp.org/cheatsheets/XML_External_Entity_Prevention_Cheat_Sheet.html#general-guidance)
and uses [xmerl's SAX entity controls](https://www.erlang.org/doc/apps/xmerl/xmerl_sax_parser.html#options/0).

These controls bound custom entity expansion, not ordinary document size or
element depth. Callers still need request/file size and concurrency limits;
file APIs currently read the whole input before parsing. XML names are handled
without allocating atoms, as described below.

## XML name representation

The lower-level XML tree uses UTF-8 **binary names** for every element and
attribute, including namespace declarations. Parsed text and attribute values
remain Unicode character lists. For example:

```erlang
{ok, {<<"root">>, [{<<"id">>, "1"}], [{<<"child">>, [], ["text"]}]}} =
    signerl_xml:parse_binary(<<"<root id='1'><child>text</child></root>">>).
```

This replaces the former atom-name representation. Callers constructing or
pattern-matching XML tuples must use `<<"root">>` instead of `root`, and
`<<"ds:Signature">>` instead of `'ds:Signature'`. Lookup paths and attribute keys
also use binaries, for example `find_path([<<"ds:Object">>], Signature)` and
`attr_value(<<"Id">>, Attrs)`. Signature builders emit the same representation;
exporters and both canonicalizers consume it. The public `sign/3`, `sign/4`, and
`verify/3` arguments and return shapes are unchanged.

The SAX parser supplies character-list names, which SignErl converts directly
to UTF-8 binaries. It does not intern names, consult existing atoms, or use an
input-dependent atom vocabulary. Arbitrary names therefore cannot grow the VM's
permanent atom table, including when a document is rejected after its root.
Names keep their lexical prefixes; matching namespace URIs remains #41.

A bounded regression runs the production parse/export/canonicalize/sign/verify
path in a fresh VM on each supported OTP 26/27/28 CI runtime. After warm-up,
two batches of 25 fresh name sets must each add zero atoms, including after
garbage collection. The separate VM isolates the test measurement; production
parsing does not rely on process isolation or garbage collection to reclaim atoms.
The DTD/entity restrictions above remain in force, while ordinary document
size/depth and concurrency limits remain the caller's responsibility.

## Development toolchain

The primary development runtime is **Erlang/OTP 28.5.0.7** with
**rebar3 3.25.1**, pinned in [.tool-versions](.tool-versions). GitHub Actions
reads these pins. OTP 26 and 27 remain compatibility targets on Ubuntu and
Windows; their CI jobs track the latest available patch in each major release.

With [asdf](https://asdf-vm.com/), register any missing plugins once, then install
the repository's versions:

```bash
asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git
asdf plugin add rebar https://github.com/Stratus3D/asdf-rebar.git
asdf install
```

The Erlang plugin builds OTP from source; follow its
[platform prerequisites](https://github.com/asdf-vm/asdf-erlang#before-asdf-install).
Alternatively, install the pinned OTP and rebar3 releases directly. Native
testing also requires OpenSSL for certificates and `xmllint` for canonicalization
comparisons (`libxml2-utils` on Debian/Ubuntu). CI installs the Linux prerequisite.

[rebar3 3.25.1](https://github.com/erlang/rebar3/releases/tag/3.25.1) supports the
retained OTP 26–28 matrix and includes Windows fixes for OTP 28. The
[OTP 28.5.0.7 release notes](https://github.com/erlang/otp/releases/tag/OTP-28.5.0.7)
record the selected patch's fixes and compatibility notes.

Formatting is pinned to **erlfmt 1.8.0**; lint is pinned to
**rebar3_lint 5.0.4 / Elvis 5.0.4**. This release supports the
retained OTP 26 target; [6.0.0 requires OTP 27 or newer](https://github.com/project-fifo/rebar3_lint/blob/6.0.0/rebar.config).
Tool updates are deliberate: change the exact pins, review compatibility, and
pass the full supported CI matrix. See the
[tooling and cache instructions](test/TESTS.md#tooling-versions-and-clean-builds)
for cached plugin upgrades and isolated clean builds.

## Tests

Run tests with rebar3:

```bash
scripts/gen_certs.sh
rebar3 test
```

Run the complete quality gate before pushing:

```bash
rebar3 tall
```

`tall` runs the test alias (format checking, EUnit, Common Test, and a 100%
coverage check), lint, Xref, and Dialyzer. Formatting is checked once without
rewriting files; `flint` also checks formatting and lint without rewriting files.
Run it natively before pushing.
GitHub Actions runs the same gate on OTP 26/27/28 across Ubuntu and Windows;
all six jobs must pass on the latest PR commit before merging. CI runs for pull
requests and pushes to `dev` and `main`.
Generate the test certificates before the first run.
Each `rebar3 test` run resets collected coverage once, then combines fresh EUnit
and Common Test coverage for the 100% threshold. Focused runs of either framework
are useful during development but do not replace that combined gate. See the
[test responsibility map and focused commands](test/TESTS.md).

Apply formatting explicitly, then review the diff before rerunning the checks:

```bash
rebar3 fmt
```

For a formatting-only check that leaves source files unchanged:

```bash
rebar3 fmt --check
```

## Test Certificates

Generate test-only keys and certificates:

```bash
scripts/gen_certs.sh
```

Docs for the generated artifacts:
`test/certs/README.md`

## Contributing

Issues and PRs are welcome. Keep changes small and focused, with one PR per issue
targeting `dev`. Follow the validation-first workflow in [AGENTS.md](AGENTS.md):
investigate, add behavioral validation, implement, test, review and simplify,
then run all tests, coverage, lint, and Dialyzer. Push only after native
`rebar3 tall` passes, and merge only after all six GitHub Actions jobs pass
on the latest PR commit.
