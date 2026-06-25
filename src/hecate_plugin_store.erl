%%%-------------------------------------------------------------------
%%% @doc ReckonDB store setup helper for plugins.
%%%
%%% Creates and configures a plugin's event store based on
%%% its hecate_store_config record.
%%%
%%% Plugins with multiple bounded contexts use start_extra_stores/2
%%% to create additional stores beyond the primary one (which the
%%% plugin loader creates via store_config/0). Use
%%% start_subscriptions/1 to wire up evoq event delivery for all
%%% stores.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_plugin_store).

-include("hecate_plugin.hrl").
-include_lib("reckon_db/include/reckon_db.hrl").

-export([create_store/2, dispatch/3]).
-export([start_extra_stores/2, start_subscriptions/1]).

%% @doc Create a ReckonDB store for a plugin.
%% PluginName is used to derive the data directory.
%% Config comes from the plugin's store_config/0 callback.
-spec create_store(PluginName :: string() | binary(),
                   Config :: #hecate_store_config{}) -> ok | {error, term()}.
create_store(PluginName, #hecate_store_config{
    store_id = StoreId,
    dir_name = DirName,
    description = Desc,
    options = Opts
}) ->
    DataDir = hecate_plugin_paths:reckon_path(PluginName, DirName),
    ok = filelib:ensure_path(DataDir),
    StoreOpts = maps:merge(#{
        data_dir => DataDir
    }, ensure_map(Opts)),
    logger:info("[plugin-store] Creating ~s store at ~s (~s)",
                [StoreId, DataDir, Desc]),
    reckon_db_sup:start_store(StoreId, StoreOpts).

%% @doc Dispatch an evoq command to a plugin's store.
%% Convenience wrapper that sets the standard dispatch options.
-spec dispatch(StoreId :: atom(), Command :: term(), ExtraOpts :: map()) ->
    ok | {error, term()}.
dispatch(StoreId, Command, ExtraOpts) ->
    Opts = maps:merge(#{
        store_id => StoreId,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }, ExtraOpts),
    evoq_dispatcher:dispatch(Command, Opts).

%% @doc Create additional ReckonDB stores for a plugin.
%% The primary store is created by the plugin loader via store_config/0.
%% Call this from init/1 for extra bounded contexts.
%%
%% StoreSpecs is a list of {StoreId, SubDir, Label} tuples:
%%   {orchestration_store, "orchestration", "Agent Orchestration"}
%%
%% Each store gets a subdirectory under BaseDataDir.
-spec start_extra_stores(BaseDataDir :: string(),
                         StoreSpecs :: [{atom(), string(), string()}]) -> ok.
start_extra_stores(BaseDataDir, StoreSpecs) ->
    lists:foreach(fun({StoreId, SubDir, Label}) ->
        start_one_store(BaseDataDir, StoreId, SubDir, Label)
    end, StoreSpecs).

%% @doc Start evoq store subscriptions for a list of store IDs.
%% Subscriptions enable event delivery from ReckonDB to evoq projections
%% and process managers. Call after stores are created.
-spec start_subscriptions(StoreIds :: [atom()]) -> ok.
start_subscriptions(StoreIds) ->
    lists:foreach(fun start_subscription/1, StoreIds).

start_subscription(StoreId) ->
    log_subscription(evoq_store_subscription:start_link(StoreId), StoreId).

log_subscription({ok, _Pid}, StoreId) ->
    logger:info("[plugin-store] Subscription ready for ~p", [StoreId]);
log_subscription({error, Reason}, StoreId) ->
    logger:warning("[plugin-store] Subscription failed for ~p: ~p", [StoreId, Reason]).

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

start_one_store(BaseDataDir, StoreId, SubDir, Label) ->
    DataDir = filename:join(BaseDataDir, SubDir),
    ok = filelib:ensure_path(DataDir),
    Config = #store_config{
        store_id = StoreId,
        data_dir = DataDir,
        mode = single,
        writer_pool_size = 5,
        reader_pool_size = 5,
        gateway_pool_size = 2,
        options = #{}
    },
    case reckon_db_sup:start_store(Config) of
        {ok, _Pid} ->
            logger:info("[plugin-store] Store ~p ready (~s)", [StoreId, Label]);
        {error, {already_started, _Pid}} ->
            logger:info("[plugin-store] Store ~p already running", [StoreId]);
        {error, Reason} ->
            logger:error("[plugin-store] Failed to start store ~p: ~p", [StoreId, Reason])
    end.

ensure_map(undefined) -> #{};
ensure_map(M) when is_map(M) -> M.
