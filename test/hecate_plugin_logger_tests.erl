-module(hecate_plugin_logger_tests).
-include_lib("eunit/include/eunit.hrl").

format_basic_test() ->
    Event = #{
        level => info,
        msg => {string, "Hello world"},
        meta => #{
            time => erlang:system_time(microsecond),
            pid => self()
        }
    },
    Result = hecate_plugin_logger:format(Event, #{}),
    Bin = iolist_to_binary(Result),
    %% Should end with newline
    ?assertEqual($\n, binary:last(Bin)),
    %% Should be valid JSON
    Decoded = json:decode(binary:part(Bin, 0, byte_size(Bin) - 1)),
    ?assertEqual(<<"info">>, maps:get(<<"level">>, Decoded)),
    ?assertEqual(<<"Hello world">>, maps:get(<<"msg">>, Decoded)),
    ?assert(maps:is_key(<<"ts">>, Decoded)),
    ?assert(maps:is_key(<<"pid">>, Decoded)).

format_with_plugin_metadata_test() ->
    Event = #{
        level => warning,
        msg => {string, "Something happened"},
        meta => #{
            time => erlang:system_time(microsecond),
            plugin_name => <<"martha">>,
            plugin_version => <<"0.2.1">>
        }
    },
    Result = hecate_plugin_logger:format(Event, #{}),
    Decoded = json:decode(iolist_to_binary(string:trim(Result))),
    ?assertEqual(<<"martha">>, maps:get(<<"plugin">>, Decoded)),
    ?assertEqual(<<"0.2.1">>, maps:get(<<"plugin_version">>, Decoded)).

format_with_mfa_test() ->
    Event = #{
        level => debug,
        msg => {string, "Debug msg"},
        meta => #{
            time => erlang:system_time(microsecond),
            mfa => {my_module, my_fun, 2}
        }
    },
    Result = hecate_plugin_logger:format(Event, #{}),
    Decoded = json:decode(iolist_to_binary(string:trim(Result))),
    ?assertEqual(<<"my_module:my_fun/2">>, maps:get(<<"mfa">>, Decoded)).

format_io_format_msg_test() ->
    Event = #{
        level => error,
        msg => {"Error ~p in ~s", [badarg, "handler"]},
        meta => #{time => erlang:system_time(microsecond)}
    },
    Result = hecate_plugin_logger:format(Event, #{}),
    Decoded = json:decode(iolist_to_binary(string:trim(Result))),
    Msg = maps:get(<<"msg">>, Decoded),
    ?assert(is_binary(Msg)),
    ?assertNotEqual(<<>>, Msg).

format_report_msg_test() ->
    Event = #{
        level => info,
        msg => {report, #{key => <<"value">>, count => 42}},
        meta => #{time => erlang:system_time(microsecond)}
    },
    Result = hecate_plugin_logger:format(Event, #{}),
    Decoded = json:decode(iolist_to_binary(string:trim(Result))),
    ?assert(maps:is_key(<<"msg">>, Decoded)).

format_truncates_long_messages_test() ->
    LongMsg = list_to_binary(lists:duplicate(5000, $x)),
    Event = #{
        level => info,
        msg => {string, LongMsg},
        meta => #{time => erlang:system_time(microsecond)}
    },
    Result = hecate_plugin_logger:format(Event, #{}),
    Decoded = json:decode(iolist_to_binary(string:trim(Result))),
    Msg = maps:get(<<"msg">>, Decoded),
    %% 4096 + "..." = 4099
    ?assert(byte_size(Msg) =< 4099).

check_config_valid_test() ->
    ?assertEqual(ok, hecate_plugin_logger:check_config(#{})).

check_config_invalid_test() ->
    ?assertMatch({error, _}, hecate_plugin_logger:check_config(not_a_map)).
