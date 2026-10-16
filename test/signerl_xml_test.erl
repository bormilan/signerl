-module(signerl_xml_test).

-include_lib("eunit/include/eunit.hrl").
-include("signerl_dsig.hrl").

is_signature_element_shared_test() ->
    SigElement = {<<"ds:Signature">>, [{<<"xmlns:ds">>, ?DSIG_NAMESPACE_URI}], []},
    NonSigElement = {<<"ds:SignedInfo">>, [], []},
    ?assertEqual(true, signerl_xml:is_signature_element(SigElement)),
    ?assertEqual(false, signerl_xml:is_signature_element(NonSigElement)),
    ?assertEqual(false, signerl_xml:is_signature_element("text")).

namespace_signature_recognition_test_() ->
    [
        {Label, ?_assertEqual(Expected, signerl_xml:is_signature_element(Element))}
     || {Label, Element, Expected} <- [
            {"alias", {<<"sig:Signature">>, [{<<"xmlns:sig">>, ?DSIG_NAMESPACE_URI}], []}, true},
            {"default", {<<"Signature">>, [{<<"xmlns">>, ?DSIG_NAMESPACE_URI}], []}, true},
            {"undeclared prefix", {<<"ds:Signature">>, [], []}, false},
            {"wrong namespace", {<<"ds:Signature">>, [{<<"xmlns:ds">>, "urn:wrong"}], []}, false},
            {"text", "ds:Signature", false}
        ]
    ].
