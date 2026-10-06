-module(signerl_xml_SUITE).

-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").
-compile([export_all, nowarn_export_all]).

suite() ->
    [{timetrap, {seconds, 30}}].

all() ->
    [
        to_file_writes_and_reads_back,
        utf8_file_roundtrip,
        reject_non_utf8_file,
        missing_file_raises,
        file_and_binary_preserve_content,
        file_rejects_processing_instruction
    ].

to_file_writes_and_reads_back(Config) ->
    PrivDir = ?config(priv_dir, Config),
    OutPath = filename:join(PrivDir, "to_file_test.xml"),
    Prolog = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"],
    Root = signerl_xml:parse_file(signerl_utils:file_path("test/examples/base/books.xml")),
    ?assertMatch({library, [{id, "112233"}], ["\n    ", {book, _, _} | _]}, Root),
    Binary = signerl_xml:export(Prolog, Root),
    ok = signerl_xml:to_file(OutPath, Binary),
    ReadBack = signerl_xml:parse_file(OutPath),
    ?assertEqual(Root, ReadBack).

utf8_file_roundtrip(Config) ->
    Root = {root, [{value, "café ő 東京 😀"}], ["café ő 東京 😀"]},
    Binary = signerl_xml:export(["<?xml version='1.0' encoding='UTF-8'?>"], Root),
    Path = filename:join(?config(priv_dir, Config), "utf8.xml"),
    ok = signerl_xml:to_file(Path, Binary),
    ?assertEqual(Root, signerl_xml:parse_file(Path)).

reject_non_utf8_file(Config) ->
    Path = filename:join(?config(priv_dir, Config), "latin1.xml"),
    ok = file:write_file(Path, <<"<?xml version='1.0' encoding='ISO-8859-1'?><root/>">>),
    ?assertException(error, _, signerl_xml:parse_file(Path)).

missing_file_raises(Config) ->
    Path = filename:join(?config(priv_dir, Config), "missing.xml"),
    ?assertException(error, _, signerl_xml:parse_file(Path)).

file_and_binary_preserve_content(_Config) ->
    Path = signerl_utils:file_path("test/examples/c14n/preserved_content.xml"),
    {ok, Raw} = file:read_file(Path),
    {ok, Xml} = signerl_xml:parse_binary(Raw),
    ?assertEqual(Xml, signerl_xml:parse_file(Path)).

file_rejects_processing_instruction(Config) ->
    Path = filename:join(?config(priv_dir, Config), "instruction.xml"),
    ok = file:write_file(Path, <<"<root><?report preserved?></root>">>),
    ?assertException(error, _, signerl_xml:parse_file(Path)).
