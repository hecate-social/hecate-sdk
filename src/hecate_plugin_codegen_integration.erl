%%% @doc Integration templates for code generation.
%%%
%%% Templates for: emitter, listener, process manager, requester, responder.
%%% Each includes a worker supervisor.
%%% @end
-module(hecate_plugin_codegen_integration).

-export([generate/1]).

-import(hecate_plugin_codegen, [fmt/2, s/1, write_files/1]).

%% ===================================================================
%% generate/1 -- Dispatch by integration type
%% ===================================================================

-spec generate(map()) -> {ok, [string()]}.
generate(#{type := emitter} = Opts) -> emitter(Opts);
generate(#{type := listener} = Opts) -> listener(Opts);
generate(#{type := process_manager} = Opts) -> process_manager(Opts);
generate(#{type := requester} = Opts) -> requester(Opts);
generate(#{type := responder} = Opts) -> responder(Opts).

%% ===================================================================
%% Entry Points
%% ===================================================================

emitter(#{event := Event, target := Target} = Opts) ->
    OutDir = maps:get(output_dir, Opts, "src"),
    TargetStr = atom_to_list(Target),
    ModName = s(Event) ++ "_v1_to_" ++ TargetStr,
    DeskDir = filename:join(OutDir, ModName),
    Files = [
        {filename:join(DeskDir, ModName ++ ".erl"),
         tpl_emitter(ModName, Event, Target)}
    ],
    write_files(Files).

listener(#{fact := Fact} = Opts) ->
    OutDir = maps:get(output_dir, Opts, "src"),
    ModName = s(Fact) ++ "_listener",
    DeskDir = filename:join(OutDir, ModName),
    Files = [
        {filename:join(DeskDir, ModName ++ ".erl"),
         tpl_listener(ModName, Fact)},
        {filename:join(DeskDir, ModName ++ "_sup.erl"),
         tpl_worker_sup(ModName)}
    ],
    write_files(Files).

process_manager(#{source_event := SourceEvent, verb := Verb, subject := Subject} = Opts) ->
    OutDir = maps:get(output_dir, Opts, "src"),
    ModName = "on_" ++ s(SourceEvent) ++ "_" ++ s(Verb) ++ "_" ++ s(Subject),
    DeskDir = filename:join(OutDir, ModName),
    Files = [
        {filename:join(DeskDir, ModName ++ ".erl"),
         tpl_process_manager(ModName, SourceEvent, Verb, Subject)},
        {filename:join(DeskDir, ModName ++ "_sup.erl"),
         tpl_worker_sup(ModName)}
    ],
    write_files(Files).

requester(#{hope := Hope} = Opts) ->
    OutDir = maps:get(output_dir, Opts, "src"),
    ModName = s(Hope) ++ "_requester",
    DeskDir = filename:join(OutDir, ModName),
    Files = [
        {filename:join(DeskDir, ModName ++ ".erl"),
         tpl_requester(ModName, Hope)},
        {filename:join(DeskDir, ModName ++ "_sup.erl"),
         tpl_worker_sup(ModName)}
    ],
    write_files(Files).

responder(#{hope := Hope} = Opts) ->
    OutDir = maps:get(output_dir, Opts, "src"),
    ModName = s(Hope) ++ "_responder",
    DeskDir = filename:join(OutDir, ModName),
    Files = [
        {filename:join(DeskDir, ModName ++ ".erl"),
         tpl_responder(ModName, Hope)},
        {filename:join(DeskDir, ModName ++ "_sup.erl"),
         tpl_worker_sup(ModName)}
    ],
    write_files(Files).

%% ===================================================================
%% Templates
%% ===================================================================

tpl_emitter(ModName, Event, Target) ->
    TargetMod = case Target of
        pg -> "pg";
        mesh -> "hecate_mesh"
    end,
    fmt("%%% @doc Emitter: ~s_v1 -> ~p\n"
        "-module(~s).\n"
        "-behaviour(evoq_emitter).\n"
        "\n"
        "-export([start_link/0, init/1, handle_event/3]).\n"
        "\n"
        "start_link() ->\n"
        "    evoq_emitter:start_link(?MODULE, []).\n"
        "\n"
        "init(_Args) ->\n"
        "    {ok, #{store_id => undefined, events => [<<\"~s_v1\">>]}}.\n"
        "\n"
        "handle_event(Event, _Metadata, State) ->\n"
        "    %% TODO: Publish to ~s\n"
        "    logger:info(\"[~s] Emitting event\"),\n"
        "    {ok, State}.\n",
        [s(Event), Target, ModName, s(Event), TargetMod, ModName]).

tpl_listener(ModName, Fact) ->
    fmt("%%% @doc Listener: ~s facts from mesh\n"
        "-module(~s).\n"
        "-behaviour(evoq_listener).\n"
        "\n"
        "-export([start_link/0, init/1, handle_fact/3]).\n"
        "\n"
        "start_link() ->\n"
        "    evoq_listener:start_link(?MODULE, []).\n"
        "\n"
        "init(_Args) ->\n"
        "    {ok, #{topics => [<<\"~s\">>]}}.\n"
        "\n"
        "handle_fact(Fact, _Metadata, State) ->\n"
        "    %% TODO: Convert fact to command, dispatch\n"
        "    logger:info(\"[~s] Received fact: ~~p\", [Fact]),\n"
        "    {ok, State}.\n",
        [s(Fact), ModName, s(Fact), ModName]).

tpl_process_manager(ModName, SourceEvent, Verb, Subject) ->
    fmt("%%% @doc Process manager: on ~s -> ~s ~s\n"
        "-module(~s).\n"
        "-behaviour(evoq_process_manager).\n"
        "\n"
        "-export([start_link/0, init/1, interested_in/0, handle_event/3]).\n"
        "\n"
        "start_link() ->\n"
        "    evoq_process_manager:start_link(?MODULE, []).\n"
        "\n"
        "init(_Args) ->\n"
        "    {ok, #{}}.\n"
        "\n"
        "interested_in() ->\n"
        "    [<<\"~s_v1\">>].\n"
        "\n"
        "handle_event(Event, _Metadata, State) ->\n"
        "    %% TODO: Extract data from source event,\n"
        "    %% construct and dispatch target command\n"
        "    logger:info(\"[~s] Handling ~s\", []),\n"
        "    {ok, State}.\n",
        [s(SourceEvent), s(Verb), s(Subject), ModName,
         s(SourceEvent), ModName, s(SourceEvent)]).

tpl_requester(ModName, Hope) ->
    fmt("%%% @doc Requester: sends ~s hopes via RPC\n"
        "-module(~s).\n"
        "-behaviour(evoq_requester).\n"
        "\n"
        "-export([start_link/0, init/1, request/2, handle_feedback/3]).\n"
        "\n"
        "start_link() ->\n"
        "    evoq_requester:start_link(?MODULE, []).\n"
        "\n"
        "init(_Args) ->\n"
        "    {ok, #{}}.\n"
        "\n"
        "request(Params, State) ->\n"
        "    Hope = #{type => <<\"~s\">>, payload => Params},\n"
        "    {ok, Hope, State}.\n"
        "\n"
        "handle_feedback(Feedback, _Metadata, State) ->\n"
        "    logger:info(\"[~s] Got feedback: ~~p\", [Feedback]),\n"
        "    {ok, State}.\n",
        [s(Hope), ModName, s(Hope), ModName]).

tpl_responder(ModName, Hope) ->
    fmt("%%% @doc Responder: handles ~s hopes\n"
        "-module(~s).\n"
        "-behaviour(evoq_responder).\n"
        "\n"
        "-export([start_link/0, init/1, handle_hope/3]).\n"
        "\n"
        "start_link() ->\n"
        "    evoq_responder:start_link(?MODULE, []).\n"
        "\n"
        "init(_Args) ->\n"
        "    {ok, #{hopes => [<<\"~s\">>]}}.\n"
        "\n"
        "handle_hope(Hope, _Metadata, State) ->\n"
        "    %% TODO: Dispatch command, return feedback\n"
        "    logger:info(\"[~s] Handling hope: ~~p\", [Hope]),\n"
        "    {ok, #{status => <<\"ok\">>}, State}.\n",
        [s(Hope), ModName, s(Hope), ModName]).

%% Shared worker supervisor template
tpl_worker_sup(WorkerMod) ->
    SupMod = WorkerMod ++ "_sup",
    fmt("%%% @doc Supervisor for ~s.\n"
        "-module(~s).\n"
        "-behaviour(supervisor).\n"
        "\n"
        "-export([start_link/0, init/1]).\n"
        "\n"
        "start_link() ->\n"
        "    supervisor:start_link({local, ?MODULE}, ?MODULE, []).\n"
        "\n"
        "init([]) ->\n"
        "    Child = #{id => ~s, start => {~s, start_link, []},\n"
        "              restart => permanent, type => worker},\n"
        "    {ok, {#{strategy => one_for_one, intensity => 5, period => 60}, [Child]}}.\n",
        [WorkerMod, SupMod, WorkerMod, WorkerMod]).
