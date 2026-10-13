-module(signerl_signature).
-include("signerl_dsig.hrl").

-export([build_signature_element/4, build_signature_element/5]).

-spec build_signature_element(Message, HashAlgorithm, Key, CertDer) ->
    {ok, signerl_xml:simplified_xml()} | {error, unsupported_hash | unsupported_key}
when
    Message :: signerl_xml:simplified_xml(),
    HashAlgorithm :: atom(),
    Key :: public_key:private_key(),
    CertDer :: binary() | undefined.
build_signature_element(Message, HashAlgorithm, Key, CertDer) ->
    build_signature_element(
        Message,
        HashAlgorithm,
        Key,
        CertDer,
        signerl_utils:current_utc_timestamp()
    ).

-spec build_signature_element(Message, HashAlgorithm, Key, CertDer, SigningTime) ->
    {ok, signerl_xml:simplified_xml()}
    | {error, unsupported_hash | unsupported_key | invalid_signing_time}
when
    Message :: signerl_xml:simplified_xml(),
    HashAlgorithm :: atom(),
    Key :: public_key:private_key(),
    CertDer :: binary() | undefined,
    SigningTime :: binary().
build_signature_element(Message, sha256, Key, CertDer, SigningTime) ->
    case
        {
            signerl_utils:valid_utc_timestamp(SigningTime),
            signerl_dsig_utils:signature_method_uri_for_key(Key)
        }
    of
        {false, _} ->
            {error, invalid_signing_time};
        {true, {ok, SignatureMethodUri}} ->
            build_signature_element_with_method_uri(
                Message, sha256, Key, SignatureMethodUri, CertDer, SigningTime
            );
        {true, error} ->
            {error, unsupported_key}
    end;
build_signature_element(_Message, _Hash, _Key, _CertDer, _SigningTime) ->
    {error, unsupported_hash}.

build_signature_element_with_method_uri(
    Message, HashAlgorithm, Key, SignatureMethodUri, CertDer, SigningTime
) ->
    {ok, SignatureElementWithoutValue, SignedInfo} =
        construct_signature_without_value(
            Message,
            HashAlgorithm,
            ?DSIG_DIGEST_SHA256_URI,
            SignatureMethodUri,
            CertDer,
            SigningTime
        ),
    SignedInfoBytes = signerl_c14n:canonicalize(SignedInfo),
    SignatureBytes = public_key:sign(SignedInfoBytes, HashAlgorithm, Key),
    SignatureValue = base64:encode(SignatureBytes),
    SignatureElement =
        add_signature_value(SignatureElementWithoutValue, binary_to_list(SignatureValue)),
    {ok, SignatureElement}.

construct_signature_without_value(
    {_, MessageAttrs, _} = Message,
    HashAlgorithm,
    DigestMethodUri,
    SignatureMethodUri,
    CertDer,
    SigningTime
) ->
    SignedProperties = signed_properties(SigningTime, HashAlgorithm, DigestMethodUri, CertDer),
    SignatureAttrs = [{<<"xmlns:ds">>, ?DSIG_NAMESPACE_URI}, {<<"Id">>, ?SIGNATURE_ID}],
    SignatureNs = signerl_xml:namespace_context(
        SignatureAttrs, signerl_xml:namespace_context(MessageAttrs, #{})
    ),
    PropertiesNs = signerl_xml:namespace_context(
        [{<<"xmlns:xades">>, ?XADES_NAMESPACE_URI}], SignatureNs
    ),
    SignedInfo = signed_info(
        Message,
        signerl_xml:with_namespace_context(SignedProperties, PropertiesNs),
        HashAlgorithm,
        DigestMethodUri,
        SignatureMethodUri
    ),
    KeyInfoElement = key_info(CertDer),
    SignatureElement =
        {<<"ds:Signature">>, SignatureAttrs,
            [SignedInfo] ++ KeyInfoElement ++ [signature_object(SignedProperties)]},
    % Sign the subtree in its actual document context; serialize the original tree.
    {ok, SignatureElement, signerl_xml:with_namespace_context(SignedInfo, SignatureNs)}.

key_info(undefined) ->
    [];
key_info(CertDer) when is_binary(CertDer) ->
    CertB64 = binary_to_list(base64:encode(CertDer)),
    [
        {<<"ds:KeyInfo">>, [], [
            {<<"ds:X509Data">>, [], [{<<"ds:X509Certificate">>, [], [CertB64]}]}
        ]}
    ].

signed_info(Message, SignedProperties, HashAlgorithm, DigestMethodUri, SignatureMethodUri) ->
    MessageDigest = signerl_dsig_utils:digest_base64(
        HashAlgorithm, signerl_c14n:canonicalize(Message)
    ),
    SignedPropertiesDigest =
        signerl_dsig_utils:digest_base64(
            HashAlgorithm, signerl_c14n:canonicalize(SignedProperties)
        ),
    DigestMethodElement = digest_method_element(DigestMethodUri),
    MessageDigestElement = {<<"ds:DigestValue">>, [], [binary_to_list(MessageDigest)]},
    SignedPropertiesDigestElement =
        {<<"ds:DigestValue">>, [], [binary_to_list(SignedPropertiesDigest)]},
    {<<"ds:SignedInfo">>, [], [
        {<<"ds:CanonicalizationMethod">>, [{<<"Algorithm">>, ?DSIG_C14N11_ALGO_URI}], []},
        {<<"ds:SignatureMethod">>, [{<<"Algorithm">>, SignatureMethodUri}], []},
        reference(
            [{<<"URI">>, ""}],
            [
                {<<"ds:Transforms">>, [], [
                    {<<"ds:Transform">>,
                        [{<<"Algorithm">>, ?DSIG_ENVELOPED_SIGNATURE_TRANSFORM_URI}], []}
                ]},
                DigestMethodElement,
                MessageDigestElement
            ]
        ),
        reference(
            [
                {<<"URI">>, "#" ++ ?SIGNED_PROPERTIES_ID},
                {<<"Type">>, ?XADES_SIGNED_PROPERTIES_TYPE_URI}
            ],
            [DigestMethodElement, SignedPropertiesDigestElement]
        )
    ]}.

digest_method_element(DigestMethodUri) ->
    {<<"ds:DigestMethod">>, [{<<"Algorithm">>, DigestMethodUri}], []}.

reference(Attrs, Content) ->
    {<<"ds:Reference">>, Attrs, Content}.

add_signature_value({<<"ds:Signature">>, Attrs, Content}, SignatureValue) ->
    [SignedInfo | Rest] = Content,
    {<<"ds:Signature">>, Attrs, [
        SignedInfo,
        {<<"ds:SignatureValue">>, [], [SignatureValue]}
        | Rest
    ]}.

signature_object(SignedProperties) ->
    {<<"ds:Object">>, [], [
        {<<"xades:QualifyingProperties">>,
            [
                {<<"xmlns:xades">>, ?XADES_NAMESPACE_URI},
                {<<"Target">>, "#" ++ ?SIGNATURE_ID}
            ],
            [SignedProperties]}
    ]}.

signed_properties(SigningTime, HashAlgorithm, DigestMethodUri, CertDer) ->
    SigningTimeElement = {<<"xades:SigningTime">>, [], [binary_to_list(SigningTime)]},
    CertElements = signing_certificate_v2_elements(HashAlgorithm, DigestMethodUri, CertDer),
    {<<"xades:SignedProperties">>, [{<<"Id">>, ?SIGNED_PROPERTIES_ID}], [
        {<<"xades:SignedSignatureProperties">>, [], [SigningTimeElement | CertElements]}
    ]}.

signing_certificate_v2_elements(_HashAlgorithm, _DigestMethodUri, undefined) ->
    [];
signing_certificate_v2_elements(HashAlgorithm, DigestMethodUri, CertDer) ->
    CertDigestB64 = signerl_cert:cert_digest_base64(HashAlgorithm, CertDer),
    IssuerSerialB64 = signerl_cert:issuer_serial_v2_base64(CertDer),
    [
        {<<"xades:SigningCertificateV2">>, [], [
            {<<"xades:Cert">>, [], [
                {<<"xades:CertDigest">>, [], [
                    digest_method_element(DigestMethodUri),
                    {<<"ds:DigestValue">>, [], [binary_to_list(CertDigestB64)]}
                ]},
                {<<"xades:IssuerSerialV2">>, [], [binary_to_list(IssuerSerialB64)]}
            ]}
        ]}
    ].
