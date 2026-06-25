%%%-------------------------------------------------------------------
%%% @doc Plugin metrics facade.
%%%
%%% Lightweight metrics using OTP counters (atomics-backed, lock-free)
%%% with an ETS registry. Each plugin gets its own counters reference
%%% with up to 64 metric slots.
%%%
%%% Two metric types:
%%%   counter — monotonically increasing (e.g. requests served)
%%%   gauge   — point-in-time value (e.g. last latency)
%%%
%%% Plugins use macros from hecate_plugin.hrl:
%%%   ?METRIC_INC(Name)      — increment counter by 1
%%%   ?METRIC_ADD(Name, N)   — increment counter by N
%%%   ?METRIC_SET(Name, Val) — set gauge to Val
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_plugin_metrics).

-export([init/1, counter/3, gauge/3, get_all/0, get_plugin/1, cleanup/1]).

-define(TABLE, hecate_plugin_metrics).
-define(SLOTS_PER_PLUGIN, 64).

%%--------------------------------------------------------------------
%% @doc Initialize metrics namespace for a plugin.
%% Creates a counters reference with 64 slots.
%% Safe to call multiple times (idempotent).
%% @end
%%--------------------------------------------------------------------
-spec init(binary()) -> ok.
init(PluginName) ->
    ensure_table(),
    case ets:lookup(?TABLE, {PluginName, <<"__counters_ref__">>}) of
        [_] ->
            ok;
        [] ->
            Ref = counters:new(?SLOTS_PER_PLUGIN, [write_concurrency]),
            ets:insert(?TABLE, {{PluginName, <<"__counters_ref__">>}, Ref, 0, ref}),
            ok
    end.

%%--------------------------------------------------------------------
%% @doc Increment a counter metric by N.
%% @end
%%--------------------------------------------------------------------
-spec counter(binary(), binary(), integer()) -> ok.
counter(PluginName, MetricName, N) ->
    {Ref, Slot} = get_or_create_slot(PluginName, MetricName, counter),
    counters:add(Ref, Slot, N),
    ok.

%%--------------------------------------------------------------------
%% @doc Set a gauge metric to Value.
%% @end
%%--------------------------------------------------------------------
-spec gauge(binary(), binary(), integer()) -> ok.
gauge(PluginName, MetricName, Value) ->
    {Ref, Slot} = get_or_create_slot(PluginName, MetricName, gauge),
    counters:put(Ref, Slot, Value),
    ok.

%%--------------------------------------------------------------------
%% @doc Get all metrics for all plugins.
%% Returns a list of maps with plugin, name, type, and value keys.
%% @end
%%--------------------------------------------------------------------
-spec get_all() -> [map()].
get_all() ->
    case ets:info(?TABLE) of
        undefined -> [];
        _ -> ets:foldl(fun collect_metric/2, [], ?TABLE)
    end.

collect_metric({{_Plugin, <<"__counters_ref__">>}, _Ref, _Slot, ref}, Acc) ->
    Acc;
collect_metric({{Plugin, Name}, _Ref, Slot, Type}, Acc) ->
    metric_value(get_counter_ref(Plugin), Plugin, Name, Slot, Type, Acc).

metric_value(undefined, _Plugin, _Name, _Slot, _Type, Acc) ->
    Acc;
metric_value(CRef, Plugin, Name, Slot, Type, Acc) ->
    Value = counters:get(CRef, Slot),
    [#{plugin => Plugin, name => Name, type => Type, value => Value} | Acc].

%%--------------------------------------------------------------------
%% @doc Get all metrics for a specific plugin.
%% @end
%%--------------------------------------------------------------------
-spec get_plugin(binary()) -> [map()].
get_plugin(PluginName) ->
    case ets:info(?TABLE) of
        undefined -> [];
        _ -> get_plugin_metrics(get_counter_ref(PluginName), PluginName)
    end.

get_plugin_metrics(undefined, _PluginName) ->
    [];
get_plugin_metrics(CRef, PluginName) ->
    ets:foldl(fun(E, Acc) -> collect_plugin_metric(E, PluginName, CRef, Acc) end,
              [], ?TABLE).

collect_plugin_metric({{P, <<"__counters_ref__">>}, _, _, ref}, P, _CRef, Acc) ->
    Acc;
collect_plugin_metric({{P, Name}, _, Slot, Type}, P, CRef, Acc) ->
    Value = counters:get(CRef, Slot),
    [#{plugin => P, name => Name, type => Type, value => Value} | Acc];
collect_plugin_metric(_, _PluginName, _CRef, Acc) ->
    Acc.

%%--------------------------------------------------------------------
%% @doc Remove all metrics for a plugin.
%% @end
%%--------------------------------------------------------------------
-spec cleanup(binary()) -> ok.
cleanup(PluginName) ->
    case ets:info(?TABLE) of
        undefined -> ok;
        _ -> cleanup_plugin(PluginName)
    end.

cleanup_plugin(PluginName) ->
    %% Collect keys to delete, then delete them
    Keys = ets:foldl(fun(E, Acc) -> collect_plugin_key(E, PluginName, Acc) end,
                     [], ?TABLE),
    lists:foreach(fun(Key) -> ets:delete(?TABLE, Key) end, Keys),
    ok.

collect_plugin_key({{P, Name}, _, _, _}, P, Acc) ->
    [{P, Name} | Acc];
collect_plugin_key(_, _PluginName, Acc) ->
    Acc.

%%====================================================================
%% Internal
%%====================================================================

ensure_table() ->
    case ets:info(?TABLE) of
        undefined ->
            ets:new(?TABLE, [set, named_table, public,
                             {read_concurrency, true},
                             {write_concurrency, true}]);
        _ ->
            ok
    end.

get_counter_ref(PluginName) ->
    case ets:lookup(?TABLE, {PluginName, <<"__counters_ref__">>}) of
        [{{_, _}, Ref, _, ref}] -> Ref;
        [] -> undefined
    end.

get_or_create_slot(PluginName, MetricName, Type) ->
    ensure_table(),
    Key = {PluginName, MetricName},
    case ets:lookup(?TABLE, Key) of
        [{_, _Ref, Slot, _Type}] ->
            {get_counter_ref(PluginName), Slot};
        [] ->
            Ref = ensure_counter_ref(PluginName),
            Slot = next_slot(PluginName),
            ets:insert(?TABLE, {Key, Ref, Slot, Type}),
            {Ref, Slot}
    end.

ensure_counter_ref(PluginName) ->
    case get_counter_ref(PluginName) of
        undefined ->
            init(PluginName),
            get_counter_ref(PluginName);
        Ref -> Ref
    end.

next_slot(PluginName) ->
    MaxSlot = ets:foldl(fun
        ({{P, <<"__counters_ref__">>}, _, _, ref}, Max) when P =:= PluginName ->
            Max;
        ({{P, _Name}, _, Slot, _Type}, Max) when P =:= PluginName ->
            max(Slot, Max);
        (_, Max) ->
            Max
    end, 0, ?TABLE),
    MaxSlot + 1.
