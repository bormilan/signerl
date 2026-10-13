-module(signerl_utils).

-feature(maybe_expr, enable).

-export([
    file_path/1,
    load_key_from_file/1,
    valid_utc_timestamp/1,
    current_utc_timestamp/0,
    format_utc_timestamp/1,
    is_byte_list/1
]).

file_path(FileName) ->
    code:lib_dir(signerl) ++ "/" ++ FileName.

load_key_from_file(FilePath) ->
    maybe
        {ok, KeyRaw} ?= read_key_file(FilePath),
        {ok, KeyDer} ?= decode_pem(KeyRaw),
        {ok, public_key:pem_entry_decode(KeyDer)}
    end.

read_key_file(FilePath) ->
    case file:read_file(FilePath) of
        {ok, _} = Ok -> Ok;
        {error, Reason} -> {error, {file_error, Reason}}
    end.

decode_pem(KeyRaw) ->
    case public_key:pem_decode(KeyRaw) of
        [KeyDer] -> {ok, KeyDer};
        _ -> {error, invalid_pem}
    end.

valid_utc_timestamp(
    <<Y1, Y2, Y3, Y4, $-, M1, M2, $-, D1, D2, $T, H1, H2, $:, Min1, Min2, $:, S1, S2, $Z>>
) ->
    DateTimeDigits = [Y1, Y2, Y3, Y4, M1, M2, D1, D2, H1, H2, Min1, Min2, S1, S2],
    Year = to_int(Y1, Y2) * 100 + to_int(Y3, Y4),
    all_digits(DateTimeDigits) andalso
        in_range(Year, 1, 9999) andalso
        calendar:valid_date({Year, to_int(M1, M2), to_int(D1, D2)}) andalso
        in_range(to_int(H1, H2), 0, 23) andalso
        in_range(to_int(Min1, Min2), 0, 59) andalso
        in_range(to_int(S1, S2), 0, 59);
valid_utc_timestamp(_) ->
    false.

current_utc_timestamp() ->
    format_utc_timestamp(calendar:universal_time()).

% Format an already valid UTC datetime; timestamp validation is separate.
-spec format_utc_timestamp(calendar:datetime()) -> binary().
format_utc_timestamp({{Year, Month, Day}, {Hour, Minute, Second}}) ->
    <<
        (pad4(Year))/binary,
        "-",
        (pad2(Month))/binary,
        "-",
        (pad2(Day))/binary,
        "T",
        (pad2(Hour))/binary,
        ":",
        (pad2(Minute))/binary,
        ":",
        (pad2(Second))/binary,
        "Z"
    >>.

all_digits([]) ->
    true;
all_digits([Char | Rest]) ->
    Char >= $0 andalso Char =< $9 andalso all_digits(Rest).

to_int(Tens, Ones) ->
    (Tens - $0) * 10 + (Ones - $0).

in_range(Value, Min, Max) ->
    Value >= Min andalso Value =< Max.

pad2(Value) when Value < 10 ->
    <<"0", (integer_to_binary(Value))/binary>>;
pad2(Value) ->
    integer_to_binary(Value).

pad4(Value) ->
    list_to_binary(io_lib:format("~4..0B", [Value])).

is_byte_list(Value) ->
    lists:all(fun(Byte) -> is_integer(Byte) andalso Byte >= 0 andalso Byte =< 255 end, Value).
