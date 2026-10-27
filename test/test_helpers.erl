-module(test_helpers).

-export([
    signature_element/1,
    signature_element/2,
    parse_verified_message/2,
    replace_once/3,
    update_xml/3,
    refresh_signature/2
]).

-include_lib("eunit/include/eunit.hrl").
-include("signerl_dsig.hrl").

%% Minimal extraction fixtures, not cryptographically valid signatures.
signature_element(SignedSignaturePropertiesElements) ->
    signature_with_properties([
        {<<"xades:SignedSignatureProperties">>, [], SignedSignaturePropertiesElements}
    ]).

signature_element(SignedSignaturePropertiesElements, SignedDataObjectPropertiesElements) ->
    signature_with_properties([
        {<<"xades:SignedSignatureProperties">>, [], SignedSignaturePropertiesElements},
        {<<"xades:SignedDataObjectProperties">>, [], SignedDataObjectPropertiesElements}
    ]).

signature_with_properties(Properties) ->
    {<<"ds:Signature">>,
        [{<<"xmlns:ds">>, ?DSIG_NAMESPACE_URI}, {<<"xmlns:xades">>, ?XADES_NAMESPACE_URI}], [
            {<<"ds:SignatureValue">>, [], ["AQID"]},
            {<<"ds:Object">>, [], [
                {<<"xades:QualifyingProperties">>, [], [
                    {<<"xades:SignedProperties">>, [], Properties}
                ]}
            ]}
        ]}.

parse_verified_message(SignedMessage, PublicKey) ->
    ?assertEqual(true, signerl:verify(SignedMessage, sha256, PublicKey)),
    {ok, Parsed} = xmlan:parse_binary(SignedMessage),
    %% Verification accepts XML without a declaration, as do the reconstruction tests.
    Rebuilt = xmlan:export([], Parsed),
    ?assertEqual(true, signerl:verify(Rebuilt, sha256, PublicKey)),
    Parsed.

replace_once(Message, Before, After) ->
    ?assertMatch([_], binary:matches(Message, Before)),
    Replaced = binary:replace(Message, Before, After),
    ?assertNotEqual(Message, Replaced),
    Replaced.

%% Mutations use xmlan's public tree APIs. Refresh digests and sign SignedInfo
%% directly with OTP, independently of Signerl's validation/extraction code.
refresh_signature(Tree, Config) ->
    Key = proplists:get_value(key, Config),
    PublicKey = proplists:get_value(public_key, Config),
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
    WithDigests = update_xml(Tree, <<"ds:Reference">>, fun({_, A, _} = Ref) ->
        Value =
            case xmlan:attr_value(<<"URI">>, A) of
                {ok, ""} -> DocDigest;
                _ -> PropsDigest
            end,
        update_xml(Ref, <<"ds:DigestValue">>, fun({DN, DA, _}) -> {DN, DA, [Value]} end)
    end),
    {ok, SI} = xmlan:find_path(
        [?DSIG_NAME(<<"Signature">>), ?DSIG_NAME(<<"SignedInfo">>)], WithDigests
    ),
    {ok, {_, CAttrs, _}} = xmlan:find_path([?DSIG_NAME(<<"CanonicalizationMethod">>)], SI),
    Mode =
        case xmlan:attr_value(<<"Algorithm">>, CAttrs) of
            {ok, ?DSIG_EXC_C14N_ALGO_URI} -> exc_c14n;
            _ -> c14n11
        end,
    Bytes = xmlan_c14n:canonicalize(SI, Mode),
    Value = public_key:sign(Bytes, sha256, Key),
    %% Prove the cryptographic check succeeds even for each rejected structure.
    ?assertEqual(true, public_key:verify(Bytes, sha256, Value, PublicKey)),
    Signed = update_xml(WithDigests, <<"ds:SignatureValue">>, fun({N, A, _}) ->
        {N, A, [base64:encode(Value)]}
    end),
    xmlan:export([], Signed).

update_xml(Tree, Target, Fun) ->
    update_xml([Tree], [], [], Target, Fun).

update_xml([], [], [Tree], _Target, _Fun) ->
    Tree;
update_xml([], [{Tag, Attrs, Rest, Acc} | Stack], Children, Target, Fun) ->
    Element = {Tag, Attrs, lists:reverse(Children)},
    Updated =
        case Tag of
            Target -> Fun(Element);
            _ -> Element
        end,
    update_xml(Rest, Stack, [Updated | Acc], Target, Fun);
update_xml([{Tag, Attrs, Children} | Rest], Stack, Acc, Target, Fun) ->
    update_xml(Children, [{Tag, Attrs, Rest, Acc} | Stack], [], Target, Fun);
update_xml([Text | Rest], Stack, Acc, Target, Fun) ->
    update_xml(Rest, Stack, [Text | Acc], Target, Fun).
