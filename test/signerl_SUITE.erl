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
    add_signature_element/1,
    sign/1,
    sign_from_file/1
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
            add_signature_element,
            sign,
            sign_from_file
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

add_signature_element(_Config) ->
    Path = "test/examples/books.xml",
    Message = signerl_xml:parse_file(Path),
    {_, _, SignedMessageContent} = signerl_signature:add_signature_element(Message),
    ?assertEqual(
        true,
        lists:member({'ds:Signature', [], []}, SignedMessageContent)
    ).

sign_from_file(_) ->
    KeyPath = signerl_utils:file_path("priv/key.pem"),
    MessagePath = signerl_utils:file_path("test/examples/books.xml"),

    Digest = signerl:sign(MessagePath, sha256, KeyPath),
    ?assertEqual(true, signerl:verify(MessagePath, sha256, Digest, KeyPath)).

sign(_Config) ->
    {ok, KeyRaw} = file:read_file(signerl_utils:file_path("priv/key.pem")),
    [KeyDer] = public_key:pem_decode(KeyRaw),
    Key = public_key:pem_entry_decode(KeyDer),

    Path = "/Users/milanbor/projects/signerl/test/examples/books.xml",
    Message = signerl_xml:parse_file(Path),

    Digest = signerl:sign(Message, sha256, Key),
    ?assertEqual(true, signerl:verify(Message, sha256, Digest, Key)).
