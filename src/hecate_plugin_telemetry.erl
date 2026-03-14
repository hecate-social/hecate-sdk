%%%-------------------------------------------------------------------
%%% @doc Auto-attach telemetry handlers for evoq and reckon_db events.
%%%
%%% Bridges existing telemetry events from the event sourcing stack
%%% into the hecate_plugin_metrics system. Called by the plugin loader
%%% when a plugin with an event store is loaded.
%%%
%%% Each handler checks that the telemetry metadata's store_id matches
%%% the plugin's store before incrementing metrics — this ensures
%%% per-plugin metric isolation.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_plugin_telemetry).

-export([attach/2, detach/1]).
-export([handle_event/4, handle_duration_event/4]).

%%--------------------------------------------------------------------
%% @doc Attach telemetry handlers for a plugin's event store.
%% PluginName is the plugin identifier (binary).
%% StoreId is the atom store identifier from store_config().
%% @end
%%--------------------------------------------------------------------
-spec attach(binary(), atom()) -> ok.
attach(PluginName, StoreId) ->
    HandlerConfig = #{plugin_name => PluginName, store_id => StoreId},
    Prefix = handler_prefix(PluginName),

    %% Evoq dispatch events
    telemetry:attach(
        <<Prefix/binary, "-dispatch-stop">>,
        [evoq, dispatch, stop],
        fun ?MODULE:handle_event/4,
        HandlerConfig#{metric => <<"evoq_commands_dispatched">>}),

    telemetry:attach(
        <<Prefix/binary, "-dispatch-exception">>,
        [evoq, dispatch, exception],
        fun ?MODULE:handle_event/4,
        HandlerConfig#{metric => <<"evoq_commands_failed">>}),

    %% Evoq projection events
    telemetry:attach(
        <<Prefix/binary, "-projection-event">>,
        [evoq, projection, event],
        fun ?MODULE:handle_event/4,
        HandlerConfig#{metric => <<"evoq_events_projected">>}),

    telemetry:attach(
        <<Prefix/binary, "-projection-exception">>,
        [evoq, projection, exception],
        fun ?MODULE:handle_event/4,
        HandlerConfig#{metric => <<"evoq_projection_errors">>}),

    %% Evoq aggregate execute duration
    telemetry:attach(
        <<Prefix/binary, "-aggregate-execute-stop">>,
        [evoq, aggregate, execute, stop],
        fun ?MODULE:handle_duration_event/4,
        HandlerConfig#{metric => <<"evoq_last_execute_duration_us">>}),

    %% ReckonDB stream operations
    telemetry:attach(
        <<Prefix/binary, "-stream-write-stop">>,
        [reckon_db, stream, write, stop],
        fun ?MODULE:handle_event/4,
        HandlerConfig#{metric => <<"reckon_db_stream_writes">>}),

    telemetry:attach(
        <<Prefix/binary, "-stream-read-stop">>,
        [reckon_db, stream, read, stop],
        fun ?MODULE:handle_event/4,
        HandlerConfig#{metric => <<"reckon_db_stream_reads">>}),

    %% ReckonDB subscription delivery
    telemetry:attach(
        <<Prefix/binary, "-subscription-delivered">>,
        [reckon_db, subscription, event_delivered],
        fun ?MODULE:handle_event/4,
        HandlerConfig#{metric => <<"reckon_db_events_delivered">>}),

    logger:info("[plugin-telemetry] Attached handlers for ~s (store: ~p)",
                [PluginName, StoreId]),
    ok.

%%--------------------------------------------------------------------
%% @doc Detach all telemetry handlers for a plugin.
%% @end
%%--------------------------------------------------------------------
-spec detach(binary()) -> ok.
detach(PluginName) ->
    Prefix = handler_prefix(PluginName),
    Suffixes = [
        <<"-dispatch-stop">>,
        <<"-dispatch-exception">>,
        <<"-projection-event">>,
        <<"-projection-exception">>,
        <<"-aggregate-execute-stop">>,
        <<"-stream-write-stop">>,
        <<"-stream-read-stop">>,
        <<"-subscription-delivered">>
    ],
    lists:foreach(fun(Suffix) ->
        HandlerId = <<Prefix/binary, Suffix/binary>>,
        telemetry:detach(HandlerId)
    end, Suffixes),
    logger:info("[plugin-telemetry] Detached handlers for ~s", [PluginName]),
    ok.

%%====================================================================
%% Telemetry handler callbacks
%%====================================================================

%% @doc Counter handler — increments a counter metric if store_id matches.
handle_event(_EventName, _Measurements, Metadata, Config) ->
    #{plugin_name := PluginName, store_id := ExpectedStore, metric := Metric} = Config,
    case maps:get(store_id, Metadata, undefined) of
        ExpectedStore ->
            hecate_plugin_metrics:counter(PluginName, Metric, 1);
        _ ->
            ok
    end.

%% @doc Duration handler — sets a gauge metric with duration in microseconds.
handle_duration_event(_EventName, Measurements, Metadata, Config) ->
    #{plugin_name := PluginName, store_id := ExpectedStore, metric := Metric} = Config,
    case maps:get(store_id, Metadata, undefined) of
        ExpectedStore ->
            Duration = maps:get(duration, Measurements, 0),
            %% telemetry durations are in native units, convert to microseconds
            DurationUs = erlang:convert_time_unit(Duration, native, microsecond),
            hecate_plugin_metrics:gauge(PluginName, Metric, DurationUs);
        _ ->
            ok
    end.

%%====================================================================
%% Internal
%%====================================================================

handler_prefix(PluginName) ->
    <<"hecate-plugin-telemetry-", PluginName/binary>>.
