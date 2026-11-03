-module(signerl_property_policy_SUITE).

-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").
-include("signerl_dsig.hrl").
-compile([export_all, nowarn_export_all]).

suite() -> [{timetrap, {seconds, 30}}].
all() ->
    [
        optional_property_controls,
        property_container_cardinality,
        signature_property_cardinality,
        policy_choice,
        policy_nested_cardinality,
        policy_malformed_fields,
        production_place_cardinality,
        production_place_malformed_fields,
        role_container_cardinality,
        role_malformed_items,
        data_format_cardinality,
        data_format_malformed_fields,
        commitment_cardinality,
        commitment_scope,
        commitment_malformed_fields,
        object_identifier_fields,
        documentation_fields,
        container_text_content,
        unicode_property_values,
        extension_controls
    ].

init_per_suite(Config) ->
    Key = signerl_cert_helpers:signer_rsa_key(),
    Public = signerl_cert_helpers:rsa_public_key_from_cert(
        signerl_cert_helpers:signer_rsa_cert_path()
    ),
    Raw = <<"<?xml version='1.0'?><invoice><amount>42.00</amount></invoice>">>,
    Signed = signerl:sign(Raw, sha256, Key, undefined, <<"2026-10-24T12:00:00Z">>),
    Parsed = test_helpers:parse_verified_message(Signed, Public),
    Initialized = [{key, Key}, {public_key, Public}, {parsed, Parsed} | Config],
    assert_accepted(full_properties(Initialized), Initialized),
    Initialized.

end_per_suite(_Config) -> ok.

optional_property_controls(Config) ->
    assert_accepted(?config(parsed, Config), Config),
    Tree = full_properties(Config),
    assert_accepted(Tree, Config),
    assert_accepted(
        replace_content(Tree, <<"xades:SignaturePolicyIdentifier">>, [
            x(<<"SignaturePolicyImplied">>, [])
        ]),
        Config
    ),
    assert_accepted(
        replace_content(Tree, <<"xades:CommitmentTypeIndication">>, [
            commitment_id(), x(<<"AllSignedDataObjects">>, [])
        ]),
        Config
    ),
    %% These items are repeatable; singleton-container checks must preserve them.
    Repeated = lists:foldl(
        fun({Parent, Child}, Acc) -> duplicate(Acc, Parent, Child) end,
        Tree,
        [
            {<<"xades:ClaimedRoles">>, <<"xades:ClaimedRole">>},
            {<<"xades:CertifiedRoles">>, <<"xades:CertifiedRole">>},
            {<<"xades:SignedDataObjectProperties">>, <<"xades:DataObjectFormat">>},
            {<<"xades:SignedDataObjectProperties">>, <<"xades:CommitmentTypeIndication">>},
            {<<"xades:CommitmentTypeIndication">>, <<"xades:ObjectReference">>}
        ]
    ),
    assert_accepted(Repeated, Config).

property_container_cardinality(Config) ->
    %% One malformed container fails; duplicating it must not make the optional
    %% property look absent and bypass validation.
    Invalid = x(<<"SignedDataObjectProperties">>, [x(<<"DataObjectFormat">>, [])]),
    Base = ?config(parsed, Config),
    assert_rejected(
        single_invalid_container,
        invalid_data_object_format,
        append(Base, <<"xades:SignedProperties">>, [Invalid]),
        Config
    ),
    assert_rejected(
        duplicate_invalid_containers,
        any_error,
        append(Base, <<"xades:SignedProperties">>, [Invalid, Invalid]),
        Config
    ),
    Tree = full_properties(Config),
    lists:foreach(
        fun(Child) ->
            assert_rejected(
                Child, any_error, duplicate(Tree, <<"xades:SignedProperties">>, Child), Config
            )
        end,
        [<<"xades:SignedSignatureProperties">>, <<"xades:SignedDataObjectProperties">>]
    ).

signature_property_cardinality(Config) ->
    Tree = full_properties(Config),
    lists:foreach(
        fun(Child) ->
            assert_rejected(
                Child,
                duplicate_property,
                duplicate(Tree, <<"xades:SignedSignatureProperties">>, Child),
                Config
            )
        end,
        [
            <<"xades:SigningTime">>,
            <<"xades:SignaturePolicyIdentifier">>,
            <<"xades:SignatureProductionPlace">>,
            <<"xades:SignerRole">>
        ]
    ).

policy_choice(Config) ->
    Tree = full_properties(Config),
    Implied = x(<<"SignaturePolicyImplied">>, []),
    lists:foreach(
        fun({Label, Content}) ->
            assert_rejected(
                Label,
                invalid_signature_policy_identifier,
                replace_content(Tree, <<"xades:SignaturePolicyIdentifier">>, Content),
                Config
            )
        end,
        [
            {missing_choice, []},
            {both_choices, [Implied, explicit_policy()]},
            {duplicate_implied, [Implied, Implied]},
            {duplicate_explicit, [explicit_policy(), explicit_policy()]},
            {nonempty_implied, [x(<<"SignaturePolicyImplied">>, ["unexpected"])]}
        ]
    ).

policy_nested_cardinality(Config) ->
    assert_duplicate_fields(
        full_properties(Config),
        invalid_signature_policy_identifier,
        [
            {<<"xades:SignaturePolicyId">>, <<"xades:SigPolicyId">>},
            {<<"xades:SigPolicyId">>, <<"xades:Identifier">>},
            {<<"xades:SigPolicyId">>, <<"xades:Description">>},
            {<<"xades:SignaturePolicyId">>, <<"xades:SigPolicyHash">>},
            {<<"xades:SigPolicyHash">>, <<"ds:DigestMethod">>},
            {<<"xades:SigPolicyHash">>, <<"ds:DigestValue">>}
        ],
        Config
    ).

policy_malformed_fields(Config) ->
    Tree = full_properties(Config),
    lists:foreach(
        fun(Tag) ->
            lists:foreach(
                fun(Content) ->
                    Changed = test_helpers:update_xml(
                        Tree, <<"xades:SignaturePolicyIdentifier">>, fun(E) ->
                            replace_content(E, Tag, Content)
                        end
                    ),
                    assert_rejected(Tag, invalid_signature_policy_identifier, Changed, Config)
                end,
                malformed_contents()
            )
        end,
        [<<"xades:Identifier">>, <<"xades:Description">>, <<"ds:DigestValue">>]
    ),
    lists:foreach(
        fun({Label, Changed}) ->
            assert_rejected(Label, invalid_signature_policy_identifier, Changed, Config)
        end,
        [
            {missing_identifier, remove(Tree, <<"xades:SigPolicyId">>, <<"xades:Identifier">>)},
            {missing_hash, remove(Tree, <<"xades:SignaturePolicyId">>, <<"xades:SigPolicyHash">>)},
            {missing_method, remove(Tree, <<"xades:SigPolicyHash">>, <<"ds:DigestMethod">>)},
            {missing_value, remove(Tree, <<"xades:SigPolicyHash">>, <<"ds:DigestValue">>)},
            {missing_algorithm,
                test_helpers:update_xml(Tree, <<"xades:SigPolicyHash">>, fun(E) ->
                    test_helpers:update_xml(E, <<"ds:DigestMethod">>, fun({N, _, C}) ->
                        {N, [], C}
                    end)
                end)},
            {method_content,
                test_helpers:update_xml(Tree, <<"xades:SigPolicyHash">>, fun(E) ->
                    replace_content(E, <<"ds:DigestMethod">>, ["unexpected"])
                end)},
            {invalid_digest,
                test_helpers:update_xml(Tree, <<"xades:SigPolicyHash">>, fun(E) ->
                    replace_content(E, <<"ds:DigestValue">>, ["!!!invalid!!!"])
                end)}
        ]
    ).

production_place_cardinality(Config) ->
    assert_duplicate_fields(
        full_properties(Config),
        invalid_signature_production_place,
        [
            {<<"xades:SignatureProductionPlace">>, <<"xades:City">>},
            {<<"xades:SignatureProductionPlace">>, <<"xades:StateOrProvince">>},
            {<<"xades:SignatureProductionPlace">>, <<"xades:PostalCode">>},
            {<<"xades:SignatureProductionPlace">>, <<"xades:CountryName">>}
        ],
        Config
    ).

production_place_malformed_fields(Config) ->
    Tree = full_properties(Config),
    assert_accepted(replace_content(Tree, <<"xades:SignatureProductionPlace">>, []), Config),
    assert_malformed_fields(
        Tree,
        invalid_signature_production_place,
        [
            <<"xades:City">>,
            <<"xades:StateOrProvince">>,
            <<"xades:PostalCode">>,
            <<"xades:CountryName">>
        ],
        Config
    ).

role_container_cardinality(Config) ->
    assert_duplicate_fields(
        full_properties(Config),
        invalid_signer_role,
        [
            {<<"xades:SignerRole">>, <<"xades:ClaimedRoles">>},
            {<<"xades:SignerRole">>, <<"xades:CertifiedRoles">>}
        ],
        Config
    ).

role_malformed_items(Config) ->
    Tree = full_properties(Config),
    lists:foreach(
        fun({Container, Item}) ->
            lists:foreach(
                fun(Content) ->
                    Changed = append(Tree, Container, [{Item, [], Content}]),
                    assert_rejected(Item, invalid_signer_role, Changed, Config)
                end,
                malformed_contents()
            ),
            assert_rejected(
                empty_role_container,
                invalid_signer_role,
                replace_content(Tree, Container, []),
                Config
            )
        end,
        [
            {<<"xades:ClaimedRoles">>, <<"xades:ClaimedRole">>},
            {<<"xades:CertifiedRoles">>, <<"xades:CertifiedRole">>}
        ]
    ),
    assert_rejected(
        no_roles,
        invalid_signer_role,
        replace_content(Tree, <<"xades:SignerRole">>, []),
        Config
    ).

data_format_cardinality(Config) ->
    assert_duplicate_fields(
        full_properties(Config),
        invalid_data_object_format,
        [
            {<<"xades:DataObjectFormat">>, <<"xades:MimeType">>},
            {<<"xades:DataObjectFormat">>, <<"xades:Description">>},
            {<<"xades:DataObjectFormat">>, <<"xades:Encoding">>}
        ],
        Config
    ).

data_format_malformed_fields(Config) ->
    Tree = full_properties(Config),
    assert_malformed_fields(
        Tree,
        invalid_data_object_format,
        [
            <<"xades:MimeType">>, <<"xades:Encoding">>
        ],
        Config
    ),
    %% Description is shared by several properties; mutate it only in the format.
    lists:foreach(
        fun(Content) ->
            Changed = test_helpers:update_xml(Tree, <<"xades:DataObjectFormat">>, fun(E) ->
                replace_content(E, <<"xades:Description">>, Content)
            end),
            assert_rejected(description, invalid_data_object_format, Changed, Config)
        end,
        malformed_contents()
    ),
    MissingRef = test_helpers:update_xml(Tree, <<"xades:DataObjectFormat">>, fun({N, _, C}) ->
        {N, [], C}
    end),
    assert_rejected(missing_object_reference, invalid_data_object_format, MissingRef, Config),
    assert_accepted(replace_content(Tree, <<"xades:DataObjectFormat">>, []), Config).

commitment_cardinality(Config) ->
    assert_duplicate_fields(
        full_properties(Config),
        invalid_commitment_type_indication,
        [
            {<<"xades:CommitmentTypeIndication">>, <<"xades:CommitmentTypeId">>},
            {<<"xades:CommitmentTypeId">>, <<"xades:Identifier">>},
            {<<"xades:CommitmentTypeId">>, <<"xades:Description">>}
        ],
        Config
    ).

commitment_scope(Config) ->
    Tree = full_properties(Config),
    All = x(<<"AllSignedDataObjects">>, []),
    Ref = x(<<"ObjectReference">>, ["#invoice"]),
    lists:foreach(
        fun({Label, Scope}) ->
            Changed = replace_content(
                Tree,
                <<"xades:CommitmentTypeIndication">>,
                [commitment_id() | Scope]
            ),
            assert_rejected(Label, invalid_commitment_type_indication, Changed, Config)
        end,
        [
            {missing_scope, []},
            {mixed_scope, [All, Ref]},
            {duplicate_all, [All, All]},
            {nonempty_all, [x(<<"AllSignedDataObjects">>, ["unexpected"])]}
        ]
    ),
    lists:foreach(
        fun(Content) ->
            Changed = append(
                Tree,
                <<"xades:CommitmentTypeIndication">>,
                [x(<<"ObjectReference">>, Content)]
            ),
            assert_rejected(
                malformed_reference, invalid_commitment_type_indication, Changed, Config
            )
        end,
        malformed_contents()
    ).

commitment_malformed_fields(Config) ->
    Tree = full_properties(Config),
    lists:foreach(
        fun(Tag) ->
            lists:foreach(
                fun(Content) ->
                    Changed = test_helpers:update_xml(Tree, <<"xades:CommitmentTypeId">>, fun(E) ->
                        replace_content(E, Tag, Content)
                    end),
                    assert_rejected(Tag, invalid_commitment_type_indication, Changed, Config)
                end,
                malformed_contents()
            )
        end,
        [<<"xades:Identifier">>, <<"xades:Description">>]
    ),
    assert_rejected(
        missing_identifier,
        invalid_commitment_type_indication,
        remove(Tree, <<"xades:CommitmentTypeId">>, <<"xades:Identifier">>),
        Config
    ).

object_identifier_fields(Config) ->
    Tree = full_properties(Config),
    assert_rejected(
        duplicate_object_identifier,
        invalid_data_object_format,
        duplicate(Tree, <<"xades:DataObjectFormat">>, <<"xades:ObjectIdentifier">>),
        Config
    ),
    assert_rejected(
        missing_identifier,
        invalid_data_object_format,
        remove(Tree, <<"xades:ObjectIdentifier">>, <<"xades:Identifier">>),
        Config
    ),
    lists:foreach(
        fun(Tag) ->
            assert_rejected(
                Tag,
                invalid_data_object_format,
                duplicate(Tree, <<"xades:ObjectIdentifier">>, Tag),
                Config
            ),
            lists:foreach(
                fun(Content) ->
                    Changed = test_helpers:update_xml(Tree, <<"xades:ObjectIdentifier">>, fun(E) ->
                        replace_content(E, Tag, Content)
                    end),
                    assert_rejected(Tag, invalid_data_object_format, Changed, Config)
                end,
                malformed_contents()
            )
        end,
        [<<"xades:Identifier">>, <<"xades:Description">>]
    ).

documentation_fields(Config) ->
    Tree = full_properties(Config),
    lists:foreach(
        fun({Parent, Error}) ->
            assert_rejected(
                duplicate_documentation,
                Error,
                duplicate(Tree, Parent, <<"xades:DocumentationReferences">>),
                Config
            ),
            lists:foreach(
                fun(Content) ->
                    Changed = test_helpers:update_xml(Tree, Parent, fun(E) ->
                        replace_content(E, <<"xades:DocumentationReference">>, Content)
                    end),
                    assert_rejected(malformed_documentation, Error, Changed, Config)
                end,
                malformed_contents()
            ),
            assert_rejected(
                empty_documentation_container,
                Error,
                test_helpers:update_xml(Tree, Parent, fun(E) ->
                    replace_content(E, <<"xades:DocumentationReferences">>, [])
                end),
                Config
            ),
            assert_accepted(
                test_helpers:update_xml(Tree, Parent, fun(E) ->
                    duplicate(
                        E, <<"xades:DocumentationReferences">>, <<"xades:DocumentationReference">>
                    )
                end),
                Config
            )
        end,
        [
            {<<"xades:SigPolicyId">>, invalid_signature_policy_identifier},
            {<<"xades:ObjectIdentifier">>, invalid_data_object_format},
            {<<"xades:CommitmentTypeId">>, invalid_commitment_type_indication}
        ]
    ).

container_text_content(Config) ->
    Tree = full_properties(Config),
    lists:foreach(
        fun({Parent, Error}) ->
            lists:foreach(
                fun(Text) ->
                    assert_rejected(Parent, Error, append(Tree, Parent, [Text]), Config)
                end,
                ["unexpected", <<"é"/utf8>>, <<"漢"/utf8>>]
            ),
            assert_accepted(append(Tree, Parent, ["\n  "]), Config)
        end,
        [
            {<<"xades:SignedProperties">>, any_error},
            {<<"xades:SignedSignatureProperties">>, any_error},
            {<<"xades:SignedDataObjectProperties">>, any_error},
            {<<"xades:SignaturePolicyIdentifier">>, invalid_signature_policy_identifier},
            {<<"xades:SignaturePolicyId">>, invalid_signature_policy_identifier},
            {<<"xades:SigPolicyId">>, invalid_signature_policy_identifier},
            {<<"xades:SigPolicyHash">>, invalid_signature_policy_identifier},
            {<<"xades:SignatureProductionPlace">>, invalid_signature_production_place},
            {<<"xades:SignerRole">>, invalid_signer_role},
            {<<"xades:ClaimedRoles">>, invalid_signer_role},
            {<<"xades:CertifiedRoles">>, invalid_signer_role},
            {<<"xades:DataObjectFormat">>, invalid_data_object_format},
            {<<"xades:ObjectIdentifier">>, invalid_data_object_format},
            {<<"xades:CommitmentTypeId">>, invalid_commitment_type_indication},
            {<<"xades:CommitmentTypeIndication">>, invalid_commitment_type_indication}
        ]
    ),
    assert_rejected(
        nested_marker,
        invalid_signature_policy_identifier,
        replace_content(Tree, <<"xades:SignaturePolicyIdentifier">>, [
            x(<<"SignaturePolicyImplied">>, [x(<<"Nested">>, [])])
        ]),
        Config
    ),
    assert_rejected(
        nested_scope_marker,
        invalid_commitment_type_indication,
        replace_content(Tree, <<"xades:CommitmentTypeIndication">>, [
            commitment_id(), x(<<"AllSignedDataObjects">>, [x(<<"Nested">>, [])])
        ]),
        Config
    ).

unicode_property_values(Config) ->
    Tree = lists:foldl(
        fun(Tag, Acc) -> replace_content(Acc, Tag, [<<"東京 é"/utf8>>]) end,
        full_properties(Config),
        [
            <<"xades:City">>,
            <<"xades:Description">>,
            <<"xades:ClaimedRole">>,
            <<"xades:CertifiedRole">>
        ]
    ),
    assert_accepted(Tree, Config).

extension_controls(Config) ->
    %% Unknown extensions and other namespaces must not count as known fields.
    Extension = x(<<"FutureExtension">>, [x(<<"Nested">>, [])]),
    Tree = lists:foldl(
        fun({Parent, Local}, Acc) ->
            Lookalike = {<<"other:", Local/binary>>, [{<<"xmlns:other">>, "urn:other"}], [
                x(<<"Nested">>, [])
            ]},
            append(Acc, Parent, [Extension, Lookalike])
        end,
        full_properties(Config),
        [
            {<<"xades:SignedProperties">>, <<"SignedDataObjectProperties">>},
            {<<"xades:SignedSignatureProperties">>, <<"SignerRole">>},
            {<<"xades:SignaturePolicyIdentifier">>, <<"SignaturePolicyImplied">>},
            {<<"xades:SigPolicyId">>, <<"Identifier">>},
            {<<"xades:SigPolicyHash">>, <<"DigestValue">>},
            {<<"xades:SignatureProductionPlace">>, <<"City">>},
            {<<"xades:SignerRole">>, <<"ClaimedRoles">>},
            {<<"xades:ClaimedRoles">>, <<"ClaimedRole">>},
            {<<"xades:CertifiedRoles">>, <<"CertifiedRole">>},
            {<<"xades:SignedDataObjectProperties">>, <<"DataObjectFormat">>},
            {<<"xades:DataObjectFormat">>, <<"MimeType">>},
            {<<"xades:CommitmentTypeId">>, <<"Identifier">>},
            {<<"xades:CommitmentTypeIndication">>, <<"AllSignedDataObjects">>}
        ]
    ),
    assert_accepted(Tree, Config).

full_properties(Config) ->
    WithSignature = append(?config(parsed, Config), <<"xades:SignedSignatureProperties">>, [
        x(<<"SignaturePolicyIdentifier">>, [explicit_policy()]),
        x(<<"SignatureProductionPlace">>, [
            x(<<"City">>, ["Budapest"]),
            x(<<"StateOrProvince">>, ["Pest"]),
            x(<<"PostalCode">>, ["1011"]),
            x(<<"CountryName">>, ["HU"])
        ]),
        x(<<"SignerRole">>, [
            x(<<"ClaimedRoles">>, [x(<<"ClaimedRole">>, ["author"])]),
            x(<<"CertifiedRoles">>, [x(<<"CertifiedRole">>, ["auditor"])])
        ])
    ]),
    append(WithSignature, <<"xades:SignedProperties">>, [
        x(<<"SignedDataObjectProperties">>, [
            {<<"xades:DataObjectFormat">>, [{<<"ObjectReference">>, "#invoice"}], [
                x(<<"MimeType">>, ["text/xml"]),
                x(<<"Description">>, ["invoice"]),
                x(<<"ObjectIdentifier">>, identifier_content("urn:format", "XML invoice")),
                x(<<"Encoding">>, ["urn:encoding"])
            ]},
            x(<<"CommitmentTypeIndication">>, [
                commitment_id(), x(<<"ObjectReference">>, ["#invoice"])
            ])
        ])
    ]).

explicit_policy() ->
    x(<<"SignaturePolicyId">>, [
        x(<<"SigPolicyId">>, identifier_content("urn:policy", "policy")),
        x(<<"SigPolicyHash">>, [
            {<<"ds:DigestMethod">>, [{<<"Algorithm">>, ?DSIG_DIGEST_SHA256_URI}], []},
            {<<"ds:DigestValue">>, [], ["AQID"]}
        ])
    ]).

commitment_id() ->
    x(<<"CommitmentTypeId">>, identifier_content("urn:commitment", "approval")).

identifier_content(Identifier, Description) ->
    [
        x(<<"Identifier">>, [Identifier]),
        x(<<"Description">>, [Description]),
        x(<<"DocumentationReferences">>, [x(<<"DocumentationReference">>, ["urn:documentation"])])
    ].

x(Name, Content) -> {<<"xades:", Name/binary>>, [], Content}.

append(Tree, Parent, Extra) ->
    test_helpers:update_xml(Tree, Parent, fun({N, A, C}) -> {N, A, C ++ Extra} end).

replace_content(Tree, Tag, Content) ->
    test_helpers:update_xml(Tree, Tag, fun({N, A, _}) -> {N, A, Content} end).

duplicate(Tree, Parent, Child) ->
    test_helpers:update_xml(Tree, Parent, fun({N, A, C}) ->
        [Element] = [E || E = {Tag, _, _} <- C, Tag =:= Child],
        {N, A, C ++ [Element]}
    end).

remove(Tree, Parent, Child) ->
    test_helpers:update_xml(Tree, Parent, fun({N, A, C}) ->
        {N, A, [E || E <- C, not is_child(Child, E)]}
    end).

is_child(Tag, {Tag, _, _}) -> true;
is_child(_, _) -> false.

malformed_contents() -> [[], [x(<<"Nested">>, [])], ["text", x(<<"Nested">>, [])]].

assert_duplicate_fields(Tree, Error, Fields, Config) ->
    lists:foreach(
        fun({Parent, Child}) ->
            assert_rejected(Child, Error, duplicate(Tree, Parent, Child), Config)
        end,
        Fields
    ).

assert_malformed_fields(Tree, Error, Tags, Config) ->
    lists:foreach(
        fun(Tag) ->
            lists:foreach(
                fun(Content) ->
                    assert_rejected(Tag, Error, replace_content(Tree, Tag, Content), Config)
                end,
                malformed_contents()
            )
        end,
        Tags
    ).

assert_accepted(Tree, Config) ->
    Signed = test_helpers:refresh_signature(Tree, Config),
    ?assertEqual(true, signerl:verify(Signed, sha256, ?config(public_key, Config))).

assert_rejected(Label, Expected, Tree, Config) ->
    Signed = test_helpers:refresh_signature(Tree, Config),
    Result = signerl:verify(Signed, sha256, ?config(public_key, Config)),
    case Expected of
        any_error -> ?assertMatch({Label, {error, _}}, {Label, Result});
        _ -> ?assertEqual({Label, {error, Expected}}, {Label, Result})
    end.
