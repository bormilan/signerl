-module(signerl_xml_SUITE).

-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").
-compile([export_all, nowarn_export_all]).

suite() ->
    [{timetrap, {seconds, 30}}].

all() ->
    [to_file_writes_and_reads_back].

to_file_writes_and_reads_back(Config) ->
    PrivDir = ?config(priv_dir, Config),
    OutPath = filename:join(PrivDir, "to_file_test.xml"),
    Prolog = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"],
    Root = signerl_xml:parse_file("test/examples/base/books.xml"),
    Binary = signerl_xml:export(Prolog, Root),
    ok = signerl_xml:to_file(OutPath, Binary),
    ReadBack = signerl_xml:parse_file(OutPath),
    ?assertEqual(Root, ReadBack).
