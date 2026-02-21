-module(signerl_utils).
-feature(maybe_expr, enable).

-export([file_path/1, load_key_from_file/1, signable_message/1]).

file_path(FileName) ->
    code:lib_dir(signerl) ++ "/" ++ FileName.

load_key_from_file(FilePath) ->
    {ok, KeyRaw} = file:read_file(FilePath),
    [KeyDer] = public_key:pem_decode(KeyRaw),
    public_key:pem_entry_decode(KeyDer).

signable_message(Message) ->
    maybe
        {ok, Prolog} ?= signerl_xml:parse_prolog(Message),
        ParsedMessage = signerl_xml:parse_binary(Message),
        {ok, signerl_xml:export(Prolog, ParsedMessage)}
    else
        {error, Reason} ->
            {error, Reason}
    end.
