-module(signerl_utils).

-export([file_path/1, load_key_from_file/1]).

file_path(FileName) ->
    code:lib_dir(signerl) ++ "/" ++ FileName.

load_key_from_file(FilePath) ->
    {ok, KeyRaw} = file:read_file(FilePath),
    [KeyDer] = public_key:pem_decode(KeyRaw),
    public_key:pem_entry_decode(KeyDer).
