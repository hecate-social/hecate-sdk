-module(hecate_plugin_cowboy_tests).
-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% prefix_routes/2
%%====================================================================

prefix_routes_binary_name_test() ->
    Routes = [{"/items", my_handler, []}, {"/items/:id", my_handler, []}],
    Result = hecate_plugin_cowboy:prefix_routes(<<"scribe">>, Routes),
    ?assertEqual([
        {"/plugin/scribe/api/items", my_handler, []},
        {"/plugin/scribe/api/items/:id", my_handler, []}
    ], Result).

prefix_routes_string_name_test() ->
    Routes = [{"/docs", doc_handler, #{}}],
    Result = hecate_plugin_cowboy:prefix_routes("notes", Routes),
    ?assertEqual([{"/plugin/notes/api/docs", doc_handler, #{}}], Result).

prefix_routes_empty_test() ->
    ?assertEqual([], hecate_plugin_cowboy:prefix_routes(<<"x">>, [])).

%%====================================================================
%% ws_upgrade/3
%%====================================================================

ws_upgrade_returns_websocket_tuple_test() ->
    FakeReq = #{},
    State = #{user => <<"alice">>},
    Opts = #{idle_timeout => 30000},
    Result = hecate_plugin_cowboy:ws_upgrade(FakeReq, State, Opts),
    ?assertMatch({cowboy_websocket, #{}, #{user := <<"alice">>}, #{idle_timeout := 30000}}, Result).
