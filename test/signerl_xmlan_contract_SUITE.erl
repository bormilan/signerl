-module(signerl_xmlan_contract_SUITE).

-include_lib("stdlib/include/assert.hrl").

-compile([export_all, nowarn_export_all]).

all() ->
    [baseline_public_contract, invalid_canonicalization_mode].

baseline_public_contract(_Config) ->
    Dir = signerl_utils:file_path("test/examples/xmlan_migration"),
    ok = xmlan_contract_consumer:run(Dir).

invalid_canonicalization_mode(_Config) ->
    ?assertException(
        error, function_clause, signerl_c14n:canonicalize({<<"root">>, [], []}, unsupported)
    ).
