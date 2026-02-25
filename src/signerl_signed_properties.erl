-module(signerl_signed_properties).

-export([extract/1]).

-spec extract(SignatureElement) -> Result when
    SignatureElement :: {atom(), [{atom(), string() | number()}], [any()]},
    Result :: {ok, map()} | error.
extract({'ds:Signature', _, SignatureContent}) ->
    SignatureElement = {'ds:Signature', [], SignatureContent},
    decode_signed_properties(
        signerl_xml:find_path(
            [
                'ds:Object',
                'xades:QualifyingProperties',
                'xades:SignedProperties',
                'xades:SignedSignatureProperties'
            ],
            SignatureElement
        )
    ).

decode_signed_properties({ok, {'xades:SignedSignatureProperties', _, Properties}}) ->
    validate_signed_properties(Properties, #{});
decode_signed_properties(error) ->
    error.

validate_signed_properties([], SignedProperties) ->
    case maps:is_key(signing_time, SignedProperties) of
        true -> {ok, SignedProperties};
        false -> error
    end;
validate_signed_properties([Property | Rest], SignedProperties) ->
    case validate_signed_property(Property, SignedProperties) of
        {ok, UpdatedProperties} ->
            validate_signed_properties(Rest, UpdatedProperties);
        error ->
            error
    end.

validate_signed_property(PropertyElement, SignedProperties) ->
    validate_known_signed_property(PropertyElement, SignedProperties).

validate_known_signed_property(PropertyElement, SignedProperties) ->
    case PropertyElement of
        {'xades:SigningTime', _, _} = SigningTimeElement ->
            case validate_signing_time(SigningTimeElement) of
                {ok, SigningTime} ->
                    put_unique_property(signing_time, SigningTime, SignedProperties);
                error ->
                    error
            end;
        {'xades:SigningCertificate', _, _} = SigningCertificateElement ->
            _ = validate_signing_certificate(SigningCertificateElement),
            put_unique_property(signing_certificate, valid, SignedProperties);
        {'xades:SigningCertificateV2', _, _} = SigningCertificateV2Element ->
            _ = validate_signing_certificate_v2(SigningCertificateV2Element),
            put_unique_property(signing_certificate_v2, valid, SignedProperties);
        {'xades:SignaturePolicyIdentifier', _, _} = SignaturePolicyIdentifierElement ->
            _ = validate_signature_policy_identifier(SignaturePolicyIdentifierElement),
            put_unique_property(signature_policy_identifier, valid, SignedProperties);
        {'xades:SignatureProductionPlace', _, _} = SignatureProductionPlaceElement ->
            _ = validate_signature_production_place(SignatureProductionPlaceElement),
            put_unique_property(signature_production_place, valid, SignedProperties);
        {'xades:SignerRole', _, _} = SignerRoleElement ->
            _ = validate_signer_role(SignerRoleElement),
            put_unique_property(signer_role, valid, SignedProperties);
        {_Tag, _Attrs, _Content} ->
            {ok, SignedProperties};
        _Other ->
            {ok, SignedProperties}
    end.

put_unique_property(Key, Value, Properties) ->
    case maps:is_key(Key, Properties) of
        true ->
            error;
        false ->
            {ok, maps:put(Key, Value, Properties)}
    end.

validate_signing_time({'xades:SigningTime', _, [SigningTime]}) when is_binary(SigningTime) ->
    decode_signing_time_binary(SigningTime);
validate_signing_time({'xades:SigningTime', _, [SigningTime]}) when is_list(SigningTime) ->
    case signerl_utils:is_byte_list(SigningTime) of
        true ->
            decode_signing_time_binary(list_to_binary(SigningTime));
        false ->
            error
    end;
validate_signing_time({'xades:SigningTime', _, [_SigningTime]}) ->
    error;
validate_signing_time({'xades:SigningTime', _, _}) ->
    error.

validate_signing_certificate({'xades:SigningCertificate', _, _}) ->
    ok.

validate_signing_certificate_v2({'xades:SigningCertificateV2', _, _}) ->
    ok.

validate_signature_policy_identifier({'xades:SignaturePolicyIdentifier', _, _}) ->
    ok.

validate_signature_production_place({'xades:SignatureProductionPlace', _, _}) ->
    ok.

validate_signer_role({'xades:SignerRole', _, _}) ->
    ok.

decode_signing_time_binary(SigningTime) when is_binary(SigningTime) ->
    case signerl_utils:valid_utc_timestamp(SigningTime) of
        true -> {ok, SigningTime};
        false -> error
    end.
