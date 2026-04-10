-module(signerl_signature).
-include("signerl_dsig.hrl").

-export([build_signature_element/4]).

-spec build_signature_element(Message, Hash, Key, CertDer) ->
    {ok, signerl_xml:simplified_xml()} | {error, unsupported_hash | unsupported_key}
when
    Message :: signerl_xml:simplified_xml(),
    Hash :: atom(),
    Key :: public_key:private_key(),
    CertDer :: binary() | undefined.
build_signature_element(Message, sha256, Key, CertDer) ->
    case signerl_dsig_utils:signature_method_uri_for_key(Key) of
        {ok, SignatureMethodUri} ->
            build_signature_element_with_method_uri(
                Message, sha256, Key, SignatureMethodUri, CertDer
            );
        error ->
            {error, unsupported_key}
    end;
build_signature_element(_Message, _Hash, _Key, _CertDer) ->
    {error, unsupported_hash}.

build_signature_element_with_method_uri(Message, Hash, Key, SignatureMethodUri, CertDer) ->
    {ok, SignatureElementWithoutValue, SignedInfo} =
        construct_signature_without_value(
            Message, Hash, ?DSIG_DIGEST_SHA256_URI, SignatureMethodUri, CertDer
        ),
    SignedInfoBytes = signerl_c14n:canonicalize(SignedInfo),
    SignatureBytes = public_key:sign(SignedInfoBytes, Hash, Key),
    SignatureValue = base64:encode(SignatureBytes),
    SignatureElement =
        add_signature_value(SignatureElementWithoutValue, binary_to_list(SignatureValue)),
    {ok, SignatureElement}.

construct_signature_without_value(Message, Hash, DigestMethodUri, SignatureMethodUri, CertDer) ->
    SigningTime = signerl_utils:current_utc_timestamp(),
    SignedProperties = signed_properties(SigningTime),
    SignedInfo = signed_info(Message, SignedProperties, Hash, DigestMethodUri, SignatureMethodUri),
    KeyInfoElement = key_info(CertDer),
    SignatureElement =
        {'ds:Signature', [{'xmlns:ds', ?DSIG_NAMESPACE_URI}, {'Id', ?SIGNATURE_ID}],
            [SignedInfo] ++ KeyInfoElement ++ [signature_object(SignedProperties)]},
    {ok, SignatureElement, SignedInfo}.

key_info(undefined) ->
    [];
key_info(CertDer) when is_binary(CertDer) ->
    CertB64 = binary_to_list(base64:encode(CertDer)),
    [{'ds:KeyInfo', [], [{'ds:X509Data', [], [{'ds:X509Certificate', [], [CertB64]}]}]}].

signed_info(Message, SignedProperties, Hash, DigestMethodUri, SignatureMethodUri) ->
    MessageDigest = signerl_dsig_utils:digest_base64(Hash, signerl_c14n:canonicalize(Message)),
    SignedPropertiesDigest =
        signerl_dsig_utils:digest_base64(Hash, signerl_c14n:canonicalize(SignedProperties)),
    DigestMethodElement = {'ds:DigestMethod', [{'Algorithm', DigestMethodUri}], []},
    MessageDigestElement = {'ds:DigestValue', [], [binary_to_list(MessageDigest)]},
    SignedPropertiesDigestElement =
        {'ds:DigestValue', [], [binary_to_list(SignedPropertiesDigest)]},
    {'ds:SignedInfo', [], [
        {'ds:CanonicalizationMethod', [{'Algorithm', ?DSIG_C14N11_ALGO_URI}], []},
        {'ds:SignatureMethod', [{'Algorithm', SignatureMethodUri}], []},
        reference(
            [{'URI', ""}],
            [
                {'ds:Transforms', [], [
                    {'ds:Transform', [{'Algorithm', ?DSIG_ENVELOPED_SIGNATURE_TRANSFORM_URI}], []}
                ]},
                DigestMethodElement,
                MessageDigestElement
            ]
        ),
        reference(
            [
                {'URI', "#" ++ ?SIGNED_PROPERTIES_ID},
                {'Type', ?XADES_SIGNED_PROPERTIES_TYPE_URI}
            ],
            [DigestMethodElement, SignedPropertiesDigestElement]
        )
    ]}.

reference(Attrs, Content) ->
    {'ds:Reference', Attrs, Content}.

add_signature_value({'ds:Signature', Attrs, Content}, SignatureValue) ->
    [SignedInfo | Rest] = Content,
    {'ds:Signature', Attrs, [
        SignedInfo,
        {'ds:SignatureValue', [], [SignatureValue]}
        | Rest
    ]}.

signature_object(SignedProperties) ->
    {'ds:Object', [], [
        {'xades:QualifyingProperties',
            [
                {'xmlns:xades', ?XADES_NAMESPACE_URI},
                {'Target', "#" ++ ?SIGNATURE_ID}
            ],
            [SignedProperties]}
    ]}.

signed_properties(SigningTime) ->
    {'xades:SignedProperties', [{'Id', ?SIGNED_PROPERTIES_ID}], [
        {'xades:SignedSignatureProperties', [], [
            {'xades:SigningTime', [], [binary_to_list(SigningTime)]}
        ]}
    ]}.
