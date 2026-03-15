%%%-------------------------------------------------------------------
%%% Shared records and macros for hecate plugins.
%%%-------------------------------------------------------------------

-ifndef(HECATE_PLUGIN_HRL).
-define(HECATE_PLUGIN_HRL, true).

%% ReckonDB store configuration for a plugin.
%%
%% - store_id:   Atom used to reference the store (e.g., documents_store)
%% - dir_name:   Directory name under the plugin's data path (e.g., "documents")
%% - description: Human-readable label for logging
%% - options:    Map of additional store options (passed to reckon_db)
-record(hecate_store_config, {
    store_id    :: atom(),
    dir_name    :: string(),
    description :: string(),
    options = #{} :: map()
}).

%% SDK version — plugins can check at compile time.
-define(HECATE_SDK_VERSION, "0.6.0").

%% -------------------------------------------------------------------
%% Metrics macros
%%
%% Usage:
%%   ?METRIC_INC(<<"api_requests">>)        — increment by 1
%%   ?METRIC_ADD(<<"bytes_sent">>, 1024)     — increment by N
%%   ?METRIC_SET(<<"queue_depth">>, Depth)   — set gauge value
%%
%% The plugin name is resolved from persistent_term at call site.
%% The plugin loader sets this when loading the plugin.
%% -------------------------------------------------------------------
-define(METRIC_INC(Name),
    hecate_plugin_metrics:counter(
        persistent_term:get(hecate_current_plugin), Name, 1)).
-define(METRIC_ADD(Name, N),
    hecate_plugin_metrics:counter(
        persistent_term:get(hecate_current_plugin), Name, N)).
-define(METRIC_SET(Name, V),
    hecate_plugin_metrics:gauge(
        persistent_term:get(hecate_current_plugin), Name, V)).

-endif.
