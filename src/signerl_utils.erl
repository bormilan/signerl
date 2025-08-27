-module(signerl_utils).

-export([file_path/1]).

file_path(FileName) ->
    code:priv_dir(signerl) ++ "/" ++ FileName.
