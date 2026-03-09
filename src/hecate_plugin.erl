%%%-------------------------------------------------------------------
%%% @doc Plugin behaviour — the loading contract the daemon calls.
%%%
%%% Every in-VM plugin implements this behaviour. The daemon uses it to:
%%% - Initialize the plugin with its configuration
%%% - Discover API routes to mount under /plugin/{name}/api/...
%%% - Set up the plugin's ReckonDB event store
%%% - Serve the plugin's frontend static assets
%%% - Read the plugin's manifest (version, capabilities, permissions)
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_plugin).

-include("hecate_plugin.hrl").

%% Initialize the plugin. Called once when the plugin loads.
%% Config contains the plugin's persisted settings merged with defaults.
%% Return {ok, State} where State is passed to the supervision tree.
-callback init(Config :: map()) -> {ok, State :: term()} | {error, Reason :: term()}.

%% Return cowboy routes for this plugin's API.
%% Routes are mounted under /plugin/{name}/api/ automatically.
%% The plugin should NOT include the prefix, just relative paths.
%%
%% Example:
%%   [{"/documents", app_scribe_documents_api, []},
%%    {"/documents/:id", app_scribe_document_api, []},
%%    {"/ws", app_scribe_ws, []}]
-callback routes() -> [{Path :: string(), Handler :: module(), Opts :: term()}].

%% ReckonDB store configuration for this plugin.
%% Return a store_config record or 'none' if the plugin has no event store.
-callback store_config() -> #hecate_store_config{} | none.

%% Path to the plugin's static frontend assets directory.
%% These are served at /plugin/{name}/ by the daemon's cowboy.
%% Return 'none' if the plugin has no frontend.
-callback static_dir() -> file:filename() | none.

%% Plugin manifest: metadata, version, native capabilities.
%%
%% Required keys:
%%   name            :: binary()  - unique plugin identifier
%%   version         :: binary()  - semver string
%%   min_sdk_version :: binary()  - minimum SDK version required
%%
%% Optional keys:
%%   description          :: binary()
%%   author               :: binary()
%%   native_capabilities  :: map()  - Tauri permissions requested
%%   icon                 :: binary()  - relative path in static_dir
-callback manifest() -> map().

%% Bit flag maps for this plugin's aggregates.
%%
%% Returns a map of aggregate name (binary) to its flag map.
%% The daemon auto-mounts this at GET /plugin/{name}/api/flag-maps
%% so the frontend can decode raw status integers into labels.
%%
%% Plugins without aggregates return an empty map.
%%
%% Example:
%%   #{<<"document_aggregate">> => #{
%%       1 => <<"Draft">>,
%%       2 => <<"Published">>,
%%       4 => <<"Archived">>
%%   }}
-callback flag_maps() -> #{binary() => evoq_bit_flags:flag_map()}.
