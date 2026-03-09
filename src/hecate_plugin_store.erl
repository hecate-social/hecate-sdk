%%%-------------------------------------------------------------------
%%% @doc ReckonDB store setup helper for plugins.
%%%
%%% Creates and configures a plugin's event store based on
%%% its hecate_store_config record.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_plugin_store).

-include("hecate_plugin.hrl").

-export([create_store/2, dispatch/3]).

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

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

ensure_map(undefined) -> #{};
ensure_map(M) when is_map(M) -> M.
