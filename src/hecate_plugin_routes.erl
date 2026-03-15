%%% @doc Route discovery for plugin API handlers.
%%%
%%% Discovers Cowboy route tuples from OTP application metadata.
%%% Each domain app that exports routes/0 from any of its modules
%%% contributes routes automatically.
%%%
%%% Plugins call discover_routes/1 in their routes/0 callback:
%%%
%%%   routes() ->
%%%       hecate_plugin_routes:discover_routes(MyDomainApps).
%%%
%%% Routes returned by domain handlers use "/api/" prefix (for standalone
%%% mode). The plugin loader mounts at /plugin/{name}/api/, so
%%% strip_api_prefix/1 removes the leading "/api" to avoid double nesting.
%%% @end
-module(hecate_plugin_routes).

-export([discover_routes/1, strip_api_prefix/1]).

%% @doc Discover all routes from a list of OTP application names.
%% Scans each app's modules for those exporting routes/0 and collects
%% all returned route tuples.
-spec discover_routes(Apps :: [atom()]) -> [{string(), module(), term()}].
discover_routes(Apps) ->
    lists:flatmap(fun collect_app_routes/1, Apps).

%% @doc Strip leading "/api" from a route path.
%% Domain handlers define routes with "/api/..." prefix for standalone use.
%% When mounted as a plugin under /plugin/{name}/api/, the prefix must be
%% removed to avoid /plugin/{name}/api/api/... paths.
-spec strip_api_prefix({string(), module(), term()}) -> {string(), module(), term()}.
strip_api_prefix({"/api" ++ Rest, Handler, Opts}) ->
    {Rest, Handler, Opts};
strip_api_prefix(Route) ->
    Route.

%%% Internal

collect_app_routes(App) ->
    Mods = app_modules(App),
    Handlers = [M || M <- Mods, exports_routes(M)],
    lists:flatmap(fun(M) -> M:routes() end, Handlers).

app_modules(App) ->
    case application:get_key(App, modules) of
        {ok, Mods} -> Mods;
        _ -> []
    end.

exports_routes(Mod) ->
    code:ensure_loaded(Mod),
    erlang:function_exported(Mod, routes, 0).
