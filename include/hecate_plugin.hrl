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
-define(HECATE_SDK_VERSION, "0.1.0").

-endif.
