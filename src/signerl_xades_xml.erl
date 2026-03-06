-module(signerl_xades_xml).

-export([
    find_signed_signature_properties/1,
    find_signed_properties_element/1
]).

-spec find_signed_signature_properties(SignatureElement) -> Result when
    SignatureElement :: signerl_xml:simplified_xml(),
    Result :: {ok, signerl_xml:simplified_xml()} | {error, invalid_signature}.
find_signed_signature_properties({'ds:Signature', _, SignatureContent}) ->
    case
        signerl_xml:find_path(
            [
                'ds:Object',
                'xades:QualifyingProperties',
                'xades:SignedProperties',
                'xades:SignedSignatureProperties'
            ],
            {'ds:Signature', [], SignatureContent}
        )
    of
        {ok, _} = Ok ->
            Ok;
        error ->
            {error, invalid_signature}
    end;
find_signed_signature_properties(_) ->
    {error, invalid_signature}.

-spec find_signed_properties_element(SignatureElement) -> Result when
    SignatureElement :: signerl_xml:simplified_xml(),
    Result :: {ok, signerl_xml:simplified_xml()} | {error, invalid_signature}.
find_signed_properties_element({'ds:Signature', _, _} = SignatureElement) ->
    case
        signerl_xml:find_path(
            [
                'ds:Object',
                'xades:QualifyingProperties',
                'xades:SignedProperties'
            ],
            SignatureElement
        )
    of
        {ok, {'xades:SignedProperties', _, _} = SignedPropertiesElement} ->
            {ok, SignedPropertiesElement};
        _ ->
            {error, invalid_signature}
    end;
find_signed_properties_element(_) ->
    {error, invalid_signature}.
