-module(signerl_xades_xml_test).

-include_lib("eunit/include/eunit.hrl").

xades_xml_returns_error_with_non_signature_input_test() ->
    InvalidElement = {'root', [], []},
    ?assertEqual(
        {error, missing_element},
        signerl_xades_xml:find_signed_signature_properties(InvalidElement)
    ),
    ?assertEqual(
        {error, missing_element},
        signerl_xades_xml:find_signed_properties_element(InvalidElement)
    ).
