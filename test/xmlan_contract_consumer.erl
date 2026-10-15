-module(xmlan_contract_consumer).

-include_lib("stdlib/include/assert.hrl").
-include_lib("public_key/include/public_key.hrl").

-export([run/1]).

-spec run(string()) -> ok.
run(Dir) ->
    check_xml(Dir),
    check_helpers(),
    check_failures(Dir),
    check_signature(Dir).

check_xml(Dir) ->
    Input = read(Dir, "input.xml"),
    {ok, [ExpectedTree]} = file:consult(filename:join(Dir, "parsed.term")),
    ?assertEqual({ok, ExpectedTree}, signerl_xml:parse_binary(Input)),
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
