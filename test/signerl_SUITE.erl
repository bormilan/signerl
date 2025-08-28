-module(signerl_SUITE).

-include_lib("eunit/include/eunit.hrl").

-export([
    suite/0,
    init_per_suite/1,
    end_per_suite/1,
    init_per_group/2,
    init_per_testcase/2,
    end_per_testcase/2,
    end_per_group/2,
    groups/0,
    all/0
]).

-export([
    add_signature_element_success/1,
    sign_success/1
]).

suite() ->
    [{timetrap, {seconds, 30}}].

init_per_suite(Config) ->
    Config.
end_per_suite(_Config) ->
    ok.
init_per_testcase(_TestCase, Config) ->
    Config.
end_per_testcase(_TestCase, _Config) ->
    ok.

%%%%%%%%%%%%%%%%%%%%%%%
%%% GROUPS
%%%%%%%%%%%%%%%%%%%%%%%

groups() ->
    [
        {sign_group, [], [
            add_signature_element_success,
            sign_success
        ]}
    ].

all() ->
    [{group, sign_group}].

%%%%%%%%%%%%%%%%%%%%%%%
%%% TEST CASES
%%%%%%%%%%%%%%%%%%%%%%%
init_per_group(sign_group, Config) ->
    Config;
init_per_group(_, Config) ->
    Config.
end_per_group(sign_group, _Config) ->
    ok;
end_per_group(_, _Config) ->
    ok.

add_signature_element_success(_Config) ->
    Path = "/Users/milanbor/projects/signerl/test/examples/books.xml",
    Message = signerl_xml:parse_file(Path),
    {_, _, SignedMessageContent} = signerl_signature:add_signature_element(Message),
    ?assertEqual(
        true,
        lists:member({'ds:Signature', [], []}, SignedMessageContent)
    ).

sign_success(_Config) ->
    Path = "/Users/milanbor/projects/signerl/test/examples/books.xml",
    Message = signerl_xml:parse_file(Path),
    Prolog = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"],
    SignableMessage = signerl_xml:export(Prolog, Message),
    Digest = signerl:sign(SignableMessage),
    true = signerl:verify(SignableMessage, Digest).
