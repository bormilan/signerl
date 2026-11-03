-module(signerl_signed_properties).
-feature(maybe_expr, enable).
-include("signerl_dsig.hrl").

-export([extract/1]).

-spec extract(SignatureElement) -> Result when
    SignatureElement :: xmlan:simplified_xml(),
    Result :: {ok, map()} | {error, term()}.
extract(SignatureElement) ->
    maybe
        {ok, PropertiesElement} ?=
            signerl_xades_xml:find_signed_properties_element(SignatureElement),
        {_, _, PropertiesContent} = xmlan:expanded_names(PropertiesElement),
        {ok, _} ?= property_elements(PropertiesContent),
        {ok, SigPropsElement} ?=
            signerl_xades_xml:find_signed_signature_properties(SignatureElement),
        {?XADES_NAME(<<"SignedSignatureProperties">>), _, SigProps} =
            xmlan:expanded_names(SigPropsElement),
        {ok, SigElements} ?= property_elements(SigProps),
        {ok, Validated} ?= validate_signed_signature_properties(SigElements, #{}),
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
    case validate_signature_production_place(Content) of
        {ok, Place} -> put_unique_property(signature_production_place, Place, SignedProperties);
        {error, _} = Err -> Err
    end;
validate_signed_signature_property({?XADES_NAME(<<"SignerRole">>), _, Content}, SignedProperties) ->
    case validate_signer_role(Content) of
        {ok, Role} ->
            put_unique_property(signer_role, Role, SignedProperties);
        {error, _} = Err ->
            Err
    end;
validate_signed_signature_property({_Tag, _Attrs, _Content}, SignedProperties) ->
    {ok, SignedProperties}.

put_unique_property(Key, Value, Properties) ->
    case maps:is_key(Key, Properties) of
        true ->
            {error, duplicate_property};
        false ->
            {ok, maps:put(Key, Value, Properties)}
    end.

%%--- SignedDataObjectProperties pipeline ---

validate_signed_data_object_properties({error, missing_element}, Acc) ->
    {ok, Acc};
validate_signed_data_object_properties({error, _} = Error, _Acc) ->
    Error;
validate_signed_data_object_properties({ok, Element}, Acc) ->
    {?XADES_NAME(<<"SignedDataObjectProperties">>), _, Content} =
        xmlan:expanded_names(Element),
    maybe
        {ok, Elements} ?= property_elements(Content),
        validate_data_object_elements(Elements, Acc)
    end.

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

validate_signing_certificate_v2(Content) ->
    maybe
        {ok, Elements} ?= property_elements(Content),
        {ok, {_, _, CertContent}} ?= unique_element(?XADES_NAME(<<"Cert">>), Elements),
        {ok, CertElements} ?= property_elements(CertContent),
        {ok, {_, _, DigestContent}} ?= unique_element(?XADES_NAME(<<"CertDigest">>), CertElements),
        {ok, CertDigest} ?= extract_digest(DigestContent),
        {ok, IssuerSerial} ?= extract_issuer_serial_v2(CertElements),
        {ok, maps:merge(CertDigest, IssuerSerial)}
    else
        _ -> {error, invalid_signing_certificate_v2}
    end.

extract_issuer_serial_v2(Content) ->
    case elements(?XADES_NAME(<<"IssuerSerialV2">>), Content) of
        [] ->
            {ok, #{}};
        [{_, _, [Text]}] ->
            case decode_base64_text(Text) of
                {ok, Der} -> {ok, #{issuer_serial_v2 => Der}};
                _ -> error
            end;
        _ ->
            error
    end.

%%--- SignaturePolicyIdentifier ---

validate_signature_policy_identifier(Content) ->
    maybe
        {ok, Fields} ?= property_elements(Content),
        case
            {
                elements(?XADES_NAME(<<"SignaturePolicyImplied">>), Fields),
                elements(?XADES_NAME(<<"SignaturePolicyId">>), Fields)
            }
        of
            {[{_, _, Implied}], []} ->
                case empty_content(Implied) of
                    true -> {ok, #{type => implied}};
                    false -> {error, invalid_signature_policy_identifier}
                end;
            {[], [{_, _, PolicyContent}]} ->
                parse_signature_policy_id(PolicyContent);
            _ ->
                {error, invalid_signature_policy_identifier}
        end
    else
        _ -> {error, invalid_signature_policy_identifier}
    end.

parse_signature_policy_id(Content) ->
    maybe
        {ok, Fields} ?= property_elements(Content),
        {ok, {_, _, IdContent}} ?= unique_element(?XADES_NAME(<<"SigPolicyId">>), Fields),
        {ok, Identifier} ?= extract_object_identifier(IdContent),
        {ok, {_, _, HashContent}} ?= unique_element(?XADES_NAME(<<"SigPolicyHash">>), Fields),
        {ok, PolicyHash} ?= extract_digest(HashContent),
        {ok, maps:merge(Identifier#{type => explicit}, PolicyHash)}
    else
        _ -> {error, invalid_signature_policy_identifier}
    end.

%%--- SignatureProductionPlace ---

validate_signature_production_place(Content) ->
    case
        extract_text_fields(Content, [
            {?XADES_NAME(<<"City">>), city},
            {?XADES_NAME(<<"StateOrProvince">>), state_or_province},
            {?XADES_NAME(<<"PostalCode">>), postal_code},
            {?XADES_NAME(<<"CountryName">>), country_name}
        ])
    of
        {ok, _} = Result -> Result;
        _ -> {error, invalid_signature_production_place}
    end.

%%--- SignerRole ---

validate_signer_role(Content) ->
    maybe
        {ok, Fields} ?= property_elements(Content),
        {ok, Claimed} ?=
            extract_roles(
                ?XADES_NAME(<<"ClaimedRoles">>), ?XADES_NAME(<<"ClaimedRole">>), Fields
            ),
        {ok, Certified} ?=
            extract_roles(
                ?XADES_NAME(<<"CertifiedRoles">>), ?XADES_NAME(<<"CertifiedRole">>), Fields
            ),
        case {Claimed, Certified} of
            {[], []} -> {error, invalid_signer_role};
            {[], _} -> {ok, #{certified_roles => Certified}};
            {_, []} -> {ok, #{claimed_roles => Claimed}};
            _ -> {ok, #{claimed_roles => Claimed, certified_roles => Certified}}
        end
    else
        _ -> {error, invalid_signer_role}
    end.

extract_roles(Container, Item, Content) ->
    case elements(Container, Content) of
        [] -> {ok, []};
        [{_, _, Items}] -> repeated_text(Item, Items);
        _ -> error
    end.

%%--- DataObjectFormat ---

validate_data_object_format(Attrs, Content) ->
    maybe
        {ok, ObjectRef} ?= xmlan:attr_value(<<"ObjectReference">>, Attrs),
        {ok, Fields} ?= property_elements(Content),
        {ok, Format} ?=
            extract_text_fields(Fields, [
                {?XADES_NAME(<<"MimeType">>), mime_type},
                {?XADES_NAME(<<"Description">>), description},
                {?XADES_NAME(<<"Encoding">>), encoding}
            ]),
        ok ?= validate_optional_object_identifier(Fields),
        {ok, Format#{object_reference => ObjectRef}}
    else
        _ -> {error, invalid_data_object_format}
    end.

validate_optional_object_identifier(Content) ->
    case elements(?XADES_NAME(<<"ObjectIdentifier">>), Content) of
        [] ->
            ok;
        [{_, _, Fields}] ->
            case extract_object_identifier(Fields) of
                {ok, _} -> ok;
                _ -> error
            end;
        _ ->
            error
    end.

%%--- CommitmentTypeIndication ---

validate_commitment_type_indication(Content) ->
    maybe
        {ok, Fields} ?= property_elements(Content),
        {ok, {_, _, IdContent}} ?= unique_element(?XADES_NAME(<<"CommitmentTypeId">>), Fields),
        {ok, #{identifier := Identifier}} ?= extract_object_identifier(IdContent),
        {ok, Scope} ?= extract_commitment_scope(Fields),
        {ok, #{identifier => Identifier, scope => Scope}}
    else
        _ -> {error, invalid_commitment_type_indication}
    end.

extract_commitment_scope(Content) ->
    case
        {
            elements(?XADES_NAME(<<"AllSignedDataObjects">>), Content),
            elements(?XADES_NAME(<<"ObjectReference">>), Content)
        }
    of
        {[{_, _, All}], []} ->
            case empty_content(All) of
                true -> {ok, all};
                false -> error
            end;
        {[], [_ | _]} ->
            case repeated_text(?XADES_NAME(<<"ObjectReference">>), Content) of
                {ok, Refs} -> {ok, {references, [binary_to_list(Ref) || Ref <- Refs]}};
                _ -> error
            end;
        _ ->
            error
    end.

%%--- Shared helpers ---

%% Known-property cardinality belongs here; XML name/context handling stays in xmlan.
elements(Tag, Content) ->
    [E || E = {Name, _, _} <- Content, Name =:= Tag].

unique_element(Tag, Content) ->
    case elements(Tag, Content) of
        [Element] -> {ok, Element};
        _ -> error
    end.

%% Property containers allow element children and formatting whitespace only.
property_elements(Content) ->
    property_elements(Content, []).

property_elements([], Acc) ->
    {ok, lists:reverse(Acc)};
property_elements([{_, _, _} = Element | Rest], Acc) ->
    property_elements(Rest, [Element | Acc]);
property_elements([Text | Rest], Acc) ->
    case whitespace_text(Text) of
        true -> property_elements(Rest, Acc);
        false -> {error, invalid_signed_properties}
    end.

empty_content(Content) ->
    lists:all(fun whitespace_text/1, Content).

whitespace_text(Text) when is_binary(Text) ->
    whitespace_text(binary_to_list(Text));
whitespace_text(Text) when is_list(Text) ->
    lists:all(fun(Char) -> lists:member(Char, " \t\r\n") end, Text);
whitespace_text(_) ->
    false.

extract_digest(Content) ->
    maybe
        {ok, Fields} ?= property_elements(Content),
        {ok, {_, Attrs, MethodContent}} ?= unique_element(?DSIG_NAME(<<"DigestMethod">>), Fields),
        true ?= empty_content(MethodContent),
        {ok, Method} ?= xmlan:attr_value(<<"Algorithm">>, Attrs),
        {ok, {_, _, [Text]}} ?= unique_element(?DSIG_NAME(<<"DigestValue">>), Fields),
        {ok, Digest} ?= decode_base64_text(Text),
        {ok, #{digest_method => Method, digest_value => Digest}}
    else
        _ -> error
    end.

%% ObjectIdentifier is shared by policy IDs, commitment IDs and format metadata.
extract_object_identifier(Content) ->
    maybe
        {ok, Fields} ?= property_elements(Content),
        {ok, #{identifier := _} = Identifier} ?=
            extract_text_fields(Fields, [
                {?XADES_NAME(<<"Identifier">>), identifier},
                {?XADES_NAME(<<"Description">>), description}
            ]),
        ok ?= validate_documentation_references(Fields),
        {ok, Identifier}
    else
        _ -> error
    end.

validate_documentation_references(Content) ->
    case elements(?XADES_NAME(<<"DocumentationReferences">>), Content) of
        [] ->
            ok;
        [{_, _, References}] ->
            case repeated_text(?XADES_NAME(<<"DocumentationReference">>), References) of
                {ok, _} -> ok;
                _ -> error
            end;
        _ ->
            error
    end.

extract_text_fields(Content, Names) ->
    maybe
        {ok, Fields} ?= property_elements(Content),
        extract_text_fields(Fields, Names, #{})
    end.

extract_text_fields([], _Names, Acc) ->
    {ok, Acc};
extract_text_fields([{Tag, _, _} = Element | Rest], Names, Acc) ->
    case lists:keyfind(Tag, 1, Names) of
        false ->
            extract_text_fields(Rest, Names, Acc);
        {_, Key} ->
            maybe
                false ?= maps:is_key(Key, Acc),
                {ok, Text} ?= element_text(Element),
                extract_text_fields(Rest, Names, Acc#{Key => Text})
            else
                _ -> error
            end
    end.

repeated_text(Tag, Content) ->
    maybe
        {ok, Fields} ?= property_elements(Content),
        [_ | _] = Items ?= elements(Tag, Fields),
        collect_text(Items, [])
    else
        _ -> error
    end.

collect_text([], Acc) ->
    {ok, lists:reverse(Acc)};
collect_text([Element | Rest], Acc) ->
    case element_text(Element) of
        {ok, Text} -> collect_text(Rest, [Text | Acc]);
        _ -> error
    end.

element_text(Element) ->
    % xmlan owns Unicode text conversion. Reject malformed direct extraction
    % inputs as property errors, without catching caller key/crypto failures.
    try xmlan:single_text(Element) of
        {ok, Text} when is_binary(Text) -> {ok, Text};
        _ -> {error, invalid_text}
    catch
        error:badarg -> {error, invalid_text}
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
