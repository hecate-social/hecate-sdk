%%% @doc Code generation for plugin scaffolding.
%%%
%%% Generates Erlang source files from baked-in templates following
%%% hecate naming conventions and evoq behaviour patterns.
%%%
%%% Four entry points:
%%%   plugin/1    -- full plugin skeleton (root app, sup, rebar.config, manifest)
%%%   division/1  -- aggregate + state + department apps
%%%   desk/1      -- CMD, PRJ, or QRY desk with tests
%%%   integration/1 -- emitter, listener, process manager, requester, responder
%%%
%%% Templates are organized in sub-modules:
%%%   hecate_plugin_codegen_plugin      -- plugin + division templates
%%%   hecate_plugin_codegen_cmd         -- CMD desk templates
%%%   hecate_plugin_codegen_prj         -- PRJ desk templates
%%%   hecate_plugin_codegen_qry         -- QRY desk templates
%%%   hecate_plugin_codegen_integration -- integration templates
%%%
%%% All functions return {ok, [FilePath]} and are idempotent (skip existing files).
%%% @end
-module(hecate_plugin_codegen).

-export([plugin/1, division/1, desk/1, integration/1, delivery/1]).

%% Shared helpers used by template sub-modules
-export([fmt/2, s/1, b/1, write_files/1]).
-export([callback_module_name/1, app_atom_name/1, store_name/1]).
-export([subject_from_cmd/1, pluralize/1, replace_src_with_test/1]).
-export([sdk_version/0]).

-include("hecate_plugin.hrl").

%% ===================================================================
%% plugin/1 -- Full plugin skeleton
%% ===================================================================

-spec plugin(map()) -> {ok, [string()]}.
plugin(#{name := Name, display_name := DisplayName} = Opts) ->
    OutDir = maps:get(output_dir, Opts, "."),
    Tag = maps:get(tag, Opts, Name),
    Version = maps:get(version, Opts, <<"0.1.0">>),
    CallbackMod = callback_module_name(Name),
    AppAtom = app_atom_name(Name),

    Files = [
        %% Root app callback
        {filename:join([OutDir, "src", s(CallbackMod) ++ ".erl"]),
         hecate_plugin_codegen_plugin:tpl_plugin_callback(
             CallbackMod, Name, DisplayName, Version, Tag)},

        %% Root supervisor
        {filename:join([OutDir, "src", s(CallbackMod) ++ "_sup.erl"]),
         hecate_plugin_codegen_plugin:tpl_plugin_sup(CallbackMod)},

        %% Application resource file
        {filename:join([OutDir, "src", s(AppAtom) ++ ".app.src"]),
         hecate_plugin_codegen_plugin:tpl_app_src(AppAtom, s(DisplayName) ++ " plugin daemon")},

        %% rebar.config
        {filename:join([OutDir, "rebar.config"]),
         hecate_plugin_codegen_plugin:tpl_rebar_config(AppAtom)},

        %% manifest.json
        {filename:join([OutDir, "..", "manifest.json"]),
         hecate_plugin_codegen_plugin:tpl_manifest(Name, DisplayName, Version, Tag, CallbackMod)}
    ],
    write_files(Files).

%% ===================================================================
%% division/1 -- Aggregate + State + Department apps
%% ===================================================================

-spec division(map()) -> {ok, [string()]}.
division(#{subject := Subject, cmd_app := CmdApp, prj_app := PrjApp,
           qry_app := QryApp} = Opts) ->
    OutDir = maps:get(output_dir, Opts, "apps"),
    StoreId = maps:get(store_id, Opts, b(s(PrjApp) ++ "_store")),

    Flags = maps:get(flags, Opts, []),

    AggMod = s(Subject) ++ "_aggregate",
    StateMod = s(Subject) ++ "_state",
    StateHrl = s(Subject) ++ "_state.hrl",
    StatusHrl = s(Subject) ++ "_status.hrl",

    Files = [
        %% CMD app: aggregate
        {filename:join([OutDir, s(CmdApp), "src", AggMod ++ ".erl"]),
         hecate_plugin_codegen_plugin:tpl_aggregate(AggMod, StateMod, StatusHrl)},

        %% CMD app: state module
        {filename:join([OutDir, s(CmdApp), "src", StateMod ++ ".erl"]),
         hecate_plugin_codegen_plugin:tpl_state(StateMod, s(Subject))},

        %% CMD app: state header
        {filename:join([OutDir, s(CmdApp), "include", StateHrl]),
         hecate_plugin_codegen_plugin:tpl_state_hrl(StateMod, s(Subject))},

        %% CMD app: status header
        {filename:join([OutDir, s(CmdApp), "include", StatusHrl]),
         hecate_plugin_codegen_plugin:tpl_status_hrl(s(Subject), Flags)},

        %% CMD app: app.src
        {filename:join([OutDir, s(CmdApp), "src", s(CmdApp) ++ ".app.src"]),
         hecate_plugin_codegen_plugin:tpl_app_src(CmdApp, s(CmdApp) ++ " CMD department")},

        %% CMD app: supervisor
        {filename:join([OutDir, s(CmdApp), "src", s(CmdApp) ++ "_sup.erl"]),
         hecate_plugin_codegen_plugin:tpl_dept_sup(CmdApp)},

        %% PRJ app: store facade
        {filename:join([OutDir, s(PrjApp), "src", s(PrjApp) ++ "_store.erl"]),
         hecate_plugin_codegen_prj:tpl_prj_store(PrjApp, StoreId, Subject)},

        %% PRJ app: app.src
        {filename:join([OutDir, s(PrjApp), "src", s(PrjApp) ++ ".app.src"]),
         hecate_plugin_codegen_plugin:tpl_app_src(PrjApp, s(PrjApp) ++ " PRJ department")},

        %% PRJ app: supervisor
        {filename:join([OutDir, s(PrjApp), "src", s(PrjApp) ++ "_sup.erl"]),
         hecate_plugin_codegen_plugin:tpl_dept_sup(PrjApp)},

        %% QRY app: app.src
        {filename:join([OutDir, s(QryApp), "src", s(QryApp) ++ ".app.src"]),
         hecate_plugin_codegen_plugin:tpl_app_src(QryApp, s(QryApp) ++ " QRY department")},

        %% QRY app: supervisor
        {filename:join([OutDir, s(QryApp), "src", s(QryApp) ++ "_sup.erl"]),
         hecate_plugin_codegen_plugin:tpl_dept_sup(QryApp)}
    ],
    write_files(Files).

%% ===================================================================
%% desk/1 -- CMD, PRJ, or QRY desk
%% ===================================================================

-spec desk(map()) -> {ok, [string()]}.
desk(#{dept := cmd} = Opts) -> hecate_plugin_codegen_cmd:desk(Opts);
desk(#{dept := prj} = Opts) -> hecate_plugin_codegen_prj:desk(Opts);
desk(#{dept := qry} = Opts) -> hecate_plugin_codegen_qry:desk(Opts).

%% ===================================================================
%% integration/1 -- Emitter, Listener, PM, Requester, Responder
%% ===================================================================

-spec integration(map()) -> {ok, [string()]}.
integration(Opts) ->
    hecate_plugin_codegen_integration:generate(Opts).

%% ===================================================================
%% delivery/1 -- Dockerfile, CI/CD workflows, package scripts
%% ===================================================================

-spec delivery(map()) -> {ok, [string()]}.
delivery(Opts) ->
    hecate_plugin_codegen_delivery:generate(Opts).

%% ===================================================================
%% Shared Helpers
%% ===================================================================

-spec sdk_version() -> string().
sdk_version() -> ?HECATE_SDK_VERSION.

%% Write files, skip existing, create directories
-spec write_files([{string(), string()}]) -> {ok, [string()]}.
write_files(Files) ->
    Written = lists:filtermap(fun({Path, Content}) ->
        case filelib:is_regular(Path) of
            true ->
                logger:info("[codegen] Skipping existing: ~s", [Path]),
                false;
            false ->
                ok = filelib:ensure_dir(Path),
                ok = file:write_file(Path, Content),
                logger:info("[codegen] Generated: ~s", [Path]),
                {true, Path}
        end
    end, Files),
    {ok, Written}.

%% Format template string
-spec fmt(string(), [term()]) -> string().
fmt(Fmt, Args) ->
    lists:flatten(io_lib:format(Fmt, Args)).

%% Convert to string
-spec s(binary() | atom() | string()) -> string().
s(V) when is_binary(V) -> binary_to_list(V);
s(V) when is_atom(V) -> atom_to_list(V);
s(V) when is_list(V) -> V.

%% Convert to binary
-spec b(string() | binary() | atom()) -> binary().
b(V) when is_list(V) -> list_to_binary(V);
b(V) when is_binary(V) -> V;
b(V) when is_atom(V) -> atom_to_binary(V).

%% hecate-app-foo -> app_foo
-spec callback_module_name(binary() | atom() | string()) -> string().
callback_module_name(Name) ->
    Str = s(Name),
    Stripped = case lists:prefix("hecate-app-", Str) of
        true -> "app_" ++ lists:nthtail(11, Str);
        false -> Str
    end,
    re:replace(Stripped, "-", "_", [global, {return, list}]).

%% hecate-app-foo -> hecate_app_food (daemon app name)
-spec app_atom_name(binary() | atom() | string()) -> string().
app_atom_name(Name) ->
    Str = s(Name),
    Underscored = re:replace(Str, "-", "_", [global, {return, list}]),
    Underscored ++ "d".

%% foo_store name from plugin name
-spec store_name(binary() | atom() | string()) -> string().
store_name(Name) ->
    Str = s(Name),
    Stripped = case lists:prefix("hecate-app-", Str) of
        true -> lists:nthtail(11, Str);
        false -> Str
    end,
    re:replace(Stripped, "-", "_", [global, {return, list}]).

%% Extract subject from command module name: "initiate_venture_v1" -> "venture"
-spec subject_from_cmd(binary() | atom() | string()) -> string().
subject_from_cmd(CmdMod) ->
    Str = s(CmdMod),
    NoVersion = case lists:suffix("_v1", Str) of
        true -> lists:sublist(Str, length(Str) - 3);
        false -> Str
    end,
    case string:split(NoVersion, "_", leading) of
        [_Verb, Rest] -> Rest;
        _ -> NoVersion
    end.

%% Naive pluralization
-spec pluralize(string()) -> string().
pluralize(Word) ->
    case lists:suffix("s", Word) of
        true -> Word ++ "es";
        false ->
            case lists:suffix("y", Word) of
                true -> lists:sublist(Word, length(Word) - 1) ++ "ies";
                false -> Word ++ "s"
            end
    end.

%% Replace /src/ with /test/ in a path
-spec replace_src_with_test(string()) -> string().
replace_src_with_test(Path) ->
    case string:split(Path, "/src", trailing) of
        [Before, After] -> Before ++ "/test" ++ After;
        _ -> Path ++ "/../test"
    end.
