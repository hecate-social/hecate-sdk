%%%-------------------------------------------------------------------
%%% @doc Standard directory layout for plugin data.
%%%
%%% Replaces per-plugin path modules (e.g., app_scribed_paths.erl).
%%% All plugins get the same layout under their data directory:
%%%
%%%   ~/.hecate/plugins/{plugin_name}/
%%%   ├── sqlite/        — SQLite read model databases
%%%   ├── reckon-db/     — ReckonDB event store
%%%   └── run/           — Runtime files (PID, etc.)
%%%
%%% Resolution order for the base directory:
%%%   1. application:get_env(hecate, data_dir) — set when running inside hecate-daemon
%%%   2. HECATE_HOME env var — set when running as a standalone plugin
%%%   3. ~/.hecate — default fallback
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_plugin_paths).

-export([base_dir/1, sqlite_dir/1, sqlite_path/2, reckon_dir/1,
         reckon_path/2, run_dir/1, run_path/2, ensure_layout/1]).

%% @doc Root data directory for a plugin.
-spec base_dir(PluginName :: string() | binary()) -> file:filename().
base_dir(PluginName) ->
    Name = sanitize_name(PluginName),
    HecateHome = hecate_home(),
    filename:join([HecateHome, "plugins", Name]).

%% @doc SQLite directory for a plugin's read models.
-spec sqlite_dir(string() | binary()) -> file:filename().
sqlite_dir(PluginName) ->
    filename:join(base_dir(PluginName), "sqlite").

%% @doc Full path to a named SQLite database file.
-spec sqlite_path(string() | binary(), string()) -> file:filename().
sqlite_path(PluginName, DbName) ->
    filename:join(sqlite_dir(PluginName), DbName).

%% @doc ReckonDB directory for a plugin's event store.
-spec reckon_dir(string() | binary()) -> file:filename().
reckon_dir(PluginName) ->
    filename:join(base_dir(PluginName), "reckon-db").

%% @doc Full path to a named ReckonDB store directory.
-spec reckon_path(string() | binary(), string()) -> file:filename().
reckon_path(PluginName, StoreName) ->
    filename:join(reckon_dir(PluginName), StoreName).

%% @doc Runtime directory for PID files, temp data.
-spec run_dir(string() | binary()) -> file:filename().
run_dir(PluginName) ->
    filename:join(base_dir(PluginName), "run").

%% @doc Full path to a named runtime file.
-spec run_path(string() | binary(), string()) -> file:filename().
run_path(PluginName, FileName) ->
    filename:join(run_dir(PluginName), FileName).

%% @doc Create all standard directories for a plugin.
-spec ensure_layout(string() | binary()) -> ok.
ensure_layout(PluginName) ->
    Dirs = [sqlite_dir(PluginName), reckon_dir(PluginName), run_dir(PluginName)],
    lists:foreach(fun(Dir) -> ok = filelib:ensure_path(Dir) end, Dirs).

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

hecate_home() ->
    case application:get_env(hecate, data_dir) of
        {ok, Dir} -> expand_tilde(Dir);
        undefined -> hecate_home_from_env()
    end.

hecate_home_from_env() ->
    case os:getenv("HECATE_HOME") of
        false -> filename:join(os:getenv("HOME"), ".hecate");
        Dir   -> Dir
    end.

expand_tilde([$~ | Rest]) -> os:getenv("HOME") ++ Rest;
expand_tilde(Path)        -> Path.

%% Strip org prefix (e.g., "hecate-apps/scribe" -> "scribe")
sanitize_name(Name) when is_binary(Name) ->
    case binary:split(Name, <<"/">>) of
        [_, Short] -> binary_to_list(Short);
        [Single]   -> binary_to_list(Single)
    end;
sanitize_name(Name) when is_list(Name) ->
    Name.
