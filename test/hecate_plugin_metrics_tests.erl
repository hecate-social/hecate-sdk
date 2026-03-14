-module(hecate_plugin_metrics_tests).
-include_lib("eunit/include/eunit.hrl").

setup() ->
    %% Clean up any leftover table
    catch ets:delete(hecate_plugin_metrics),
    ok.

cleanup(_) ->
    catch ets:delete(hecate_plugin_metrics),
    ok.

metrics_test_() ->
    {foreach, fun setup/0, fun cleanup/1, [
        {"init creates table and counters ref", fun init_creates_table/0},
        {"init is idempotent", fun init_idempotent/0},
        {"counter increments", fun counter_increments/0},
        {"gauge sets value", fun gauge_sets_value/0},
        {"get_all returns all metrics", fun get_all_returns_all/0},
        {"get_plugin returns only that plugin", fun get_plugin_filters/0},
        {"cleanup removes plugin metrics", fun cleanup_removes/0},
        {"counter auto-inits plugin", fun counter_auto_inits/0},
        {"multiple plugins are isolated", fun plugins_isolated/0}
    ]}.

init_creates_table() ->
    ok = hecate_plugin_metrics:init(<<"test-plugin">>),
    ?assertNotEqual(undefined, ets:info(hecate_plugin_metrics)).

init_idempotent() ->
    ok = hecate_plugin_metrics:init(<<"test-plugin">>),
    ok = hecate_plugin_metrics:init(<<"test-plugin">>),
    ?assertNotEqual(undefined, ets:info(hecate_plugin_metrics)).

counter_increments() ->
    hecate_plugin_metrics:init(<<"p1">>),
    hecate_plugin_metrics:counter(<<"p1">>, <<"requests">>, 1),
    hecate_plugin_metrics:counter(<<"p1">>, <<"requests">>, 5),
    [#{value := V}] = hecate_plugin_metrics:get_plugin(<<"p1">>),
    ?assertEqual(6, V).

gauge_sets_value() ->
    hecate_plugin_metrics:init(<<"p1">>),
    hecate_plugin_metrics:gauge(<<"p1">>, <<"latency">>, 100),
    hecate_plugin_metrics:gauge(<<"p1">>, <<"latency">>, 42),
    [#{value := V, type := T}] = hecate_plugin_metrics:get_plugin(<<"p1">>),
    ?assertEqual(42, V),
    ?assertEqual(gauge, T).

get_all_returns_all() ->
    hecate_plugin_metrics:init(<<"p1">>),
    hecate_plugin_metrics:init(<<"p2">>),
    hecate_plugin_metrics:counter(<<"p1">>, <<"a">>, 1),
    hecate_plugin_metrics:counter(<<"p2">>, <<"b">>, 2),
    All = hecate_plugin_metrics:get_all(),
    ?assertEqual(2, length(All)),
    Names = lists:sort([maps:get(name, M) || M <- All]),
    ?assertEqual([<<"a">>, <<"b">>], Names).

get_plugin_filters() ->
    hecate_plugin_metrics:init(<<"p1">>),
    hecate_plugin_metrics:init(<<"p2">>),
    hecate_plugin_metrics:counter(<<"p1">>, <<"a">>, 1),
    hecate_plugin_metrics:counter(<<"p2">>, <<"b">>, 2),
    P1 = hecate_plugin_metrics:get_plugin(<<"p1">>),
    ?assertEqual(1, length(P1)),
    [#{name := <<"a">>, value := 1}] = P1.

cleanup_removes() ->
    hecate_plugin_metrics:init(<<"p1">>),
    hecate_plugin_metrics:counter(<<"p1">>, <<"a">>, 5),
    ok = hecate_plugin_metrics:cleanup(<<"p1">>),
    ?assertEqual([], hecate_plugin_metrics:get_plugin(<<"p1">>)).

counter_auto_inits() ->
    %% Counter on uninitialized plugin should auto-init
    hecate_plugin_metrics:counter(<<"auto">>, <<"x">>, 3),
    [#{value := 3}] = hecate_plugin_metrics:get_plugin(<<"auto">>).

plugins_isolated() ->
    hecate_plugin_metrics:init(<<"a">>),
    hecate_plugin_metrics:init(<<"b">>),
    hecate_plugin_metrics:counter(<<"a">>, <<"count">>, 10),
    hecate_plugin_metrics:counter(<<"b">>, <<"count">>, 20),
    [#{value := 10}] = hecate_plugin_metrics:get_plugin(<<"a">>),
    [#{value := 20}] = hecate_plugin_metrics:get_plugin(<<"b">>).
