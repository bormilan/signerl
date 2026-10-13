-module(signerl_utils_test).
-include_lib("eunit/include/eunit.hrl").

valid_calendar_timestamps_test_() ->
    [
        ?_assert(signerl_utils:valid_utc_timestamp(Time))
     || Time <- [
            <<"2000-02-29T00:00:00Z">>,
            <<"2024-02-29T23:59:59Z">>,
            <<"2026-04-30T12:34:56Z">>,
            <<"0001-01-01T00:00:00Z">>,
            <<"9999-12-31T23:59:59Z">>
        ]
    ].

invalid_calendar_timestamps_test_() ->
    [
        ?_assertNot(signerl_utils:valid_utc_timestamp(Time))
     || Time <- [
            <<"2026-02-31T12:00:00Z">>,
            <<"2026-02-29T12:00:00Z">>,
            <<"1900-02-29T12:00:00Z">>,
            <<"2100-02-29T12:00:00Z">>,
            <<"2026-04-31T12:00:00Z">>,
            <<"2026-00-01T12:00:00Z">>,
            <<"2026-13-01T12:00:00Z">>,
            <<"2026-01-00T12:00:00Z">>,
            <<"0000-01-01T12:00:00Z">>,
            <<"2026-01-01T24:00:00Z">>,
            <<"2026-01-01T12:60:00Z">>,
            <<"2026-01-01T12:00:60Z">>,
            <<"2026-01-01T12:00:00+00:00">>,
            <<"2026-01-01T12:00:00.0Z">>,
            <<"202x-01-01T12:00:00Z">>,
            <<"2026-01-01T12:00:00z">>,
            undefined
        ]
    ].

format_utc_timestamp_test_() ->
    [
        ?_assertEqual(
            <<"0001-01-02T03:04:05Z">>,
            signerl_utils:format_utc_timestamp({{1, 1, 2}, {3, 4, 5}})
        ),
        ?_assertEqual(
            <<"2000-02-29T00:00:00Z">>,
            signerl_utils:format_utc_timestamp({{2000, 2, 29}, {0, 0, 0}})
        ),
        ?_assertEqual(
            <<"9999-12-31T23:59:59Z">>,
            signerl_utils:format_utc_timestamp({{9999, 12, 31}, {23, 59, 59}})
        )
    ].
