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

-export([sign_success/1]).

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
    [{sign_group, [], [sign_success]}].

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

sign_success(_Config) ->
    % TODO: fix file read
    Path = "/Users/milanbor/projects/signerl/test/examples/books.xml",
    Message = signerl_xml:parse_file(Path),
    SignedMessage = signerl:add_signature_element(Message),
    ?assertEqual(
        true,
        signerl:validate(SignedMessage)
    ),

    Prolog = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"],
    SignableMessage = signerl_xml:export(Prolog, Message),
    Digest = signerl:sign(SignableMessage),
    true = signerl:verify(SignableMessage, Digest).
