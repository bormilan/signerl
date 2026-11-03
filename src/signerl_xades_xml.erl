-module(signerl_xades_xml).
-include("signerl_dsig.hrl").

-export([
    find_signed_signature_properties/1,
    find_signed_data_object_properties/1,
    find_signed_properties_element/1
]).

-spec find_signed_signature_properties(xmlan:simplified_xml()) ->
    {ok, xmlan:simplified_xml()} | {error, missing_element | duplicate_property}.
find_signed_signature_properties(SignatureElement) ->
    find_properties([?XADES_NAME(<<"SignedSignatureProperties">>)], SignatureElement).

-spec find_signed_data_object_properties(xmlan:simplified_xml()) ->
    {ok, xmlan:simplified_xml()} | {error, missing_element | duplicate_property}.
find_signed_data_object_properties(SignatureElement) ->
    find_properties([?XADES_NAME(<<"SignedDataObjectProperties">>)], SignatureElement).

-spec find_signed_properties_element(xmlan:simplified_xml()) ->
    {ok, xmlan:simplified_xml()} | {error, missing_element}.
find_signed_properties_element(SignatureElement) ->
    find_properties([], SignatureElement).

find_properties([Name], SignatureElement) ->
    case find_signed_properties_element(SignatureElement) of
        {ok, Parent} ->
            case xmlan:find_children(Name, Parent) of
                [] -> {error, missing_element};
                [Element] -> {ok, Element};
                _ -> {error, duplicate_property}
            end;
        {error, _} = Error ->
            Error
    end;
find_properties([], SignatureElement) ->
    case signerl_dsig_utils:is_signature_element(SignatureElement) of
        true ->
            Path = [
                ?DSIG_NAME(<<"Object">>),
                ?XADES_NAME(<<"QualifyingProperties">>),
                ?XADES_NAME(<<"SignedProperties">>)
            ],
            case xmlan:find_path(Path, SignatureElement) of
                {ok, _} = Ok -> Ok;
                {error, not_found} -> {error, missing_element}
            end;
        false ->
            {error, missing_element}
    end.
