-module(signerl_signed_properties).

-export([extract/1]).

-spec extract(SignatureElement) -> Result when
    SignatureElement :: {atom(), [{atom(), string() | number()}], [any()]},
    Result :: {ok, map()} | {error, term()}.
extract(SignatureElement) ->
    case signerl_xades_xml:find_signed_signature_properties(SignatureElement) of
        {ok, {'xades:SignedSignatureProperties', _, Properties}} ->
            validate_signed_properties(Properties, #{});
        {error, _} = Err ->
            Err
    end.

validate_signed_properties([], SignedProperties) ->
    case maps:is_key(signing_time, SignedProperties) of
        true -> {ok, SignedProperties};
        false -> {error, missing_signing_time}
    end;
validate_signed_properties([Property | Rest], SignedProperties) ->
    case validate_signed_property(Property, SignedProperties) of
        {ok, UpdatedProperties} ->
            validate_signed_properties(Rest, UpdatedProperties);
        {error, _} = Err ->
            Err
    end.

validate_signed_property({'xades:SigningTime', _, _} = SigningTimeElement, SignedProperties) ->
    case validate_signing_time(SigningTimeElement) of
        {ok, SigningTime} ->
            put_unique_property(signing_time, SigningTime, SignedProperties);
        {error, _} = Err ->
            Err
    end;
validate_signed_property({'xades:SigningCertificate', _, _}, SignedProperties) ->
    %% TODO: validate certificate content (structural presence check only)
    put_unique_property(signing_certificate, present, SignedProperties);
validate_signed_property({'xades:SigningCertificateV2', _, _}, SignedProperties) ->
    %% TODO: validate certificate v2 content (structural presence check only)
    put_unique_property(signing_certificate_v2, present, SignedProperties);
validate_signed_property({'xades:SignaturePolicyIdentifier', _, _}, SignedProperties) ->
    %% TODO: validate policy identifier content (structural presence check only)
    put_unique_property(signature_policy_identifier, present, SignedProperties);
validate_signed_property({'xades:SignatureProductionPlace', _, _}, SignedProperties) ->
    %% TODO: validate production place content (structural presence check only)
    put_unique_property(signature_production_place, present, SignedProperties);
validate_signed_property({'xades:SignerRole', _, _}, SignedProperties) ->
    %% TODO: validate signer role content (structural presence check only)
    put_unique_property(signer_role, present, SignedProperties);
validate_signed_property({_Tag, _Attrs, _Content}, SignedProperties) ->
    {ok, SignedProperties};
validate_signed_property(_Other, SignedProperties) ->
    {ok, SignedProperties}.

put_unique_property(Key, Value, Properties) ->
    case maps:is_key(Key, Properties) of
        true ->
            {error, duplicate_property};
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
            {error, invalid_signing_time}
    end;
validate_signing_time({'xades:SigningTime', _, [_SigningTime]}) ->
    {error, invalid_signing_time};
validate_signing_time({'xades:SigningTime', _, _}) ->
    {error, invalid_signing_time}.

decode_signing_time_binary(SigningTime) when is_binary(SigningTime) ->
    case signerl_utils:valid_utc_timestamp(SigningTime) of
        true -> {ok, SigningTime};
        false -> {error, invalid_signing_time}
    end.
