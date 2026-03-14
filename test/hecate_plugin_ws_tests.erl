-module(hecate_plugin_ws_tests).
-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% encode/1
%%====================================================================

encode_map_test() ->
    {text, Encoded} = hecate_plugin_ws:encode(#{<<"hello">> => <<"world">>}),
    Decoded = json:decode(iolist_to_binary(Encoded)),
    ?assertEqual(<<"world">>, maps:get(<<"hello">>, Decoded)).

encode_list_test() ->
    {text, Encoded} = hecate_plugin_ws:encode([1, 2, 3]),
    Decoded = json:decode(iolist_to_binary(Encoded)),
    ?assertEqual([1, 2, 3], Decoded).

%%====================================================================
%% decode/1
%%====================================================================

decode_json_object_test() ->
    Result = hecate_plugin_ws:decode(<<"{\"key\":\"value\"}">>),
    ?assertEqual(#{<<"key">> => <<"value">>}, Result).

decode_json_array_test() ->
    Result = hecate_plugin_ws:decode(<<"[1,2,3]">>),
    ?assertEqual([1, 2, 3], Result).

%%====================================================================
%% reply_json/2
%%====================================================================

reply_json_includes_type_test() ->
    {text, Encoded} = hecate_plugin_ws:reply_json(<<"update">>, #{<<"id">> => 1}),
    Decoded = json:decode(iolist_to_binary(Encoded)),
    ?assertEqual(<<"update">>, maps:get(<<"type">>, Decoded)),
    ?assertEqual(1, maps:get(<<"id">>, Decoded)).

%%====================================================================
%% reply_error/3
%%====================================================================

reply_error_structure_test() ->
    {text, Encoded} = hecate_plugin_ws:reply_error(
        <<"not_found">>, <<"Item not found">>, #{<<"id">> => <<"abc">>}),
    Decoded = json:decode(iolist_to_binary(Encoded)),
    ?assertEqual(<<"error">>, maps:get(<<"type">>, Decoded)),
    ?assertEqual(<<"not_found">>, maps:get(<<"code">>, Decoded)),
    ?assertEqual(<<"Item not found">>, maps:get(<<"message">>, Decoded)),
    ?assertEqual(#{<<"id">> => <<"abc">>}, maps:get(<<"details">>, Decoded)).

%%====================================================================
%% upgrade/2
%%====================================================================

upgrade_returns_websocket_tuple_test() ->
    FakeReq = #{},
    State = #{},
    Result = hecate_plugin_ws:upgrade(FakeReq, State),
    ?assertMatch({cowboy_websocket, #{}, #{}, #{idle_timeout := 60000}}, Result).
