-module(signerl_xades_xml).
-include("signerl_dsig.hrl").

-export([
    find_signed_signature_properties/1,
    find_signed_data_object_properties/1,
    find_signed_properties_element/1
]).

-spec find_signed_signature_properties(signerl_xml:simplified_xml()) ->
    {ok, signerl_xml:simplified_xml()} | {error, missing_element}.
find_signed_signature_properties(SignatureElement) ->
    find_properties([?XADES_NAME(<<"SignedSignatureProperties">>)], SignatureElement).

-spec find_signed_data_object_properties(signerl_xml:simplified_xml()) ->
    {ok, signerl_xml:simplified_xml()} | {error, missing_element}.
find_signed_data_object_properties(SignatureElement) ->
    find_properties([?XADES_NAME(<<"SignedDataObjectProperties">>)], SignatureElement).

-spec find_signed_properties_element(signerl_xml:simplified_xml()) ->
    {ok, signerl_xml:simplified_xml()} | {error, missing_element}.
find_signed_properties_element(SignatureElement) ->
    find_properties([], SignatureElement).

find_properties(Tail, SignatureElement) ->
    case signerl_xml:is_signature_element(SignatureElement) of
        true ->
            Path = [
                ?DSIG_NAME(<<"Object">>),
                ?XADES_NAME(<<"QualifyingProperties">>),
                ?XADES_NAME(<<"SignedProperties">>)
                | Tail
            ],
            case signerl_xml:find_path(Path, SignatureElement) of
                {ok, _} = Ok -> Ok;
                {error, not_found} -> {error, missing_element}
            end;
        false ->
            {error, missing_element}
    end.
