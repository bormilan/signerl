-module(signerl_signature).
-include("signerl_dsig.hrl").

-export([build_signature_element/4, build_signature_element/5]).

-spec build_signature_element(Message, HashAlgorithm, Key, CertDer) ->
    {ok, xmlan:simplified_xml()} | {error, atom()}
when
    Message :: xmlan:simplified_xml(),
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
    {ok, xmlan:simplified_xml()}
    | {error, atom()}
when
    Message :: xmlan:simplified_xml(),
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
    {SignatureId, PropertiesId} = signing_ids(Message),
    {ok, SignatureElementWithoutValue, SignedInfo} =
        construct_signature_without_value(
            Message,
            HashAlgorithm,
            ?DSIG_DIGEST_SHA256_URI,
            SignatureMethodUri,
            CertDer,
            SigningTime,
            {SignatureId, PropertiesId}
        ),
    SignedInfoBytes = xmlan_c14n:canonicalize(SignedInfo),
    SignatureBytes = public_key:sign(SignedInfoBytes, HashAlgorithm, Key),
    ok = validate_certificate_key(
        CertDer,
        SignatureMethodUri,
        SignedInfoBytes,
        HashAlgorithm,
        SignatureBytes
    ),
    SignatureValue = base64:encode(SignatureBytes),
    SignatureElement =
        add_signature_value(SignatureElementWithoutValue, binary_to_list(SignatureValue)),
    {ok, SignatureElement}.

validate_certificate_key(undefined, _Method, _Bytes, _Hash, _Signature) ->
    ok;
validate_certificate_key(CertDer, Method, Bytes, Hash, Signature) ->
    Certificate = signerl_cert:certificate_info(CertDer),
    case signerl_cert:verify_signature(Certificate, Method, Bytes, Hash, Signature) of
        true -> ok;
        false -> error(certificate_key_mismatch)
    end.

signing_ids(Message) ->
    case signerl_dsig_utils:signature_inventory(Message) of
        {0, Ids} ->
            case lists:all(fun(Count) -> Count =:= 1 end, maps:values(Ids)) of
                true ->
                    {
                        available_id(?SIGNATURE_ID, Ids, 0),
                        available_id(?SIGNED_PROPERTIES_ID, Ids, 0)
                    };
                false ->
                    error(invalid_signature_structure)
            end;
        _ ->
            error(already_signed)
    end.

available_id(Base, Ids, Number) ->
    Candidate =
        case Number of
            0 -> Base;
            _ -> Base ++ "-" ++ integer_to_list(Number)
        end,
    case maps:is_key(Candidate, Ids) of
        true -> available_id(Base, Ids, Number + 1);
        false -> Candidate
    end.

construct_signature_without_value(
    {_, MessageAttrs, _} = Message,
    HashAlgorithm,
    DigestMethodUri,
    SignatureMethodUri,
    CertDer,
    SigningTime,
    {SignatureId, PropertiesId}
) ->
    SignedProperties = signed_properties(
        SigningTime,
        HashAlgorithm,
        DigestMethodUri,
        CertDer,
        PropertiesId
    ),
    SignatureAttrs = [{<<"xmlns:ds">>, ?DSIG_NAMESPACE_URI}, {<<"Id">>, SignatureId}],
    SignatureNs = xmlan:namespace_context(
        SignatureAttrs, xmlan:namespace_context(MessageAttrs, #{})
    ),
    PropertiesNs = xmlan:namespace_context(
        [{<<"xmlns:xades">>, ?XADES_NAMESPACE_URI}], SignatureNs
    ),
    SignedInfo = signed_info(
        Message,
        xmlan:with_namespace_context(SignedProperties, PropertiesNs),
        HashAlgorithm,
        DigestMethodUri,
        SignatureMethodUri,
        PropertiesId
    ),
    KeyInfoElement = key_info(CertDer),
    SignatureElement =
        {<<"ds:Signature">>, SignatureAttrs,
            [SignedInfo] ++ KeyInfoElement ++ [signature_object(SignedProperties, SignatureId)]},
    % Sign the subtree in its actual document context; serialize the original tree.
    {ok, SignatureElement, xmlan:with_namespace_context(SignedInfo, SignatureNs)}.

key_info(undefined) ->
    [];
key_info(CertDer) when is_binary(CertDer) ->
    CertB64 = binary_to_list(base64:encode(CertDer)),
    [
        {<<"ds:KeyInfo">>, [], [
            {<<"ds:X509Data">>, [], [{<<"ds:X509Certificate">>, [], [CertB64]}]}
        ]}
    ].

signed_info(
    Message, SignedProperties, HashAlgorithm, DigestMethodUri, SignatureMethodUri, PropertiesId
) ->
    MessageDigest = signerl_dsig_utils:digest_base64(
        HashAlgorithm, xmlan_c14n:canonicalize(Message)
    ),
    SignedPropertiesDigest =
        signerl_dsig_utils:digest_base64(
            HashAlgorithm, xmlan_c14n:canonicalize(SignedProperties)
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
                transforms([?DSIG_ENVELOPED_SIGNATURE_TRANSFORM_URI, ?DSIG_C14N11_ALGO_URI]),
                DigestMethodElement,
                MessageDigestElement
            ]
        ),
        reference(
            [
                {<<"URI">>, "#" ++ PropertiesId},
                {<<"Type">>, ?XADES_SIGNED_PROPERTIES_TYPE_URI}
            ],
            [
                transforms([?DSIG_C14N11_ALGO_URI]),
                DigestMethodElement,
                SignedPropertiesDigestElement
            ]
        )
    ]}.

transforms(Algorithms) ->
    {<<"ds:Transforms">>, [], [
        {<<"ds:Transform">>, [{<<"Algorithm">>, Algorithm}], []}
     || Algorithm <- Algorithms
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

signature_object(SignedProperties, SignatureId) ->
    {<<"ds:Object">>, [], [
        {<<"xades:QualifyingProperties">>,
            [
                {<<"xmlns:xades">>, ?XADES_NAMESPACE_URI},
                {<<"Target">>, "#" ++ SignatureId}
            ],
            [SignedProperties]}
    ]}.

signed_properties(SigningTime, HashAlgorithm, DigestMethodUri, CertDer, PropertiesId) ->
    SigningTimeElement = {<<"xades:SigningTime">>, [], [binary_to_list(SigningTime)]},
    CertElements = signing_certificate_v2_elements(HashAlgorithm, DigestMethodUri, CertDer),
    {<<"xades:SignedProperties">>, [{<<"Id">>, PropertiesId}], [
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
