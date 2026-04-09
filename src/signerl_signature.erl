-module(signerl_signature).
-include("signerl_dsig.hrl").

-export([build_signature_element/3]).

-spec build_signature_element(Message, Hash, Key) ->
    {ok, {atom(), [{atom(), string() | number()}], [any()]}} | {error, invalid_signature}
when
    Message :: {atom(), [{atom(), string() | number()}], [any()]},
    Hash :: atom(),
    Key :: term().
build_signature_element(Message, sha256, Key) ->
    case signerl_dsig_utils:signature_method_uri_for_key(Key) of
        {ok, SignatureMethodUri} ->
            build_signature_element_with_method_uri(Message, sha256, Key, SignatureMethodUri);
        error ->
            {error, invalid_signature}
    end;
build_signature_element(_Message, _Hash, _Key) ->
    {error, invalid_signature}.

build_signature_element_with_method_uri(Message, Hash, Key, SignatureMethodUri) ->
    {ok, SignatureElementWithoutValue, SignedInfo} =
        construct_signature_without_value(
            Message, Hash, ?DSIG_DIGEST_SHA256_URI, SignatureMethodUri
        ),
    SignedInfoBytes = signerl_c14n:canonicalize(SignedInfo),
    SignatureBytes = public_key:sign(SignedInfoBytes, Hash, Key),
    SignatureValue = base64:encode(SignatureBytes),
    SignatureElement =
        add_signature_value(SignatureElementWithoutValue, binary_to_list(SignatureValue)),
    {ok, SignatureElement}.

construct_signature_without_value(Message, Hash, DigestMethodUri, SignatureMethodUri) ->
    SigningTime = signerl_utils:current_utc_timestamp(),
    SignedProperties = signed_properties(SigningTime),
    SignedInfo = signed_info(Message, SignedProperties, Hash, DigestMethodUri, SignatureMethodUri),
    SignatureElement =
        {'ds:Signature',
            [
                {'xmlns:ds', ?DSIG_NAMESPACE_URI},
                {'Id', ?SIGNATURE_ID}
            ],
            [
                SignedInfo,
                signature_object(SignedProperties)
            ]},
    {ok, SignatureElement, SignedInfo}.

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
            [
                DigestMethodElement,
                SignedPropertiesDigestElement
            ]
        )
    ]}.

reference(Attrs, Content) ->
    {'ds:Reference', Attrs, Content}.

add_signature_value({'ds:Signature', Attrs, Content}, SignatureValue) ->
    {'ds:Signature', Attrs, [
        lists:nth(1, Content),
        {'ds:SignatureValue', [], [SignatureValue]},
        lists:nth(2, Content)
    ]}.

signature_object(SignedProperties) ->
    {'ds:Object', [], [
        {'xades:QualifyingProperties',
            [
                {'xmlns:xades', ?XADES_NAMESPACE_URI},
                {'Target', "#" ++ ?SIGNATURE_ID}
            ],
            [
                SignedProperties
            ]}
    ]}.

signed_properties(SigningTime) ->
    {'xades:SignedProperties', [{'Id', ?SIGNED_PROPERTIES_ID}], [
        {'xades:SignedSignatureProperties', [], [
            {'xades:SigningTime', [], [binary_to_list(SigningTime)]}
        ]}
    ]}.
