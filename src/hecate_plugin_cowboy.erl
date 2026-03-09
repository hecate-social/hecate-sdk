%%%-------------------------------------------------------------------
%%% @doc Cowboy route setup helper for plugins.
%%%
%%% Takes routes from a plugin's routes/0 callback and prepends
%%% the standard /plugin/{name}/ prefix.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_plugin_cowboy).

-export([prefix_routes/2, make_dispatch/2, ws_upgrade/3]).

%% @doc Prefix plugin routes with /plugin/{name}/api.
%% Plugin routes are relative (e.g., "/documents/:id").
%% This prepends the standard prefix.
-spec prefix_routes(PluginName :: string() | binary(),
                    Routes :: [{string(), module(), term()}]) ->
    [{string(), module(), term()}].
prefix_routes(PluginName, Routes) ->
    Name = to_list(PluginName),
    Prefix = "/plugin/" ++ Name ++ "/api",
    [{Prefix ++ Path, Handler, Opts} || {Path, Handler, Opts} <- Routes].

%% @doc Build a cowboy dispatch table for a plugin.
%% Includes API routes and static file serving.
-spec make_dispatch(PluginName :: string() | binary(),
                    Routes :: [{string(), module(), term()}]) ->
    cowboy_router:dispatch_rules().
make_dispatch(PluginName, Routes) ->
    Name = to_list(PluginName),
    ApiRoutes = prefix_routes(PluginName, Routes),
    StaticRoute = static_route(Name),
    AllRoutes = ApiRoutes ++ StaticRoute,
    cowboy_router:compile([{'_', AllRoutes}]).

%% @doc Standard WebSocket upgrade for plugin handlers.
%% Call from a cowboy handler's init/2 to upgrade to WebSocket.
-spec ws_upgrade(Req :: cowboy_req:req(), State :: term(),
                 Opts :: map()) ->
    {cowboy_websocket, cowboy_req:req(), term()}.
ws_upgrade(Req, State, Opts) ->
    {cowboy_websocket, Req, State, Opts}.

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

static_route(Name) ->
    %% Serve plugin static files at /plugin/{name}/[...]
    Path = "/plugin/" ++ Name ++ "/[...]",
    [{Path, cowboy_static, {priv_dir, list_to_atom("hecate_plugin_" ++ Name), "static"}}].

to_list(V) when is_binary(V) -> binary_to_list(V);
to_list(V) when is_list(V) -> V.
