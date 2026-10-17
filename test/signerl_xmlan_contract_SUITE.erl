-module(signerl_xmlan_contract_SUITE).

-include_lib("stdlib/include/assert.hrl").
-include_lib("signerl/include/signerl_xml.hrl").
-include_lib("public_key/include/public_key.hrl").

-compile([export_all, nowarn_export_all]).

all() ->
    [
        baseline_public_contract,
        invalid_canonicalization_mode,
        dependency_application_startup,
        compatibility_file_output
    ].

baseline_public_contract(_Config) ->
    Dir = signerl_utils:file_path("test/examples/xmlan_migration"),
    check_xml(Dir),
    check_helpers(),
    check_aliases(),
    check_failures(Dir),
    check_signature(Dir).

invalid_canonicalization_mode(_Config) ->
    ?assertException(
        error, function_clause, signerl_c14n:canonicalize({<<"root">>, [], []}, unsupported)
    ).

dependency_application_startup(_Config) ->
    ?assertMatch({ok, _}, application:ensure_all_started(signerl)),
    {ok, Applications} = application:get_key(signerl, applications),
    ?assert(lists:member(xmlan, Applications)),
    ?assertNot(lists:member(xmerl, Applications)),
    {ok, Peer, _} = peer:start_link(#{
        connection => standard_io,
        args => [
            "+S",
            "2:2",
            "-enable-feature",
            "maybe_expr",
            "-pa",
            filename:join(code:lib_dir(signerl), "ebin"),
            filename:join(code:lib_dir(xmlan), "ebin")
        ]
    }),
    try
        {ok, Started} = peer:call(Peer, application, ensure_all_started, [signerl]),
        ?assert(lists:member(xmlan, Started)),
        ?assert(lists:member(xmerl, Started))
    after
        peer:stop(Peer)
    end.

compatibility_file_output(Config) ->
    Dir = signerl_utils:file_path("test/examples/xmlan_migration"),
    {ok, Bytes} = file:read_file(filename:join(Dir, "input.xml")),
    Path = filename:join(proplists:get_value(priv_dir, Config), "compatibility.xml"),
    ok = signerl_xml:to_file(Path, Bytes),
    Expected = check_parsed_input(Dir, Bytes),
    ?assertEqual(Expected, signerl_xml:parse_file(Path)),
    Missing = filename:join([proplists:get_value(priv_dir, Config), "absent", "output.xml"]),
    ?assertEqual({error, enoent}, signerl_xml:to_file(Missing, Bytes)).

check_xml(Dir) ->
    Input = read(Dir, "input.xml"),
    ExpectedTree = check_parsed_input(Dir, Input),
    ?assertEqual(ExpectedTree, signerl_xml:parse_file(filename:join(Dir, "input.xml"))),
    Prolog = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"],
    ?assertEqual({ok, Prolog}, signerl_xml:parse_prolog(Input)),
    ?assertEqual(read(Dir, "export.xml"), signerl_xml:export(Prolog, ExpectedTree)),
    ?assertEqual(read(Dir, "fragment.xml"), signerl_xml:export_fragment(ExpectedTree)),
    ?assertEqual(read(Dir, "c14n11.xml"), signerl_c14n:canonicalize(ExpectedTree)),
    ?assertEqual(read(Dir, "c14n11.xml"), signerl_c14n:canonicalize(ExpectedTree, c14n11)),
    ?assertEqual(read(Dir, "exclusive.xml"), signerl_c14n:canonicalize(ExpectedTree, exc_c14n)),
    [Item] = signerl_xml:find_children({<<"urn:items">>, <<"item">>}, ExpectedTree),
    ?assertEqual({ok, Item}, signerl_xml:find_path([{<<"urn:items">>, <<"item">>}], ExpectedTree)),
    ?assertEqual({<<"urn:items">>, <<"item">>}, signerl_xml:expanded_name(Item, #{})),
    Context = signerl_xml:namespace_context(element(2, ExpectedTree), #{}),
    ?assertEqual(<<"urn:invoice">>, maps:get(<<>>, Context)),
    ?assertEqual(Item, signerl_xml:with_namespace_context(Item, Context)),
    ?assertMatch(
        {{<<"urn:invoice">>, <<"invoice">>}, _, _}, signerl_xml:expanded_names(ExpectedTree)
    ).

check_parsed_input(Dir, Input) ->
    {ok, [Expected]} = file:consult(filename:join(Dir, "parsed.term")),
    ?assertEqual({ok, Expected}, signerl_xml:parse_binary(Input)),
    Expected.

check_helpers() ->
    Tree = constructed_tree(),
    Attrs = element(2, Tree),
    ?assertEqual({ok, <<"café"/utf8>>}, signerl_xml:attr_value(<<"label">>, Attrs)),
    ?assertEqual(-42, signerl_xml:attr_value_or_undefined(<<"count">>, Attrs)),
    ?assertEqual({ok, hello}, signerl_xml:attr_value(<<"kind">>, Attrs)),
    {ok, Child} = signerl_xml:find_path([<<"child">>], Tree),
    ?assertEqual({ok, <<"árvíz"/utf8>>}, signerl_xml:single_text(Child)),
    Empty = {<<"empty">>, [], []},
    ?assertEqual([Child, Empty], element(3, signerl_xml:add_new_element(Empty, Tree))),
    ?assertEqual(
        {error, not_found}, signerl_xml:find_path([<<"child">>], {<<"root">>, [], [Child, Child]})
    ),
    Signature =
        {<<"sig:Signature">>, [{<<"xmlns:sig">>, "http://www.w3.org/2000/09/xmldsig#"}], []},
    ?assert(signerl_xml:is_signature_element(Signature)),
    ?assert(
        signerl_xml:is_signature_element(
            {<<"sig:Signature">>, [], []},
            #{<<"sig">> => <<"http://www.w3.org/2000/09/xmldsig#">>}
        )
    ),
    ?assertEqual(
        Tree, signerl_c14n:remove_signature_elements(signerl_xml:add_new_element(Signature, Tree))
    ).

-spec constructed_tree() -> signerl_xml:simplified_xml().
constructed_tree() ->
    {<<"root">>, [{<<"label">>, <<"café"/utf8>>}, {<<"count">>, -42}, {<<"kind">>, hello}], [
        {<<"child">>, [], ["árvíz"]}
    ]}.

check_failures(Dir) ->
    BadInputs = [
        <<"<!DOCTYPE root><root/>">>,
        <<"<root><?report no?></root>">>,
        <<"<root/><other/>">>,
        <<"<p:root/>">>,
        <<"<root xmlns='relative'/>">>,
        <<"<root xmlns:='urn:bad'/>">>,
        <<"<root>", 255, "</root>">>,
        <<"<?xml version='1.0' encoding='ISO-8859-1'?><root/>">>
    ],
    lists:foreach(
        fun(Input) ->
            ?assertEqual({error, invalid_xml}, signerl_xml:parse_binary(Input))
        end,
        BadInputs
    ),
    ?assertEqual({error, invalid_prolog}, signerl_xml:parse_prolog(<<"<root/>">>)),
    ?assertEqual({error, missing_attribute}, signerl_xml:attr_value(<<"missing">>, [])),
    ?assertEqual(undefined, signerl_xml:attr_value_or_undefined(<<"missing">>, [])),
    ?assertEqual({error, not_found}, signerl_xml:single_text({<<"root">>, [], []})),
    Missing = filename:join(Dir, "does-not-exist.xml"),
    ?assertException(error, {badmatch, {error, enoent}}, signerl_xml:parse_file(Missing)),
    ?assertEqual(
        {error, {file_error, enoent}},
        signerl:sign(Missing, sha256, filename:join(Dir, "rsa-public.pem"))
    ),
    ?assertEqual(
        {error, {file_error, enoent}},
        signerl:verify(Missing, sha256, filename:join(Dir, "rsa-public.pem"))
    ).

check_signature(Dir) ->
    [PublicEntry] = public_key:pem_decode(read(Dir, "rsa-public.pem")),
    FrozenPublicKey = public_key:pem_entry_decode(PublicEntry),
    Expected = read(Dir, "signed-rsa.xml"),
    ?assertEqual(true, signerl:verify(Expected, sha256, FrozenPublicKey)),
    Key = public_key:generate_key({rsa, 2048, 65537}),
    PublicKey = #'RSAPublicKey'{
        modulus = Key#'RSAPrivateKey'.modulus,
        publicExponent = Key#'RSAPrivateKey'.publicExponent
    },
    Input = read(Dir, "input.xml"),
    Time = <<"2026-10-13T12:34:56Z">>,
    Signed = signerl:sign(Input, sha256, Key, undefined, Time),
    ?assertEqual(Signed, signerl:sign(Input, sha256, Key, undefined, Time)),
    ?assertEqual(Expected, replace_signature_value(Signed, signature_value(Expected))),
    ?assertEqual(true, signerl:verify(Signed, sha256, PublicKey)),
    Tampered = binary:replace(Signed, <<"before">>, <<"BEFORE">>),
    ?assertNotEqual(Signed, Tampered),
    ?assertEqual(false, signerl:verify(Tampered, sha256, PublicKey)),
    ?assertEqual({error, invalid_prolog}, signerl:sign(<<"<root/>">>, sha256, Key)),
    ?assertEqual(
        {error, invalid_xml},
        signerl:sign(<<"<?xml version='1.0'?><root/><other/>">>, sha256, Key)
    ),
    ?assertEqual(
        {error, invalid_xml}, signerl:verify(<<Signed/binary, "<other/>">>, sha256, PublicKey)
    ),
    ok.

signature_value(Signed) ->
    {ok, Tree} = signerl_xml:parse_binary(Signed),
    Uri = <<"http://www.w3.org/2000/09/xmldsig#">>,
    {ok, Element} = signerl_xml:find_path(
        [{Uri, <<"Signature">>}, {Uri, <<"SignatureValue">>}], Tree
    ),
    {ok, Value} = signerl_xml:single_text(Element),
    Value.

replace_signature_value(Signed, ExpectedValue) ->
    Value = signature_value(Signed),
    ?assertMatch([_], binary:matches(Signed, Value)),
    binary:replace(Signed, Value, ExpectedValue).

read(Dir, Name) ->
    {ok, Bytes} = file:read_file(filename:join(Dir, Name)),
    Bytes.

-spec alias_values() ->
    {
        signerl_xml:attribute_value(),
        signerl_xml:expanded_name(),
        signerl_xml:expanded_xml(),
        signerl_xml:namespace_context(),
        signerl_c14n:c14n_mode()
    }.
alias_values() ->
    Value = <<"café"/utf8>>,
    Name = {<<"urn:alias">>, <<"root">>},
    {Value, Name, {Name, [{<<"label">>, Value}], [Value]}, #{<<"p">> => <<"urn:alias">>}, exc_c14n}.

check_aliases() ->
    {Value, Name, Expanded, Context, Mode} = alias_values(),
    Tree = {<<"p:root">>, [{<<"label">>, Value}], [Value]},
    WithContext = signerl_xml:with_namespace_context(Tree, Context),
    ?assertEqual(Name, signerl_xml:expanded_name(Tree, Context)),
    {ExpandedName, _, [Value]} = Expanded,
    ?assertEqual(Name, ExpandedName),
    ?assertMatch({{<<"urn:alias">>, <<"root">>}, _, _}, signerl_xml:expanded_names(WithContext)),
    ?assertEqual(?XML_NAMESPACE_URI, maps:get(<<"xml">>, signerl_xml:namespace_context([], #{}))),
    ?assertEqual(
        <<"<p:root xmlns:p=\"urn:alias\" label=\"café\">café</p:root>"/utf8>>,
        signerl_c14n:canonicalize(WithContext, Mode)
    ).
