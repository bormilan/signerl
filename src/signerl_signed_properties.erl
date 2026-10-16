-module(signerl_signed_properties).
-feature(maybe_expr, enable).
-include("signerl_dsig.hrl").

-export([extract/1]).

-spec extract(SignatureElement) -> Result when
    SignatureElement :: xmlan:simplified_xml(),
    Result :: {ok, map()} | {error, term()}.
extract(SignatureElement) ->
    maybe
        {ok, SigPropsElement} ?=
            signerl_xades_xml:find_signed_signature_properties(SignatureElement),
        {?XADES_NAME(<<"SignedSignatureProperties">>), _, SigProps} =
            xmlan:expanded_names(SigPropsElement),
        {ok, Validated} ?= validate_signed_signature_properties(SigProps, #{}),
        DataObjProps = signerl_xades_xml:find_signed_data_object_properties(SignatureElement),
        {ok, WithDataObj} ?= validate_signed_data_object_properties(DataObjProps, Validated),
        {ok, WithDataObj}
    end.

validate_signed_signature_properties([], SignedProperties) ->
    case maps:is_key(signing_time, SignedProperties) of
        true -> {ok, SignedProperties};
        false -> {error, missing_signing_time}
    end;
validate_signed_signature_properties([Property | Rest], SignedProperties) ->
    case validate_signed_signature_property(Property, SignedProperties) of
        {ok, UpdatedProperties} ->
            validate_signed_signature_properties(Rest, UpdatedProperties);
        {error, _} = Err ->
            Err
    end.

validate_signed_signature_property(
    {?XADES_NAME(<<"SigningTime">>), _, _} = SigningTimeElement, SignedProperties
) ->
    case validate_signing_time(SigningTimeElement) of
        {ok, SigningTime} ->
            put_unique_property(signing_time, SigningTime, SignedProperties);
        {error, _} = Err ->
            Err
    end;
validate_signed_signature_property({?XADES_NAME(<<"SigningCertificate">>), _, _}, Properties) ->
    put_unique_property(signing_certificate, present, Properties);
validate_signed_signature_property(
    {?XADES_NAME(<<"SigningCertificateV2">>), _, Content}, SignedProperties
) ->
    case validate_signing_certificate_v2(Content) of
        {ok, CertInfo} ->
            put_unique_property(signing_certificate_v2, CertInfo, SignedProperties);
        {error, _} = Err ->
            Err
    end;
validate_signed_signature_property(
    {?XADES_NAME(<<"SignaturePolicyIdentifier">>), _, Content}, SignedProperties
) ->
    case validate_signature_policy_identifier(Content) of
        {ok, Policy} ->
            put_unique_property(signature_policy_identifier, Policy, SignedProperties);
        {error, _} = Err ->
            Err
    end;
validate_signed_signature_property(
    {?XADES_NAME(<<"SignatureProductionPlace">>), _, Content}, SignedProperties
) ->
    Place = validate_signature_production_place(Content),
    put_unique_property(signature_production_place, Place, SignedProperties);
validate_signed_signature_property({?XADES_NAME(<<"SignerRole">>), _, Content}, SignedProperties) ->
    case validate_signer_role(Content) of
        {ok, Role} ->
            put_unique_property(signer_role, Role, SignedProperties);
        {error, _} = Err ->
            Err
    end;
validate_signed_signature_property({_Tag, _Attrs, _Content}, SignedProperties) ->
    {ok, SignedProperties};
validate_signed_signature_property(_Other, SignedProperties) ->
    {ok, SignedProperties}.

put_unique_property(Key, Value, Properties) ->
    case maps:is_key(Key, Properties) of
        true ->
            {error, duplicate_property};
        false ->
            {ok, maps:put(Key, Value, Properties)}
    end.

%%--- SignedDataObjectProperties pipeline ---

validate_signed_data_object_properties({error, _}, Acc) ->
    {ok, Acc};
validate_signed_data_object_properties({ok, Element}, Acc) ->
    {?XADES_NAME(<<"SignedDataObjectProperties">>), _, Content} =
        xmlan:expanded_names(Element),
    validate_data_object_elements(Content, Acc).

validate_data_object_elements([], Acc) ->
    {ok, Acc};
validate_data_object_elements([Element | Rest], Acc) ->
    case validate_data_object_element(Element, Acc) of
        {ok, Updated} -> validate_data_object_elements(Rest, Updated);
        {error, _} = Err -> Err
    end.

validate_data_object_element({?XADES_NAME(<<"DataObjectFormat">>), Attrs, Content}, Acc) ->
    case validate_data_object_format(Attrs, Content) of
        {ok, Format} ->
            Existing = maps:get(data_object_formats, Acc, []),
            {ok, Acc#{data_object_formats => Existing ++ [Format]}};
        {error, _} = Err ->
            Err
    end;
validate_data_object_element({?XADES_NAME(<<"CommitmentTypeIndication">>), _, Content}, Acc) ->
    case validate_commitment_type_indication(Content) of
        {ok, Commitment} ->
            Existing = maps:get(commitment_type_indications, Acc, []),
            {ok, Acc#{commitment_type_indications => Existing ++ [Commitment]}};
        {error, _} = Err ->
            Err
    end;
validate_data_object_element({_Tag, _Attrs, _Content}, Acc) ->
    {ok, Acc};
validate_data_object_element(_Other, Acc) ->
    {ok, Acc}.

%%--- SigningTime ---

validate_signing_time({?XADES_NAME(<<"SigningTime">>), _, [SigningTime]}) when
    is_binary(SigningTime)
->
    decode_signing_time_binary(SigningTime);
validate_signing_time({?XADES_NAME(<<"SigningTime">>), _, [SigningTime]}) when
    is_list(SigningTime)
->
    case signerl_utils:is_byte_list(SigningTime) of
        true ->
            decode_signing_time_binary(list_to_binary(SigningTime));
        false ->
            {error, invalid_signing_time}
    end;
validate_signing_time({?XADES_NAME(<<"SigningTime">>), _, [_SigningTime]}) ->
    {error, invalid_signing_time};
validate_signing_time({?XADES_NAME(<<"SigningTime">>), _, _}) ->
    {error, invalid_signing_time}.

decode_signing_time_binary(SigningTime) when is_binary(SigningTime) ->
    case signerl_utils:valid_utc_timestamp(SigningTime) of
        true -> {ok, SigningTime};
        false -> {error, invalid_signing_time}
    end.

%%--- SigningCertificateV2 ---

validate_signing_certificate_v2([{?XADES_NAME(<<"Cert">>), _, CertContent}]) ->
    validate_cert_element(CertContent);
validate_signing_certificate_v2(_) ->
    {error, invalid_signing_certificate_v2}.

validate_cert_element(Content) ->
    maybe
        {ok, CertDigest} ?= extract_cert_digest(Content),
        IssuerSerial = extract_issuer_serial_v2(Content),
        {ok, maps:merge(CertDigest, IssuerSerial)}
    end.

extract_cert_digest(Content) ->
    case lists:keyfind(?XADES_NAME(<<"CertDigest">>), 1, Content) of
        {?XADES_NAME(<<"CertDigest">>), _, DigestContent} ->
            validate_cert_digest(DigestContent);
        false ->
            {error, invalid_signing_certificate_v2}
    end.

validate_cert_digest(DigestContent) ->
    case extract_digest(DigestContent) of
        {ok, _} = Ok -> Ok;
        error -> {error, invalid_signing_certificate_v2}
    end.

extract_issuer_serial_v2(Content) ->
    case lists:keyfind(?XADES_NAME(<<"IssuerSerialV2">>), 1, Content) of
        {?XADES_NAME(<<"IssuerSerialV2">>), _, [IssuerSerialText]} ->
            case decode_base64_text(IssuerSerialText) of
                {ok, IssuerSerialDer} -> #{issuer_serial_v2 => IssuerSerialDer};
                {error, _} -> #{}
            end;
        _ ->
            #{}
    end.

%%--- SignaturePolicyIdentifier ---

validate_signature_policy_identifier(Content) ->
    case lists:keyfind(?XADES_NAME(<<"SignaturePolicyImplied">>), 1, Content) of
        {?XADES_NAME(<<"SignaturePolicyImplied">>), _, _} ->
            {ok, #{type => implied}};
        false ->
            validate_explicit_policy(Content)
    end.

validate_explicit_policy(Content) ->
    case lists:keyfind(?XADES_NAME(<<"SignaturePolicyId">>), 1, Content) of
        {?XADES_NAME(<<"SignaturePolicyId">>), _, PolicyContent} ->
            parse_signature_policy_id(PolicyContent);
        false ->
            {error, invalid_signature_policy_identifier}
    end.

parse_signature_policy_id(PolicyContent) ->
    maybe
        {ok, Identifier, IdExtra} ?= extract_policy_identifier(PolicyContent),
        {ok, PolicyHash} ?= extract_policy_hash(PolicyContent),
        Description = extract_optional_text(?XADES_NAME(<<"Description">>), IdExtra),
        {ok,
            maps:merge(
                #{type => explicit, identifier => Identifier},
                maps:merge(PolicyHash, Description)
            )}
    end.

extract_policy_identifier(PolicyContent) ->
    case lists:keyfind(?XADES_NAME(<<"SigPolicyId">>), 1, PolicyContent) of
        {?XADES_NAME(<<"SigPolicyId">>), _, IdContent} ->
            case lists:keyfind(?XADES_NAME(<<"Identifier">>), 1, IdContent) of
                {?XADES_NAME(<<"Identifier">>), _, [IdentifierText]} ->
                    case extract_text_value(IdentifierText) of
                        {ok, Id} -> {ok, Id, IdContent};
                        {error, _} -> {error, invalid_signature_policy_identifier}
                    end;
                _ ->
                    {error, invalid_signature_policy_identifier}
            end;
        false ->
            {error, invalid_signature_policy_identifier}
    end.

extract_policy_hash(PolicyContent) ->
    case lists:keyfind(?XADES_NAME(<<"SigPolicyHash">>), 1, PolicyContent) of
        {?XADES_NAME(<<"SigPolicyHash">>), _, HashContent} ->
            validate_policy_hash(HashContent);
        false ->
            {error, invalid_signature_policy_identifier}
    end.

validate_policy_hash(HashContent) ->
    case extract_digest(HashContent) of
        {ok, _} = Ok -> Ok;
        error -> {error, invalid_signature_policy_identifier}
    end.

%%--- SignatureProductionPlace ---

validate_signature_production_place(Content) ->
    lists:foldl(fun extract_place_field/2, #{}, Content).

extract_place_field({?XADES_NAME(<<"City">>), _, [Text]}, Acc) ->
    put_text_field(city, Text, Acc);
extract_place_field({?XADES_NAME(<<"StateOrProvince">>), _, [Text]}, Acc) ->
    put_text_field(state_or_province, Text, Acc);
extract_place_field({?XADES_NAME(<<"PostalCode">>), _, [Text]}, Acc) ->
    put_text_field(postal_code, Text, Acc);
extract_place_field({?XADES_NAME(<<"CountryName">>), _, [Text]}, Acc) ->
    put_text_field(country_name, Text, Acc);
extract_place_field(_, Acc) ->
    Acc.

put_text_field(Key, Text, Acc) when is_binary(Text) ->
    Acc#{Key => Text};
put_text_field(Key, Text, Acc) when is_list(Text) ->
    case signerl_utils:is_byte_list(Text) of
        true -> Acc#{Key => list_to_binary(Text)};
        false -> Acc
    end;
put_text_field(_Key, _Text, Acc) ->
    Acc.

%%--- SignerRole ---

validate_signer_role(Content) ->
    ClaimedRoles = extract_roles(
        ?XADES_NAME(<<"ClaimedRoles">>), ?XADES_NAME(<<"ClaimedRole">>), Content
    ),
    CertifiedRoles = extract_roles(
        ?XADES_NAME(<<"CertifiedRoles">>), ?XADES_NAME(<<"CertifiedRole">>), Content
    ),
    case {ClaimedRoles, CertifiedRoles} of
        {[], []} ->
            {error, invalid_signer_role};
        _ ->
            Role = build_role_map(ClaimedRoles, CertifiedRoles),
            {ok, Role}
    end.

extract_roles(ContainerTag, ItemTag, Content) ->
    case lists:keyfind(ContainerTag, 1, Content) of
        {ContainerTag, _, Items} ->
            extract_role_items(ItemTag, Items);
        false ->
            []
    end.

extract_role_items(_ItemTag, []) ->
    [];
extract_role_items(ItemTag, [{ItemTag, _, [Text]} | Rest]) ->
    case to_binary_text(Text) of
        {ok, Bin} -> [Bin | extract_role_items(ItemTag, Rest)];
        error -> extract_role_items(ItemTag, Rest)
    end;
extract_role_items(ItemTag, [_ | Rest]) ->
    extract_role_items(ItemTag, Rest).

build_role_map([], CertifiedRoles) ->
    #{certified_roles => CertifiedRoles};
build_role_map(ClaimedRoles, []) ->
    #{claimed_roles => ClaimedRoles};
build_role_map(ClaimedRoles, CertifiedRoles) ->
    #{claimed_roles => ClaimedRoles, certified_roles => CertifiedRoles}.

%%--- DataObjectFormat ---

validate_data_object_format(Attrs, Content) ->
    case xmlan:attr_value(<<"ObjectReference">>, Attrs) of
        {ok, ObjectRef} ->
            Format = extract_data_format_fields(Content, #{object_reference => ObjectRef}),
            {ok, Format};
        {error, _} ->
            {error, invalid_data_object_format}
    end.

extract_data_format_fields([], Acc) ->
    Acc;
extract_data_format_fields([{?XADES_NAME(<<"MimeType">>), _, [Text]} | Rest], Acc) ->
    extract_data_format_fields(Rest, put_text_or_skip(mime_type, Text, Acc));
extract_data_format_fields([{?XADES_NAME(<<"Description">>), _, [Text]} | Rest], Acc) ->
    extract_data_format_fields(Rest, put_text_or_skip(description, Text, Acc));
extract_data_format_fields([{?XADES_NAME(<<"Encoding">>), _, [Text]} | Rest], Acc) ->
    extract_data_format_fields(Rest, put_text_or_skip(encoding, Text, Acc));
extract_data_format_fields([_ | Rest], Acc) ->
    extract_data_format_fields(Rest, Acc).

%%--- CommitmentTypeIndication ---

validate_commitment_type_indication(Content) ->
    case extract_commitment_type_id(Content) of
        {ok, Identifier} ->
            Scope = extract_commitment_scope(Content),
            {ok, maps:merge(#{identifier => Identifier}, Scope)};
        {error, _} = Err ->
            Err
    end.

extract_commitment_type_id(Content) ->
    case lists:keyfind(?XADES_NAME(<<"CommitmentTypeId">>), 1, Content) of
        {?XADES_NAME(<<"CommitmentTypeId">>), _, IdContent} ->
            case lists:keyfind(?XADES_NAME(<<"Identifier">>), 1, IdContent) of
                {?XADES_NAME(<<"Identifier">>), _, [IdentifierText]} ->
                    extract_text_value(IdentifierText);
                _ ->
                    {error, invalid_commitment_type_indication}
            end;
        false ->
            {error, invalid_commitment_type_indication}
    end.

extract_commitment_scope(Content) ->
    case lists:keyfind(?XADES_NAME(<<"AllSignedDataObjects">>), 1, Content) of
        {?XADES_NAME(<<"AllSignedDataObjects">>), _, _} ->
            #{scope => all};
        false ->
            extract_object_references(Content)
    end.

extract_object_references(Content) ->
    Refs = [Text || {?XADES_NAME(<<"ObjectReference">>), _, [Text]} <- Content],
    case Refs of
        [] -> #{};
        _ -> #{scope => {references, Refs}}
    end.

%%--- Shared helpers ---

extract_digest(DigestContent) ->
    maybe
        {ok, {?DSIG_NAME(<<"DigestMethod">>), DigestMethodAttrs, _}} ?=
            find_element(?DSIG_NAME(<<"DigestMethod">>), DigestContent),
        {ok, DigestMethodUri} ?= xmlan:attr_value(<<"Algorithm">>, DigestMethodAttrs),
        {ok, {?DSIG_NAME(<<"DigestValue">>), _, [DigestValueText]}} ?=
            find_element(?DSIG_NAME(<<"DigestValue">>), DigestContent),
        {ok, DigestValue} ?= decode_base64_text(DigestValueText),
        {ok, #{digest_method => DigestMethodUri, digest_value => DigestValue}}
    else
        _ -> error
    end.

find_element(Tag, Content) ->
    case lists:keyfind(Tag, 1, Content) of
        false -> {error, not_found};
        Element -> {ok, Element}
    end.

extract_text_value(Text) when is_binary(Text) ->
    {ok, Text};
extract_text_value(Text) when is_list(Text) ->
    case signerl_utils:is_byte_list(Text) of
        true -> {ok, list_to_binary(Text)};
        false -> {error, invalid_text}
    end;
extract_text_value(_) ->
    {error, invalid_text}.

extract_optional_text(Tag, Content) ->
    case lists:keyfind(Tag, 1, Content) of
        {Tag, _, [Text]} ->
            case to_binary_text(Text) of
                {ok, Bin} -> #{description => Bin};
                error -> #{}
            end;
        _ ->
            #{}
    end.

to_binary_text(Text) when is_binary(Text) ->
    {ok, Text};
to_binary_text(Text) when is_list(Text) ->
    case signerl_utils:is_byte_list(Text) of
        true -> {ok, list_to_binary(Text)};
        false -> error
    end;
to_binary_text(_) ->
    error.

put_text_or_skip(Key, Text, Acc) ->
    case to_binary_text(Text) of
        {ok, Bin} -> Acc#{Key => Bin};
        error -> Acc
    end.

decode_base64_text(Text) when is_binary(Text) ->
    decode_base64_value(Text);
decode_base64_text(Text) when is_list(Text) ->
    case signerl_utils:is_byte_list(Text) of
        true -> decode_base64_value(list_to_binary(Text));
        false -> {error, invalid_base64}
    end;
decode_base64_text(_) ->
    {error, invalid_base64}.

decode_base64_value(<<>>) ->
    {error, invalid_base64};
decode_base64_value(Value) ->
    try
        {ok, base64:decode(Value)}
    catch
        _:_ -> {error, invalid_base64}
    end.
