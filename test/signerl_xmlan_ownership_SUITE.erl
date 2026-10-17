-module(signerl_xmlan_ownership_SUITE).

-include_lib("stdlib/include/assert.hrl").
-include("xmlan_audit.hrl").
-compile([export_all, nowarn_export_all]).

all() -> [compatibility_owns_no_engine, compiled_calls_use_public_dependency].

compatibility_owns_no_engine(_Config) ->
    Xml = source_forms(signerl_xml),
    C14n = source_forms(signerl_c14n),
    assert_delegates(Xml, xmlan, ?XMLAN_GENERIC, [
        {is_signature_element, 1}, {is_signature_element, 2}
    ]),
    assert_delegates(C14n, xmlan_c14n, [{canonicalize, 1}, {canonicalize, 2}], [
        {remove_signature_elements, 1}
    ]),
    assert_aliases(Xml, xmlan, ?XMLAN_ALIASES),
    assert_aliases(C14n, xmlan_c14n, [c14n_mode]),
    Header = filename:join([code:lib_dir(signerl), "include", "signerl_xml.hrl"]),
    {ok, Bytes} = file:read_file(Header),
    Statements = [
        string:trim(hd(string:split(Line, "%")))
     || Line <- string:split(binary_to_list(Bytes), "\n", all)
    ],
    ?assertEqual(["-include_lib(\"xmlan/include/xmlan.hrl\")."], [S || S <- Statements, S =/= ""]).

source_forms(Module) ->
    Root = code:lib_dir(signerl),
    {ok, Forms} = epp:parse_file(
        filename:join([Root, "src", atom_to_list(Module) ++ ".erl"]),
        [filename:join(Root, "include")],
        []
    ),
    ?assertEqual([], [E || {error, E} <- Forms]),
    [erl_parse:map_anno(fun(_) -> 0 end, Form) || Form <- Forms].

assert_delegates(Forms, Target, Generic, Local) ->
    Functions = [{F, A} || {function, _, F, A, _} <- Forms],
    ?assertEqual(lists:sort(Generic ++ Local), lists:sort(Functions)),
    lists:foreach(
        fun({F, A}) ->
            [{function, 0, F, A, [{clause, 0, Args, [], [Body]}]}] =
                [Form || {function, _, Name, Arity, _} = Form <- Forms, {Name, Arity} =:= {F, A}],
            ?assertEqual(A, length([V || {var, _, _} = V <- Args])),
            ?assertEqual({call, 0, {remote, 0, {atom, 0, Target}, {atom, 0, F}}, Args}, Body)
        end,
        Generic
    ).

assert_aliases(Forms, Target, Names) ->
    Actual = [{Name, Type} || {attribute, _, type, {Name, Type, []}} <- Forms],
    Expected = [
        {Name, {remote_type, 0, [{atom, 0, Target}, {atom, 0, Name}, []]}}
     || Name <- Names
    ],
    ?assertEqual(lists:sort(Expected), lists:sort(Actual)),
    ?assertEqual([], [Name || {attribute, _, opaque, {Name, _, _}} <- Forms]),
    ?assertEqual(
        lists:sort([{Name, 0} || Name <- Names]),
        lists:sort(lists:append([Types || {attribute, _, export_type, Types} <- Forms]))
    ).

compiled_calls_use_public_dependency(_Config) ->
    ?assertMatch({ok, _}, application:ensure_all_started(signerl)),
    {ok, Apps} = application:get_key(signerl, applications),
    ?assert(lists:member(xmlan, Apps)),
    ?assertNot(lists:member(xmerl, Apps)),
    {ok, XmlApps} = application:get_key(xmlan, applications),
    ?assert(lists:member(xmerl, XmlApps)),
    ?assertNot(lists:member(signerl, XmlApps)),
    {ok, XmlConfig} = file:consult(filename:join(code:lib_dir(xmlan), "rebar.config")),
    ?assertEqual([], proplists:get_value(deps, XmlConfig)),
    assert_pin(),
    Signerl = beam_info(signerl),
    Xmlan = beam_info(xmlan),
    lists:foreach(
        fun({Module, Imports, _}) ->
            lists:foreach(fun(Import) -> assert_import(Import, Xmlan) end, Imports),
            ct:log("~p imports ~p", [Module, Imports])
        end,
        Signerl
    ),
    lists:foreach(
        fun({_, Imports, _}) ->
            ?assertEqual([], [M || {M, _, _} <- Imports, lists:prefix("signerl", atom_to_list(M))])
        end,
        Xmlan
    ).

assert_pin() ->
    Root = project_root(code:lib_dir(signerl)),
    {ok, Config} = file:consult(filename:join(Root, "rebar.config")),
    [{xmlan, {git, Url, {ref, Ref}}}] = proplists:get_value(deps, Config),
    ?assertEqual("https://github.com/bormilan/xmlan.git", Url),
    ?assertEqual(40, length(Ref)),
    ?assert(
        lists:all(fun(C) -> (C >= $0 andalso C =< $9) orelse (C >= $a andalso C =< $f) end, Ref)
    ),
    {ok, [Lock]} = file:consult(filename:join(Root, "rebar.lock")),
    ?assertEqual([{<<"xmlan">>, {git, Url, {ref, Ref}}, 0}], Lock).

project_root(Dir) ->
    case filelib:is_regular(filename:join(Dir, "rebar.config")) of
        true ->
            Dir;
        false ->
            Parent = filename:dirname(Dir),
            ?assertNotEqual(Dir, Parent),
            project_root(Parent)
    end.

beam_info(App) ->
    Paths = filelib:wildcard(filename:join([code:lib_dir(App), "ebin", "*.beam"])),
    ?assertNotEqual([], Paths),
    [beam_data(Path) || Path <- Paths].

beam_data(Path) ->
    {ok, {M, Chunks}} = beam_lib:chunks(Path, [imports, exports]),
    {M, proplists:get_value(imports, Chunks), proplists:get_value(exports, Chunks)}.

assert_import({M, F, A}, Xmlan) when M =:= xmlan; M =:= xmlan_c14n ->
    {M, _, Exports} = lists:keyfind(M, 1, Xmlan),
    ?assert(lists:member({F, A}, Exports));
assert_import({signerl_xml, F, A}, _) ->
    ?assert(lists:member({F, A}, [{is_signature_element, 1}, {is_signature_element, 2}]));
assert_import({signerl_c14n, F, A}, _) ->
    ?assertEqual({remove_signature_elements, 1}, {F, A});
assert_import({M, F, A}, _) ->
    ?assertNot(lists:prefix("xmerl", atom_to_list(M))),
    ?assertNot(lists:member({M, F, A}, [{erlang, apply, 2}, {erlang, apply, 3}])).
