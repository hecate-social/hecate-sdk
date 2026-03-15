%%% @doc CMD desk templates for code generation.
%%%
%%% Templates for: command, event, handler, API handler, CMD tests.
%%% @end
-module(hecate_plugin_codegen_cmd).

-export([desk/1]).

-import(hecate_plugin_codegen, [fmt/2, s/1, b/1, write_files/1,
    pluralize/1, replace_src_with_test/1, subject_from_cmd/1]).

%% ===================================================================
%% desk/1 -- CMD desk entry point
%% ===================================================================

-spec desk(map()) -> {ok, [string()]}.
desk(#{verb := Verb, subject := Subject, past_verb := PastVerb} = Opts) ->
    OutDir = maps:get(output_dir, Opts, "src"),
    StoreId = maps:get(store_id, Opts, <<"martha_store">>),
    AggType = maps:get(aggregate_type, Opts, b(s(Subject) ++ "_aggregate")),
    DeskName = s(Verb) ++ "_" ++ s(Subject),
    CmdMod = DeskName ++ "_v1",
    EvtMod = s(Subject) ++ "_" ++ s(PastVerb) ++ "_v1",
    HandlerMod = "maybe_" ++ DeskName,
    ApiMod = DeskName ++ "_api",
    DeskDir = filename:join(OutDir, DeskName),
    TestDir = maps:get(test_dir, Opts, replace_src_with_test(OutDir)),
    ApiPath = maps:get(api_path, Opts, "/api/" ++ pluralize(s(Subject)) ++ "/" ++ s(Verb)),

    Files = [
        {filename:join(DeskDir, CmdMod ++ ".erl"),
         tpl_command(CmdMod, DeskName, Subject)},

        {filename:join(DeskDir, EvtMod ++ ".erl"),
         tpl_event(EvtMod, Subject, PastVerb)},

        {filename:join(DeskDir, HandlerMod ++ ".erl"),
         tpl_handler(HandlerMod, CmdMod, EvtMod, AggType, StoreId)},

        {filename:join(DeskDir, ApiMod ++ ".erl"),
         tpl_cmd_api(ApiMod, CmdMod, HandlerMod, ApiPath, Subject)},

        {filename:join(TestDir, DeskName ++ "_tests.erl"),
         tpl_cmd_tests(DeskName, CmdMod, EvtMod, HandlerMod)}
    ],
    write_files(Files).

%% ===================================================================
%% Templates
%% ===================================================================

tpl_command(CmdMod, DeskName, Subject) ->
    IdField = s(Subject) ++ "_id",
    fmt("%%% @doc ~s command.\n"
        "-module(~s).\n"
        "-behaviour(evoq_command).\n"
        "\n"
        "-export([command_type/0]).\n"
        "-export([new/1, from_map/1, validate/1, to_map/1]).\n"
        "-export([get_~s/1]).\n"
        "-export([generate_id/0]).\n"
        "\n"
        "-record(~s, {\n"
        "    ~s :: binary()\n"
        "    %% TODO: Add command fields\n"
        "}).\n"
        "\n"
        "-spec command_type() -> atom().\n"
        "command_type() -> ~s.\n"
        "\n"
        "-spec new(map()) -> {ok, #~s{}} | {error, term()}.\n"
        "new(Params) ->\n"
        "    Id = maps:get(~s, Params, generate_id()),\n"
        "    {ok, #~s{~s = Id}}.\n"
        "\n"
        "-spec validate(#~s{}) -> {ok, #~s{}} | {error, term()}.\n"
        "validate(#~s{} = Cmd) -> {ok, Cmd}.\n"
        "\n"
        "-spec to_map(#~s{}) -> map().\n"
        "to_map(#~s{} = Cmd) ->\n"
        "    #{command_type => ~s, ~s => Cmd#~s.~s}.\n"
        "\n"
        "-spec from_map(map()) -> {ok, #~s{}} | {error, term()}.\n"
        "from_map(Map) ->\n"
        "    Id = hecate_plugin_api:get_field(~s, Map, generate_id()),\n"
        "    {ok, #~s{~s = Id}}.\n"
        "\n"
        "get_~s(#~s{~s = V}) -> V.\n"
        "\n"
        "generate_id() ->\n"
        "    Ts = integer_to_binary(erlang:system_time(millisecond)),\n"
        "    Rand = binary:encode_hex(crypto:strong_rand_bytes(8)),\n"
        "    <<\"~s-\", Ts/binary, \"-\", Rand/binary>>.\n",
        [DeskName, CmdMod,
         IdField,
         CmdMod, IdField,
         CmdMod, CmdMod,
         IdField, CmdMod, IdField,
         CmdMod, CmdMod, CmdMod,
         CmdMod, CmdMod,
         CmdMod, IdField, CmdMod, IdField,
         CmdMod, IdField, CmdMod, IdField,
         IdField, CmdMod, IdField,
         s(Subject)]).

tpl_event(EvtMod, Subject, PastVerb) ->
    IdField = s(Subject) ++ "_id",
    fmt("%%% @doc ~s_~s event.\n"
        "-module(~s).\n"
        "-behaviour(evoq_event).\n"
        "\n"
        "-export([event_type/0]).\n"
        "-export([new/1, to_map/1, from_map/1]).\n"
        "-export([get_~s/1]).\n"
        "\n"
        "-record(~s, {\n"
        "    ~s    :: binary(),\n"
        "    ~s_at :: integer()\n"
        "    %% TODO: Add event fields\n"
        "}).\n"
        "\n"
        "-spec event_type() -> atom().\n"
        "event_type() -> ~s.\n"
        "\n"
        "-spec new(map()) -> #~s{}.\n"
        "new(#{~s := Id} = _Params) ->\n"
        "    #~s{~s = Id, ~s_at = erlang:system_time(millisecond)}.\n"
        "\n"
        "-spec to_map(#~s{}) -> map().\n"
        "to_map(#~s{} = E) ->\n"
        "    #{event_type => ~s,\n"
        "      ~s => E#~s.~s,\n"
        "      ~s_at => E#~s.~s_at}.\n"
        "\n"
        "-spec from_map(map()) -> {ok, #~s{}} | {error, term()}.\n"
        "from_map(Map) ->\n"
        "    Id = hecate_plugin_api:get_field(~s, Map),\n"
        "    case Id of\n"
        "        undefined -> {error, invalid_event};\n"
        "        _ -> {ok, #~s{\n"
        "            ~s = Id,\n"
        "            ~s_at = hecate_plugin_api:get_field(~s_at, Map,\n"
        "                erlang:system_time(millisecond))\n"
        "        }}\n"
        "    end.\n"
        "\n"
        "get_~s(#~s{~s = V}) -> V.\n",
        [s(Subject), s(PastVerb), EvtMod,
         IdField,
         EvtMod, IdField, s(PastVerb),
         EvtMod, EvtMod, IdField, EvtMod, IdField, s(PastVerb),
         EvtMod, EvtMod, EvtMod,
         IdField, EvtMod, IdField,
         s(PastVerb), EvtMod, s(PastVerb),
         EvtMod, IdField,
         EvtMod, IdField, s(PastVerb), s(PastVerb),
         IdField, EvtMod, IdField]).

tpl_handler(HandlerMod, CmdMod, EvtMod, AggType, StoreId) ->
    SubjectStr = subject_from_cmd(CmdMod),
    fmt("%%% @doc ~s handler.\n"
        "-module(~s).\n"
        "\n"
        "-include_lib(\"evoq/include/evoq.hrl\").\n"
        "\n"
        "-export([handle/1, handle/2, dispatch/1]).\n"
        "\n"
        "-spec handle(~s:~s()) ->\n"
        "    {ok, [~s:~s()]} | {error, term()}.\n"
        "handle(Cmd) -> handle(Cmd, undefined).\n"
        "\n"
        "-spec handle(~s:~s(), term()) ->\n"
        "    {ok, [~s:~s()]} | {error, term()}.\n"
        "handle(Cmd, _State) ->\n"
        "    Event = ~s:new(#{~s_id => ~s:get_~s_id(Cmd)}),\n"
        "    {ok, [Event]}.\n"
        "\n"
        "-spec dispatch(~s:~s()) ->\n"
        "    {ok, non_neg_integer(), [map()]} | {error, term()}.\n"
        "dispatch(Cmd) ->\n"
        "    Id = ~s:get_~s_id(Cmd),\n"
        "    EvoqCmd = #evoq_command{\n"
        "        command_type = ~s:command_type(),\n"
        "        aggregate_type = ~s,\n"
        "        aggregate_id = Id,\n"
        "        payload = ~s:to_map(Cmd),\n"
        "        metadata = #{timestamp => erlang:system_time(millisecond),\n"
        "                     aggregate_type => ~s}\n"
        "    },\n"
        "    evoq_dispatcher:dispatch(EvoqCmd, #{\n"
        "        store_id => ~s,\n"
        "        adapter => reckon_evoq_adapter,\n"
        "        consistency => eventual\n"
        "    }).\n",
        [HandlerMod, HandlerMod,
         CmdMod, CmdMod, EvtMod, EvtMod,
         CmdMod, CmdMod, EvtMod, EvtMod,
         EvtMod, SubjectStr, CmdMod, SubjectStr,
         CmdMod, CmdMod,
         CmdMod, SubjectStr,
         CmdMod, s(AggType), CmdMod, s(AggType),
         s(StoreId)]).

tpl_cmd_api(ApiMod, CmdMod, HandlerMod, ApiPath, Subject) ->
    IdField = s(Subject) ++ "_id",
    fmt("%%% @doc API handler: POST ~s\n"
        "-module(~s).\n"
        "-export([init/2, routes/0]).\n"
        "\n"
        "routes() -> [{\"~s\", ?MODULE, []}].\n"
        "\n"
        "init(Req0, State) ->\n"
        "    case cowboy_req:method(Req0) of\n"
        "        <<\"POST\">> -> handle_post(Req0, State);\n"
        "        _ -> hecate_plugin_api:method_not_allowed(Req0)\n"
        "    end.\n"
        "\n"
        "handle_post(Req0, _State) ->\n"
        "    case hecate_plugin_api:read_json_body(Req0) of\n"
        "        {ok, Params, Req1} -> do_command(Params, Req1);\n"
        "        {error, invalid_json, Req1} ->\n"
        "            hecate_plugin_api:bad_request(<<\"Invalid JSON\">>, Req1)\n"
        "    end.\n"
        "\n"
        "do_command(Params, Req) ->\n"
        "    case ~s:from_map(Params) of\n"
        "        {ok, Cmd} ->\n"
        "            case ~s:dispatch(Cmd) of\n"
        "                {ok, Version, Events} ->\n"
        "                    hecate_plugin_api:json_ok(201, #{\n"
        "                        ~s => ~s:get_~s(Cmd),\n"
        "                        version => Version,\n"
        "                        events => Events\n"
        "                    }, Req);\n"
        "                {error, Reason} ->\n"
        "                    hecate_plugin_api:bad_request(Reason, Req)\n"
        "            end;\n"
        "        {error, Reason} ->\n"
        "            hecate_plugin_api:bad_request(Reason, Req)\n"
        "    end.\n",
        [ApiPath, ApiMod, ApiPath,
         CmdMod, HandlerMod,
         IdField, CmdMod, IdField]).

tpl_cmd_tests(DeskName, CmdMod, EvtMod, HandlerMod) ->
    SubjectStr = subject_from_cmd(CmdMod),
    fmt("-module(~s_tests).\n"
        "-include_lib(\"eunit/include/eunit.hrl\").\n"
        "\n"
        "%% ===================================================================\n"
        "%% Command tests\n"
        "%% ===================================================================\n"
        "\n"
        "new_command_test() ->\n"
        "    {ok, Cmd} = ~s:new(#{}),\n"
        "    ?assert(is_binary(~s:get_~s_id(Cmd))).\n"
        "\n"
        "to_map_roundtrip_test() ->\n"
        "    {ok, Cmd} = ~s:new(#{}),\n"
        "    Map = ~s:to_map(Cmd),\n"
        "    {ok, Cmd2} = ~s:from_map(Map),\n"
        "    ?assertEqual(~s:get_~s_id(Cmd), ~s:get_~s_id(Cmd2)).\n"
        "\n"
        "validate_test() ->\n"
        "    {ok, Cmd} = ~s:new(#{}),\n"
        "    ?assertMatch({ok, _}, ~s:validate(Cmd)).\n"
        "\n"
        "%% ===================================================================\n"
        "%% Handler tests\n"
        "%% ===================================================================\n"
        "\n"
        "handle_returns_event_test() ->\n"
        "    {ok, Cmd} = ~s:new(#{}),\n"
        "    {ok, Events} = ~s:handle(Cmd),\n"
        "    ?assertEqual(1, length(Events)).\n"
        "\n"
        "event_has_correct_type_test() ->\n"
        "    {ok, Cmd} = ~s:new(#{}),\n"
        "    {ok, [Event]} = ~s:handle(Cmd),\n"
        "    Map = ~s:to_map(Event),\n"
        "    ?assertEqual(~s, maps:get(event_type, Map)).\n",
        [DeskName,
         CmdMod, CmdMod, SubjectStr,
         CmdMod, CmdMod, CmdMod,
         CmdMod, SubjectStr, CmdMod, SubjectStr,
         CmdMod, CmdMod,
         CmdMod, HandlerMod,
         CmdMod, HandlerMod, EvtMod, EvtMod]).
