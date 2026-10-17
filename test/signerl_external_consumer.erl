-module(signerl_external_consumer).

-include_lib("stdlib/include/assert.hrl").
-include_lib("public_key/include/public_key.hrl").

-export([run/2]).

-spec run(string(), string()) -> ok.
run(Fixtures, Work) ->
    ?assertMatch({ok, _}, application:ensure_all_started(signerl)),
    ok = xmlan_contract_consumer:run(Fixtures),
    dependency_pin(Work),
    #{key := Key, cert := Cert} = public_key:pkix_test_root_cert(
        "Signerl external consumer", [{key, public_key:generate_key({rsa, 2048, 65537})}]
    ),
    Public = rsa_public(Key),
    Wrong = rsa_public(public_key:generate_key({rsa, 2048, 65537})),
    {ok, FrozenInput} = file:read_file(filename:join(Fixtures, "input.xml")),
    lists:foreach(
        fun(Input) ->
            check_public_arities(Input, Key, Cert, Public, Wrong, Work)
        end,
        [
            FrozenInput,
            <<
                "<?xml version='1.0'?><root xmlns='urn:root'><child xmlns=''>"
                "café &amp; 東京</child></root>"/utf8
            >>
        ]
    ),
    ok.

rsa_public(Key) ->
    #'RSAPublicKey'{
        modulus = Key#'RSAPrivateKey'.modulus,
        publicExponent = Key#'RSAPrivateKey'.publicExponent
    }.

check_public_arities(Input, Key, Cert, Public, Wrong, Work) ->
    Path = filename:join(Work, "input.xml"),
    ok = file:write_file(Path, Input),
    Time = <<"2026-10-13T12:34:56Z">>,
    Fixed = signerl:sign(Input, sha256, Key, Cert, Time),
    ?assertEqual(Fixed, signerl:sign(Path, sha256, Key, Cert, Time)),
    lists:foreach(
        fun(Signed) ->
            ?assert(is_binary(Signed)),
            ?assertEqual(true, signerl:verify(Signed, sha256, Public)),
            ?assertEqual(false, signerl:verify(Signed, sha256, Wrong)),
            {ok, Tree = {Tag, Attrs, Children}} = xmlan:parse_binary(Signed),
            {ok, Prolog} = xmlan:parse_prolog(Signed),
            ?assertEqual(true, signerl:verify(xmlan:export(Prolog, Tree), sha256, Public)),
            Tampered = xmlan:export(Prolog, {Tag, [{<<"tampered">>, "true"} | Attrs], Children}),
            ?assertEqual(false, signerl:verify(Tampered, sha256, Public)),
            SignedPath = filename:join(Work, "signed.xml"),
            ok = signerl_xml:to_file(SignedPath, Signed),
            ?assertEqual(true, signerl:verify(SignedPath, sha256, Public)),
            ?assertEqual(false, signerl:verify(SignedPath, sha256, Wrong)),
            ok = signerl_xml:to_file(SignedPath, Tampered),
            ?assertEqual(false, signerl:verify(SignedPath, sha256, Public))
        end,
        [
            signerl:sign(Input, sha256, Key),
            signerl:sign(Path, sha256, Key),
            signerl:sign(Input, sha256, Key, Cert),
            signerl:sign(Path, sha256, Key, Cert),
            Fixed
        ]
    ).

dependency_pin(Work) ->
    {ok, Config} = file:consult(filename:join(code:lib_dir(signerl), "rebar.config")),
    [{xmlan, Xmlan = {git, "https://github.com/bormilan/xmlan.git", {ref, Ref}}}] =
        proplists:get_value(deps, Config),
    {ok, [Lock]} = file:consult("rebar.lock"),
    ?assertEqual(2, length(Lock)),
    ?assert(lists:member({<<"xmlan">>, Xmlan, 1}, Lock)),
    {ok, Expected} = file:read_file(filename:join(Work, "signerl.expected-ref")),
    SignerlRef = string:trim(binary_to_list(Expected)),
    ?assert(
        lists:member(
            {<<"signerl">>, {git, "https://github.com/bormilan/signerl.git", {ref, SignerlRef}}, 0},
            Lock
        )
    ),
    ?assertEqual(
        {ok, [[{<<"xmlan">>, Xmlan, 0}]]},
        file:consult(filename:join(code:lib_dir(signerl), "rebar.lock"))
    ),
    ok = file:write_file(filename:join(Work, "xmlan.expected-ref"), Ref ++ "\n").
