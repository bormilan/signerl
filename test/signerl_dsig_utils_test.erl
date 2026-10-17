-module(signerl_dsig_utils_test).

-include_lib("eunit/include/eunit.hrl").
-include("signerl_dsig.hrl").

is_signature_element_shared_test() ->
    SigElement = {<<"ds:Signature">>, [{<<"xmlns:ds">>, ?DSIG_NAMESPACE_URI}], []},
    NonSigElement = {<<"ds:SignedInfo">>, [], []},
    ?assertEqual(true, signerl_dsig_utils:is_signature_element(SigElement)),
    ?assertEqual(false, signerl_dsig_utils:is_signature_element(NonSigElement)),
    ?assertEqual(false, signerl_dsig_utils:is_signature_element("text")).

namespace_signature_recognition_test_() ->
    [
        {Label, ?_assertEqual(Expected, signerl_dsig_utils:is_signature_element(Element))}
     || {Label, Element, Expected} <- [
            {"alias", {<<"sig:Signature">>, [{<<"xmlns:sig">>, ?DSIG_NAMESPACE_URI}], []}, true},
            {"default", {<<"Signature">>, [{<<"xmlns">>, ?DSIG_NAMESPACE_URI}], []}, true},
            {"undeclared prefix", {<<"ds:Signature">>, [], []}, false},
            {"wrong namespace", {<<"ds:Signature">>, [{<<"xmlns:ds">>, "urn:wrong"}], []}, false},
            {"text", "ds:Signature", false}
        ]
    ].

remove_signature_from_root_test() ->
    Input =
        {<<"root">>, [], [
            {<<"child">>, [], ["text"]},
            {<<"ds:Signature">>, [{<<"xmlns:ds">>, "http://www.w3.org/2000/09/xmldsig#"}], [
                {<<"ds:SignedInfo">>, [], []}
            ]},
            {<<"other">>, [], ["data"]}
        ]},
    Expected =
        {<<"root">>, [], [
            {<<"child">>, [], ["text"]},
            {<<"other">>, [], ["data"]}
        ]},
    ?assertEqual(Expected, signerl_dsig_utils:remove_signature_elements(Input)).

remove_signature_preserves_other_children_test() ->
    Attrs = [{<<"id">>, "1"}, {<<"xmlns:ds">>, "http://www.w3.org/2000/09/xmldsig#"}],
    Input =
        {<<"root">>, Attrs, [
            {<<"a">>, [], []},
            {<<"b">>, [], []},
            {<<"ds:Signature">>, [], [{<<"value">>, [], ["sig"]}]},
            {<<"c">>, [], []}
        ]},
    Expected =
        {<<"root">>, Attrs, [
            {<<"a">>, [], []}, {<<"b">>, [], []}, {<<"c">>, [], []}
        ]},
    ?assertEqual(Expected, signerl_dsig_utils:remove_signature_elements(Input)).

remove_signature_resolves_namespace_context_test() ->
    Attrs = [
        {<<"xmlns:s">>, "http://www.w3.org/2000/09/xmldsig#"},
        {<<"xmlns:ds">>, "urn:decoy"}
    ],
    Decoy = {<<"ds:Signature">>, [], ["document content"]},
    Rebound = {<<"s:Signature">>, [{<<"xmlns:s">>, "urn:decoy"}], []},
    Input =
        {<<"root">>, Attrs, [
            "before",
            {<<"s:Signature">>, [], []},
            Decoy,
            Rebound,
            {<<"ds:Signature">>, [{<<"xmlns:ds">>, "http://www.w3.org/2000/09/xmldsig#"}], []},
            <<"after">>
        ]},
    ?assertEqual(
        {<<"root">>, Attrs, ["before", Decoy, Rebound, <<"after">>]},
        signerl_dsig_utils:remove_signature_elements(Input)
    ).

remove_signature_no_signature_present_test() ->
    Input = {<<"root">>, [], [{<<"child">>, [], ["text"]}]},
    ?assertEqual(Input, signerl_dsig_utils:remove_signature_elements(Input)).
