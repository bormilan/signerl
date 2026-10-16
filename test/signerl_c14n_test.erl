-module(signerl_c14n_test).

-include_lib("eunit/include/eunit.hrl").

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
    ?assertEqual(Expected, signerl_c14n:remove_signature_elements(Input)).

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
    ?assertEqual(Expected, signerl_c14n:remove_signature_elements(Input)).

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
        signerl_c14n:remove_signature_elements(Input)
    ).

remove_signature_no_signature_present_test() ->
    Input = {<<"root">>, [], [{<<"child">>, [], ["text"]}]},
    ?assertEqual(Input, signerl_c14n:remove_signature_elements(Input)).
