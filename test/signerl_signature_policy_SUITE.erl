-module(signerl_signature_policy_SUITE).

-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").
-include("signerl_dsig.hrl").
-compile([export_all, nowarn_export_all]).

suite() ->
    [{timetrap, {seconds, 30}}].

all() ->
    [
        generated_transforms,
        reference_count_and_targets,
        actual_ids_and_targets,
        declared_methods,
        transform_pairs,
        transform_parameters,
        formatted_transform_controls,
        signature_placement,
        signing_rejects_existing_signatures,
        signing_avoids_id_collisions,
        signature_lookalikes_remain_content
    ].

init_per_suite(Config) ->
    Key = signerl_cert_helpers:signer_rsa_key(),
    PublicKey = signerl_cert_helpers:rsa_public_key_from_cert(
        signerl_cert_helpers:signer_rsa_cert_path()
    ),
    Raw = <<"<?xml version='1.0'?><invoice><amount>42.00</amount></invoice>">>,
    Signed = signerl:sign(Raw, sha256, Key, undefined, <<"2026-10-24T12:00:00Z">>),
    Parsed = test_helpers:parse_verified_message(Signed, PublicKey),
    [{key, Key}, {public_key, PublicKey}, {raw, Raw}, {parsed, Parsed} | Config].

end_per_suite(_Config) ->
    ok.

generated_transforms(Config) ->
    Parsed = ?config(parsed, Config),
    Document = signed_info(Parsed),
    [Doc, Props] = xmlan:find_children(?DSIG_NAME(<<"Reference">>), Document),
    ?assertEqual(
        [?DSIG_ENVELOPED_SIGNATURE_TRANSFORM_URI, ?DSIG_C14N11_ALGO_URI],
        algorithms(Doc)
    ),
    ?assertEqual([?DSIG_C14N11_ALGO_URI], algorithms(Props)).

reference_count_and_targets(Config) ->
    foreach_pair(Config, fun(Tree) ->
        [Doc, Props] = references(Tree),
        [
            {extra_reference,
                set_references(Tree, [Doc, Props, set_attr(Doc, <<"URI">>, "#missing")])},
            {external_reference,
                set_references(Tree, [
                    Doc, set_attr(Props, <<"URI">>, "https://invalid.example/properties")
                ])},
            {missing_document, set_references(Tree, [Props])},
            {missing_properties, set_references(Tree, [Doc])},
            {duplicate_document, set_references(Tree, [Doc, Doc])},
            {duplicate_properties, set_references(Tree, [Props, Props])},
            {missing_uri, set_references(Tree, [Doc, remove_attr(Props, <<"URI">>)])},
            {wrong_type, set_references(Tree, [Doc, set_attr(Props, <<"Type">>, "urn:wrong")])},
            {missing_type, set_references(Tree, [Doc, remove_attr(Props, <<"Type">>)])},
            {unexpected_document_type,
                set_references(Tree, [set_attr(Doc, <<"Type">>, "urn:wrong"), Props])}
        ]
    end).

actual_ids_and_targets(Config) ->
    lists:foreach(
        fun(Mode) ->
            Tree = pair(?config(parsed, Config), Mode),
            Renamed = rename_ids(Tree),
            Mutations = [
                {missing_signature_id,
                    update(Tree, <<"ds:Signature">>, fun(E) -> remove_attr(E, <<"Id">>) end)},
                {empty_signature_id,
                    update(Tree, <<"ds:Signature">>, fun(E) -> set_attr(E, <<"Id">>, "") end)},
                {missing_properties_id,
                    update(Tree, <<"xades:SignedProperties">>, fun(E) ->
                        remove_attr(E, <<"Id">>)
                    end)},
                {wrong_properties_id,
                    update(Tree, <<"xades:SignedProperties">>, fun(E) ->
                        set_attr(E, <<"Id">>, "other-properties")
                    end)},
                {missing_target,
                    update(Tree, <<"xades:QualifyingProperties">>, fun(E) ->
                        remove_attr(E, <<"Target">>)
                    end)},
                {wrong_target,
                    update(Tree, <<"xades:QualifyingProperties">>, fun(E) ->
                        set_attr(E, <<"Target">>, "#missing")
                    end)},
                {duplicate_signature_id,
                    add_payload(Tree, {<<"record">>, [{<<"Id">>, ?SIGNATURE_ID}], []})},
                {duplicate_properties_id,
                    add_payload(Tree, {<<"record">>, [{<<"Id">>, ?SIGNED_PROPERTIES_ID}], []})},
                {xml_id_collision,
                    add_payload(Tree, {<<"record">>, [{<<"xml:id">>, ?SIGNED_PROPERTIES_ID}], []})},
                {duplicate_payload_id, duplicate_payload_id(Tree)},
                {ambiguous_properties,
                    update(Tree, <<"xades:QualifyingProperties">>, fun({N, A, C}) ->
                        {N, A, C ++ C}
                    end)},
                {ambiguous_target,
                    update(Tree, <<"ds:Object">>, fun({N, A, C}) -> {N, A, C ++ C} end)}
            ],
            lists:foreach(
                fun({Label, Changed}) -> assert_rejected(Label, Changed, Config) end, Mutations
            ),
            assert_accepted(Renamed, Config)
        end,
        [legacy, explicit]
    ).

declared_methods(Config) ->
    foreach_pair(Config, fun(Tree) ->
        [Doc, Props] = references(Tree),
        [
            {rsa_declared_ecdsa,
                update(Tree, <<"ds:SignatureMethod">>, fun(E) ->
                    set_attr(E, <<"Algorithm">>, ?DSIG_SIG_ECDSA_SHA256_URI)
                end)},
            {rsa_declared_sha512,
                update(Tree, <<"ds:SignatureMethod">>, fun(E) ->
                    set_attr(E, <<"Algorithm">>, ?DSIG_SIG_RSA_SHA512_URI)
                end)},
            {document_digest_method,
                set_references(Tree, [
                    update(Doc, <<"ds:DigestMethod">>, fun(E) ->
                        set_attr(E, <<"Algorithm">>, ?DSIG_DIGEST_SHA512_URI)
                    end),
                    Props
                ])},
            {properties_digest_method,
                set_references(Tree, [
                    Doc,
                    update(Props, <<"ds:DigestMethod">>, fun(E) ->
                        set_attr(E, <<"Algorithm">>, ?DSIG_DIGEST_SHA1_URI)
                    end)
                ])}
        ]
    end),
    EcKey = signerl_cert_helpers:signer_ecdsa_key(),
    EcPublic = signerl_cert_helpers:ecdsa_public_key_from_cert(
        signerl_cert_helpers:signer_ecdsa_cert_path()
    ),
    EcSigned = signerl:sign(?config(raw, Config), sha256, EcKey),
    EcTree = test_helpers:parse_verified_message(EcSigned, EcPublic),
    EcConfig = [{key, EcKey}, {public_key, EcPublic} | Config],
    Changed = update(EcTree, <<"ds:SignatureMethod">>, fun(E) ->
        set_attr(E, <<"Algorithm">>, ?DSIG_SIG_RSA_SHA256_URI)
    end),
    assert_rejected(ecdsa_declared_rsa, Changed, EcConfig),
    %% RSA private-key verification remains supported, as do PEM convenience paths.
    ?assertEqual(
        true,
        signerl:verify(xmlan:export([], ?config(parsed, Config)), sha256, ?config(key, Config))
    ).

transform_pairs(Config) ->
    Tree = ?config(parsed, Config),
    Explicit = pair(Tree, explicit),
    Legacy = pair(Tree, legacy),
    assert_accepted(Explicit, Config),
    assert_accepted(Legacy, Config),
    %% Exclusive C14N SignedInfo works with either reference pair.
    lists:foreach(
        fun(T) ->
            Exc = update(T, <<"ds:CanonicalizationMethod">>, fun(E) ->
                set_attr(E, <<"Algorithm">>, ?DSIG_EXC_C14N_ALGO_URI)
            end),
            assert_accepted(Exc, Config),
            [Doc, Props] = references(T),
            assert_accepted(set_references(T, [Props, Doc]), Config)
        end,
        [Explicit, Legacy]
    ),
    [NewDoc, NewProps] = references(Explicit),
    [OldDoc, OldProps] = references(Legacy),
    Cases = [
        {explicit_document_legacy_properties, set_references(Tree, [NewDoc, OldProps])},
        {legacy_document_explicit_properties, set_references(Tree, [OldDoc, NewProps])},
        {reversed_transforms,
            set_references(Tree, [
                set_transforms(NewDoc, [
                    ?DSIG_C14N11_ALGO_URI, ?DSIG_ENVELOPED_SIGNATURE_TRANSFORM_URI
                ]),
                NewProps
            ])},
        {extra_transform,
            set_references(Tree, [
                set_transforms(NewDoc, [
                    ?DSIG_ENVELOPED_SIGNATURE_TRANSFORM_URI,
                    ?DSIG_C14N11_ALGO_URI,
                    ?DSIG_C14N11_ALGO_URI
                ]),
                NewProps
            ])},
        {unsupported_properties_transform,
            set_references(Tree, [NewDoc, set_transforms(NewProps, [?DSIG_EXC_C14N_ALGO_URI])])},
        {empty_legacy_transforms, set_references(Tree, [OldDoc, set_transforms(OldProps, [])])}
    ],
    lists:foreach(fun({Label, Changed}) -> assert_rejected(Label, Changed, Config) end, Cases).

transform_parameters(Config) ->
    foreach_pair(Config, fun(Tree) ->
        [Doc, Props] = references(Tree),
        [
            {transform_parameter_attribute,
                set_references(Tree, [
                    update(Doc, <<"ds:Transform">>, fun(E) ->
                        set_attr(E, <<"Unexpected">>, "value")
                    end),
                    Props
                ])},
            {transform_parameter_child,
                set_references(Tree, [
                    update(Doc, <<"ds:Transform">>, fun({N, A, _}) ->
                        {N, A, [{<<"ds:XPath">>, [], ["."]}]}
                    end),
                    Props
                ])},
            {transforms_parameter,
                set_references(Tree, [
                    update(Doc, <<"ds:Transforms">>, fun(E) ->
                        set_attr(E, <<"Unexpected">>, "value")
                    end),
                    Props
                ])},
            {duplicate_transforms,
                set_references(Tree, [duplicate_child(Doc, <<"ds:Transforms">>), Props])},
            {duplicate_digest_method,
                set_references(Tree, [duplicate_child(Doc, <<"ds:DigestMethod">>), Props])},
            {digest_parameter,
                set_references(Tree, [
                    update(Doc, <<"ds:DigestMethod">>, fun({N, A, _}) -> {N, A, ["invalid"]} end),
                    Props
                ])},
            {c14n_parameter,
                update(Tree, <<"ds:CanonicalizationMethod">>, fun(E) ->
                    set_attr(E, <<"Unexpected">>, "value")
                end)},
            {signature_parameter,
                update(Tree, <<"ds:SignatureMethod">>, fun({N, A, _}) ->
                    {N, A, [{<<"ds:HMACOutputLength">>, [], ["8"]}]}
                end)}
        ]
    end).

formatted_transform_controls(Config) ->
    lists:foreach(
        fun(Mode) ->
            Tree = pair(?config(parsed, Config), Mode),
            Spaced = update(Tree, <<"ds:Transforms">>, fun({N, A, C}) ->
                {N, A, ["\n  " | C] ++ ["\n"]}
            end),
            Alias = update(Spaced, <<"ds:Transform">>, fun({_, A, _}) ->
                {<<"local:Transform">>, [{<<"xmlns:local">>, ?DSIG_NAMESPACE_URI} | A], [" \t\r\n"]}
            end),
            assert_accepted(Alias, Config),
            %% Non-whitespace text is a parameter, not formatting.
            Bad = update(Spaced, <<"ds:Transforms">>, fun({N, A, C}) ->
                {N, A, ["unexpected" | C]}
            end),
            assert_rejected(non_whitespace_transform_content, Bad, Config)
        end,
        [explicit, legacy]
    ).

signature_placement(Config) ->
    Tree = ?config(parsed, Config),
    {Root, Attrs, Children} = Tree,
    Signature = signature(Tree),
    Payload = lists:keydelete(<<"ds:Signature">>, 1, Children),
    Cases = [
        {additional_signature, {Root, Attrs, Children ++ [Signature]}},
        {nested_only, {Root, Attrs, Payload ++ [{<<"wrapper">>, [], [Signature]}]}},
        {nested_extra, add_payload(Tree, {<<"wrapper">>, [], [Signature]})},
        {inside_signature,
            update(Tree, <<"ds:Object">>, fun({N, A, C}) ->
                {N, A, C ++ [{<<"ds:Signature">>, [], []}]}
            end)},
        {root_signature, Signature}
    ],
    lists:foreach(
        fun({Label, Changed}) ->
            assert_public_rejected(Label, xmlan:export([], Changed), Config)
        end,
        Cases
    ).

signing_rejects_existing_signatures(Config) ->
    Tree = ?config(parsed, Config),
    assert_accepted(Tree, Config),
    Signature = signature(Tree),
    lists:foreach(
        fun(Signed) ->
            ?assertError(
                already_signed,
                signerl:sign(
                    xmlan:export(["<?xml version='1.0'?>"], Signed), sha256, ?config(key, Config)
                )
            )
        end,
        [Tree, {<<"wrapper">>, [], [{<<"nested">>, [], [Signature]}]}, Signature]
    ).

signing_avoids_id_collisions(Config) ->
    Raw =
        <<"<?xml version='1.0'?><invoice Id='Signature-1'>",
            "<amount xml:id='SignedProperties-1'>42.00</amount></invoice>">>,
    Signed = signerl:sign(Raw, sha256, ?config(key, Config)),
    test_helpers:parse_verified_message(Signed, ?config(public_key, Config)),
    %% The actual generated identities must be distinct from payload IDs.
    {ok, T} = xmlan:parse_binary(Signed),
    {ok, {_, SigAttrs, _}} = xmlan:find_path([<<"ds:Signature">>], T),
    ?assertNotEqual({ok, ?SIGNATURE_ID}, xmlan:attr_value(<<"Id">>, SigAttrs)),
    Duplicate = <<"<?xml version='1.0'?><invoice Id='same'><amount Id='same'/></invoice>">>,
    ?assertError(
        invalid_signature_structure, signerl:sign(Duplicate, sha256, ?config(key, Config))
    ).

signature_lookalikes_remain_content(Config) ->
    Raw =
        <<"<?xml version='1.0'?><invoice xmlns:ds='urn:application'>",
            "<Signature/><ds:Signature/><nested><ds:Signature/></nested></invoice>">>,
    Signed = signerl:sign(Raw, sha256, ?config(key, Config)),
    Parsed = test_helpers:parse_verified_message(Signed, ?config(public_key, Config)),
    {ok, Original} = xmlan:parse_binary(Raw),
    ?assertEqual(Original, signerl_dsig_utils:remove_signature_elements(Parsed)).

foreach_pair(Config, Cases) ->
    lists:foreach(
        fun(Mode) ->
            Tree = pair(?config(parsed, Config), Mode),
            assert_accepted(Tree, Config),
            lists:foreach(
                fun({Label, Changed}) -> assert_rejected(Label, Changed, Config) end, Cases(Tree)
            )
        end,
        [legacy, explicit]
    ).

assert_accepted(Tree, Config) ->
    Signed = refresh(Tree, Config),
    test_helpers:parse_verified_message(Signed, ?config(public_key, Config)).

assert_rejected(Label, Tree, Config) ->
    ?assertNotEqual(?config(parsed, Config), Tree),
    Signed = refresh(Tree, Config),
    assert_public_rejected(Label, Signed, Config).

assert_public_rejected(Label, Signed, Config) ->
    Result = signerl:verify(Signed, sha256, ?config(public_key, Config)),
    ?assertMatch({Label, {error, _}}, {Label, Result}).

signature(Tree) ->
    {ok, Signature} = xmlan:find_path([?DSIG_NAME(<<"Signature">>)], Tree),
    Signature.

signed_info(Tree) ->
    {ok, SignedInfo} = xmlan:find_path(
        [?DSIG_NAME(<<"Signature">>), ?DSIG_NAME(<<"SignedInfo">>)], Tree
    ),
    SignedInfo.

%% Mutations use xmlan's public tree APIs. Refresh digests and sign SignedInfo
%% directly with OTP, independently of Signerl's validation/extraction code.
refresh(Tree, Config) ->
    {ok, Signature} = xmlan:find_path([<<"ds:Signature">>], Tree),
    {ok, Object} = xmlan:find_path([?DSIG_NAME(<<"Object">>)], Signature),
    {_, _, Qualifiers} = Object,
    Qualifier = hd([E || E = {<<"xades:QualifyingProperties">>, _, _} <- Qualifiers]),
    {_, QAttrs, PropertiesChildren} = Qualifier,
    Properties = hd([E || E = {<<"xades:SignedProperties">>, _, _} <- PropertiesChildren]),
    ContextProperties = xmlan:with_namespace_context(
        Properties,
        xmlan:namespace_context(QAttrs, xmlan:namespace_context(element(2, Signature), #{}))
    ),
    Unsigned = signerl_dsig_utils:remove_signature_elements(Tree),
    DocDigest = base64:encode(crypto:hash(sha256, xmlan_c14n:canonicalize(Unsigned))),
    PropsDigest = base64:encode(crypto:hash(sha256, xmlan_c14n:canonicalize(ContextProperties))),
    WithDigests = update(Tree, <<"ds:Reference">>, fun({_, A, _} = Ref) ->
        Value =
            case xmlan:attr_value(<<"URI">>, A) of
                {ok, ""} -> DocDigest;
                _ -> PropsDigest
            end,
        update(Ref, <<"ds:DigestValue">>, fun({DN, DA, _}) -> {DN, DA, [Value]} end)
    end),
    SI = signed_info(WithDigests),
    {ok, {_, CAttrs, _}} = xmlan:find_path([?DSIG_NAME(<<"CanonicalizationMethod">>)], SI),
    Mode =
        case xmlan:attr_value(<<"Algorithm">>, CAttrs) of
            {ok, ?DSIG_EXC_C14N_ALGO_URI} -> exc_c14n;
            _ -> c14n11
        end,
    Bytes = xmlan_c14n:canonicalize(SI, Mode),
    Value = public_key:sign(Bytes, sha256, ?config(key, Config)),
    %% Prove the cryptographic check succeeds even for each rejected structure.
    ?assertEqual(true, public_key:verify(Bytes, sha256, Value, ?config(public_key, Config))),
    Signed = update(WithDigests, <<"ds:SignatureValue">>, fun({N, A, _}) ->
        {N, A, [base64:encode(Value)]}
    end),
    xmlan:export([], Signed).

pair(Tree, Mode) ->
    [Doc, Props] = references(Tree),
    {DocTransforms, PropsTransforms} =
        case Mode of
            explicit ->
                {[?DSIG_ENVELOPED_SIGNATURE_TRANSFORM_URI, ?DSIG_C14N11_ALGO_URI], [
                    ?DSIG_C14N11_ALGO_URI
                ]};
            legacy ->
                {[?DSIG_ENVELOPED_SIGNATURE_TRANSFORM_URI], absent}
        end,
    set_references(Tree, [
        set_transforms(Doc, DocTransforms), set_transforms(Props, PropsTransforms)
    ]).

references(Tree) ->
    {ok, {_, _, Children}} = xmlan:find_path([<<"ds:Signature">>, <<"ds:SignedInfo">>], Tree),
    [E || E = {<<"ds:Reference">>, _, _} <- Children].

set_references(Tree, Refs) ->
    update(Tree, <<"ds:SignedInfo">>, fun({N, A, C}) ->
        {N, A, [E || E = {Tag, _, _} <- C, Tag =/= <<"ds:Reference">>] ++ Refs}
    end).

set_transforms({N, A, C}, Transforms) ->
    Rest = [E || E = {Tag, _, _} <- C, Tag =/= <<"ds:Transforms">>],
    case Transforms of
        absent ->
            {N, A, Rest};
        _ ->
            {N, A, [
                {<<"ds:Transforms">>, [], [
                    {<<"ds:Transform">>, [{<<"Algorithm">>, T}], []}
                 || T <- Transforms
                ]}
                | Rest
            ]}
    end.

algorithms(Ref) ->
    case xmlan:find_path([?DSIG_NAME(<<"Transforms">>)], Ref) of
        {error, not_found} ->
            absent;
        {ok, Transforms} ->
            [
                A
             || {_, Attrs, _} <- xmlan:find_children(?DSIG_NAME(<<"Transform">>), Transforms),
                {ok, A} <- [xmlan:attr_value(<<"Algorithm">>, Attrs)]
            ]
    end.

rename_ids(Tree) ->
    T1 = update(Tree, <<"ds:Signature">>, fun(E) -> set_attr(E, <<"Id">>, "signature-custom") end),
    T2 = update(T1, <<"xades:QualifyingProperties">>, fun(E) ->
        set_attr(E, <<"Target">>, "#signature-custom")
    end),
    T3 = update(T2, <<"xades:SignedProperties">>, fun(E) ->
        set_attr(E, <<"Id">>, "properties-custom")
    end),
    [Doc, Props] = references(T3),
    set_references(T3, [Doc, set_attr(Props, <<"URI">>, "#properties-custom")]).

duplicate_payload_id(Tree) ->
    Payload = {<<"record">>, [{<<"Id">>, "record-1"}], []},
    add_payload(add_payload(Tree, Payload), Payload).

set_attr({N, A, C}, Name, Value) -> {N, lists:keystore(Name, 1, A, {Name, Value}), C}.
remove_attr({N, A, C}, Name) -> {N, lists:keydelete(Name, 1, A), C}.
add_payload({N, A, C}, Child) -> {N, A, [Child | C]}.
duplicate_child({N, A, C}, Tag) -> {N, A, C ++ [lists:keyfind(Tag, 1, C)]}.

update(Tree, Target, Fun) ->
    update([Tree], [], [], Target, Fun).

update([], [], [Tree], _Target, _Fun) ->
    Tree;
update([], [{Tag, Attrs, Rest, Acc} | Stack], Children, Target, Fun) ->
    Element = {Tag, Attrs, lists:reverse(Children)},
    Updated =
        case Tag of
            Target -> Fun(Element);
            _ -> Element
        end,
    update(Rest, Stack, [Updated | Acc], Target, Fun);
update([{Tag, Attrs, Children} | Rest], Stack, Acc, Target, Fun) ->
    update(Children, [{Tag, Attrs, Rest, Acc} | Stack], [], Target, Fun);
update([Text | Rest], Stack, Acc, Target, Fun) ->
    update(Rest, Stack, [Text | Acc], Target, Fun).
