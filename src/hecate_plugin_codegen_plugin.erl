%%% @doc Plugin and division templates for code generation.
%%%
%%% Templates for: plugin callback, supervisor, app.src, rebar.config,
%%% manifest.json, aggregate, state, state/status headers, department supervisor.
%%% @end
-module(hecate_plugin_codegen_plugin).

-export([tpl_plugin_callback/5, tpl_plugin_sup/1]).
-export([tpl_app_src/2, tpl_rebar_config/1, tpl_manifest/5]).
-export([tpl_aggregate/3, tpl_state/2, tpl_state_hrl/2, tpl_status_hrl/1, tpl_status_hrl/2]).
-export([tpl_dept_sup/1]).

-import(hecate_plugin_codegen, [fmt/2, s/1, sdk_version/0, store_name/1]).

%% ===================================================================
%% Plugin Templates
%% ===================================================================

tpl_plugin_callback(Mod, Name, DisplayName, Version, Tag) ->
    SdkVsn = sdk_version(),
    fmt("%%% @doc ~s plugin callback module.\n"
        "-module(~s).\n"
        "-behaviour(hecate_plugin).\n"
        "\n"
        "-include_lib(\"hecate_sdk/include/hecate_plugin.hrl\").\n"
        "\n"
        "-export([init/1, routes/0, store_config/0, static_dir/0, manifest/0, flag_maps/0]).\n"
        "-export([health/0]).\n"
        "\n"
        "-define(DOMAIN_APPS, [\n"
        "    %% TODO: Add domain apps here\n"
        "]).\n"
        "\n"
        "-spec init(map()) -> {ok, map()} | {error, term()}.\n"
        "init(#{plugin_name := PluginName, store_id := StoreId, data_dir := DataDir}) ->\n"
        "    persistent_term:put(~s_config, #{\n"
        "        plugin_name => PluginName,\n"
        "        store_id => StoreId,\n"
        "        data_dir => DataDir\n"
        "    }),\n"
        "    persistent_term:put(hecate_current_plugin, PluginName),\n"
        "    lists:foreach(fun(App) -> application:load(App) end, ?DOMAIN_APPS),\n"
        "    case ~s_sup:start_link() of\n"
        "        {ok, Pid} -> {ok, #{sup_pid => Pid}};\n"
        "        {error, {already_started, Pid}} -> {ok, #{sup_pid => Pid}};\n"
        "        {error, Reason} -> {error, Reason}\n"
        "    end.\n"
        "\n"
        "-spec routes() -> [{string(), module(), term()}].\n"
        "routes() ->\n"
        "    [hecate_plugin_routes:strip_api_prefix(R)\n"
        "     || R <- hecate_plugin_routes:discover_routes(?DOMAIN_APPS)].\n"
        "\n"
        "-spec store_config() -> #hecate_store_config{}.\n"
        "store_config() ->\n"
        "    #hecate_store_config{\n"
        "        store_id = ~s_store,\n"
        "        dir_name = \"~s\",\n"
        "        description = \"~s event store\"\n"
        "    }.\n"
        "\n"
        "-spec static_dir() -> string() | none.\n"
        "static_dir() -> \"priv/static\".\n"
        "\n"
        "-spec manifest() -> map().\n"
        "manifest() ->\n"
        "    #{\n"
        "        name => <<\"~s\">>,\n"
        "        display_name => <<\"~s\">>,\n"
        "        version => <<\"~s\">>,\n"
        "        description => <<\"~s plugin\">>,\n"
        "        tag => <<\"~s\">>,\n"
        "        min_sdk_version => <<\"~s\">>\n"
        "    }.\n"
        "\n"
        "-spec flag_maps() -> #{binary() => evoq_bit_flags:flag_map()}.\n"
        "flag_maps() -> #{}.\n"
        "\n"
        "-spec health() -> ok | degraded | {unhealthy, binary()}.\n"
        "health() ->\n"
        "    case is_pid(whereis(~s_sup)) of\n"
        "        true -> ok;\n"
        "        false -> {unhealthy, <<\"supervision tree down\">>}\n"
        "    end.\n",
        [s(DisplayName), s(Mod),
         s(Mod), s(Mod),
         store_name(Name), store_name(Name), s(DisplayName),
         s(Name), s(DisplayName), s(Version), s(DisplayName), s(Tag),
         SdkVsn,
         s(Mod)]).

tpl_plugin_sup(Mod) ->
    SupMod = s(Mod) ++ "_sup",
    fmt("%%% @doc Top-level supervisor for ~s plugin.\n"
        "-module(~s).\n"
        "-behaviour(supervisor).\n"
        "\n"
        "-export([start_link/0, init/1]).\n"
        "\n"
        "start_link() ->\n"
        "    supervisor:start_link({local, ?MODULE}, ?MODULE, []).\n"
        "\n"
        "init([]) ->\n"
        "    SupFlags = #{strategy => one_for_one, intensity => 10, period => 60},\n"
        "    Children = [\n"
        "        %% TODO: Add department supervisors here\n"
        "        %% child(my_cmd_app_sup),\n"
        "        %% child(my_prj_app_sup),\n"
        "        %% child(my_qry_app_sup)\n"
        "    ],\n"
        "    {ok, {SupFlags, Children}}.\n"
        "\n"
        "child(Mod) ->\n"
        "    #{id => Mod, start => {Mod, start_link, []},\n"
        "      restart => permanent, type => supervisor}.\n",
        [s(Mod), SupMod]).

%% ===================================================================
%% Division Templates
%% ===================================================================

tpl_aggregate(AggMod, StateMod, StatusHrl) ->
    fmt("%%% @doc ~s aggregate.\n"
        "-module(~s).\n"
        "-behaviour(evoq_aggregate).\n"
        "\n"
        "-include(\"~s\").\n"
        "-include(\"~s\").\n"
        "\n"
        "-export([state_module/0, init/1, execute/2, apply/2]).\n"
        "\n"
        "-type state() :: #~s{}.\n"
        "\n"
        "-spec state_module() -> module().\n"
        "state_module() -> ~s.\n"
        "\n"
        "-spec init(binary()) -> {ok, state()}.\n"
        "init(AggregateId) ->\n"
        "    {ok, ~s:new(AggregateId)}.\n"
        "\n"
        "%% NOTE: evoq calls execute(State, Payload) - State FIRST!\n"
        "-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.\n"
        "execute(#~s{status = 0}, Payload) ->\n"
        "    %% Fresh aggregate -- only initiate allowed\n"
        "    case maps:get(command_type, Payload, undefined) of\n"
        "        %% TODO: Match initiate command\n"
        "        _ -> {error, not_initiated}\n"
        "    end;\n"
        "execute(#~s{}, _Payload) ->\n"
        "    %% TODO: Route commands by type\n"
        "    {error, unknown_command}.\n"
        "\n"
        "-spec apply(state(), map()) -> state().\n"
        "apply(State, Event) ->\n"
        "    ~s:apply_event(State, Event).\n",
        [AggMod, AggMod,
         StatusHrl, StateMod ++ ".hrl",
         StateMod, StateMod, StateMod,
         StateMod, StateMod, StateMod]).

tpl_state(StateMod, Subject) ->
    RecName = Subject ++ "_state",
    fmt("%%% @doc ~s state module.\n"
        "-module(~s).\n"
        "-behaviour(evoq_state).\n"
        "\n"
        "-include(\"~s.hrl\").\n"
        "\n"
        "-export([new/1, apply_event/2]).\n"
        "\n"
        "-spec new(binary()) -> #~s{}.\n"
        "new(Id) ->\n"
        "    #~s{id = Id, status = 0}.\n"
        "\n"
        "-spec apply_event(#~s{}, map()) -> #~s{}.\n"
        "apply_event(State, #{event_type := EventType} = Data) ->\n"
        "    do_apply(EventType, Data, State);\n"
        "apply_event(State, #{<<\"event_type\">> := EventType} = Data) ->\n"
        "    do_apply(EventType, Data, State);\n"
        "apply_event(State, _) ->\n"
        "    State.\n"
        "\n"
        "do_apply(_EventType, _Data, State) ->\n"
        "    %% TODO: Handle events and update state\n"
        "    State.\n",
        [StateMod, StateMod, StateMod,
         RecName, RecName, RecName, RecName]).

tpl_state_hrl(_StateMod, Subject) ->
    RecName = Subject ++ "_state",
    Guard = string:uppercase(RecName ++ "_hrl"),
    fmt("-ifndef(~s).\n"
        "-define(~s, true).\n"
        "\n"
        "-record(~s, {\n"
        "    id     :: binary(),\n"
        "    status = 0 :: non_neg_integer()\n"
        "    %% TODO: Add state fields\n"
        "}).\n"
        "\n"
        "-endif.\n",
        [Guard, Guard, RecName]).

tpl_status_hrl(Subject) ->
    tpl_status_hrl(Subject, []).

tpl_status_hrl(Subject, []) ->
    tpl_status_hrl(Subject, [{<<"INITIATED">>, 1}, {<<"ARCHIVED">>, 2}]);
tpl_status_hrl(Subject, Flags) ->
    Prefix = string:uppercase(string:slice(Subject, 0, 2)),
    Guard = string:uppercase(Subject ++ "_status_hrl"),
    Defines = lists:map(fun({Name, Val}) ->
        FlagName = s(Name),
        fmt("-define(~s_~s, ~b).  %% 2^~b\n",
            [Prefix, FlagName, Val, trunc(math:log2(Val))])
    end, Flags),
    MapEntries = lists:map(fun({Name, _Val}) ->
        FlagName = s(Name),
        LowerName = string:lowercase(FlagName),
        fmt("    ?~s_~s => <<\"~s\">>", [Prefix, FlagName, LowerName])
    end, Flags),
    MapBody = string:join(MapEntries, ",\n"),
    fmt("-ifndef(~s).\n"
        "-define(~s, true).\n"
        "\n"
        "%% Bit flag definitions for ~s status\n"
        "~s"
        "\n"
        "-define(~s_FLAG_MAP, #{\n"
        "~s\n"
        "}).\n"
        "\n"
        "-endif.\n",
        [Guard, Guard, Subject,
         lists:flatten(Defines), Prefix, MapBody]).

%% ===================================================================
%% Shared Templates (app.src, dept_sup, rebar.config, manifest)
%% ===================================================================

tpl_app_src(AppName, Desc) ->
    fmt("{application, ~s, [\n"
        "    {description, \"~s\"},\n"
        "    {vsn, \"0.1.0\"},\n"
        "    {registered, []},\n"
        "    {applications, [kernel, stdlib]},\n"
        "    {env, []}\n"
        "]}.\n",
        [s(AppName), Desc]).

tpl_dept_sup(AppName) ->
    SupMod = s(AppName) ++ "_sup",
    fmt("%%% @doc ~s department supervisor.\n"
        "-module(~s).\n"
        "-behaviour(supervisor).\n"
        "\n"
        "-export([start_link/0, init/1]).\n"
        "\n"
        "start_link() ->\n"
        "    supervisor:start_link({local, ?MODULE}, ?MODULE, []).\n"
        "\n"
        "init([]) ->\n"
        "    {ok, {#{strategy => one_for_one, intensity => 10, period => 60}, []}}.\n",
        [s(AppName), SupMod]).

tpl_rebar_config(AppAtom) ->
    SdkVsn = sdk_version(),
    fmt("{erl_opts, [\n"
        "    debug_info,\n"
        "    warnings_as_errors\n"
        "]}.\n"
        "\n"
        "{deps, [\n"
        "    {hecate_sdk, \"~s\"}\n"
        "]}.\n"
        "\n"
        "{relx, [\n"
        "    {release, {~s, \"0.1.0\"}, [\n"
        "        ~s,\n"
        "        sasl\n"
        "    ]},\n"
        "    {mode, dev},\n"
        "    {dev_mode, true},\n"
        "    {include_erts, false},\n"
        "    {extended_start_script, true},\n"
        "    {sys_config, \"config/sys.config\"},\n"
        "    {vm_args, \"config/vm.args\"}\n"
        "]}.\n"
        "\n"
        "{profiles, [\n"
        "    {prod, [{relx, [{mode, prod}, {dev_mode, false}, {include_erts, true}]}]},\n"
        "    {test, [{deps, [{meck, \"0.9.2\"}]}]}\n"
        "]}.\n"
        "\n"
        "{project_plugins, [rebar3_ex_doc]}.\n",
        [SdkVsn, s(AppAtom), s(AppAtom)]).

tpl_manifest(Name, DisplayName, Version, Tag, CallbackMod) ->
    SdkVsn = sdk_version(),
    fmt("{\n"
        "  \"name\": \"~s\",\n"
        "  \"display_name\": \"~s\",\n"
        "  \"version\": \"~s\",\n"
        "  \"description\": \"~s plugin\",\n"
        "  \"tag\": \"~s\",\n"
        "  \"callback_module\": \"~s\",\n"
        "  \"plugin_type\": \"in_vm\",\n"
        "  \"min_sdk_version\": \"~s\"\n"
        "}\n",
        [s(Name), s(DisplayName), s(Version), s(DisplayName),
         s(Tag), s(CallbackMod), SdkVsn]).
