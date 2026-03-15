%%% @doc PRJ desk templates for code generation.
%%%
%%% Templates for: projection, read model store, PRJ tests.
%%% @end
-module(hecate_plugin_codegen_prj).

-export([desk/1]).
-export([tpl_prj_store/3]).

-import(hecate_plugin_codegen, [fmt/2, s/1, write_files/1,
    pluralize/1, replace_src_with_test/1]).

%% ===================================================================
%% desk/1 -- PRJ desk entry point
%% ===================================================================

-spec desk(map()) -> {ok, [string()]}.
desk(#{event := Event, target := Target} = Opts) ->
    OutDir = maps:get(output_dir, Opts, "src"),
    TestDir = maps:get(test_dir, Opts, replace_src_with_test(OutDir)),
    DeskName = s(Event),
    PrjMod = s(Event) ++ "_v1_to_" ++ s(Target),
    TableAtom = s(Target),
    DeskDir = filename:join(OutDir, DeskName),

    Files = [
        {filename:join(DeskDir, PrjMod ++ ".erl"),
         tpl_projection(PrjMod, Event, Target, TableAtom)},

        {filename:join(TestDir, PrjMod ++ "_tests.erl"),
         tpl_prj_tests(PrjMod, Event)}
    ],
    write_files(Files).

%% ===================================================================
%% Templates
%% ===================================================================

tpl_projection(PrjMod, Event, _Target, TableAtom) ->
    EventBin = s(Event) ++ "_v1",
    fmt("%%% @doc Projection: ~s events -> ~s ETS table.\n"
        "-module(~s).\n"
        "-behaviour(evoq_projection).\n"
        "\n"
        "-export([interested_in/0, init/1, project/4]).\n"
        "\n"
        "-define(TABLE, ~s).\n"
        "\n"
        "interested_in() ->\n"
        "    [<<\"~s\">>].\n"
        "\n"
        "init(_Config) ->\n"
        "    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),\n"
        "    {ok, #{}, RM}.\n"
        "\n"
        "project(#{data := Data} = _Event, _Metadata, State, RM) ->\n"
        "    Id = gf(id, Data),\n"
        "    Record = #{id => Id},\n"
        "    %% TODO: Extract fields from Data into Record\n"
        "    {ok, RM2} = evoq_read_model:put(Id, Record, RM),\n"
        "    {ok, State, RM2}.\n"
        "\n"
        "gf(Key, Map) -> hecate_plugin_api:get_field(Key, Map).\n",
        [s(Event), TableAtom, PrjMod, TableAtom, EventBin]).

tpl_prj_store(PrjApp, _StoreId, Subject) ->
    Plural = pluralize(s(Subject)),
    TableAtom = Plural,
    fmt("%%% @doc Read model store for ~s.\n"
        "-module(~s_store).\n"
        "\n"
        "-export([create_tables/0]).\n"
        "-export([get_all/0, get_by_id/1]).\n"
        "\n"
        "-define(TABLE, ~s).\n"
        "\n"
        "create_tables() ->\n"
        "    ets:new(?TABLE, [named_table, set, public, {read_concurrency, true}]).\n"
        "\n"
        "get_all() ->\n"
        "    ets:tab2list(?TABLE).\n"
        "\n"
        "get_by_id(Id) ->\n"
        "    case ets:lookup(?TABLE, Id) of\n"
        "        [{_, V}] -> {ok, V};\n"
        "        [] -> {error, not_found}\n"
        "    end.\n",
        [s(PrjApp), s(PrjApp), TableAtom]).

tpl_prj_tests(PrjMod, Event) ->
    fmt("-module(~s_tests).\n"
        "-include_lib(\"eunit/include/eunit.hrl\").\n"
        "\n"
        "interested_in_test() ->\n"
        "    Events = ~s:interested_in(),\n"
        "    ?assert(lists:member(<<\"~s_v1\">>, Events)).\n",
        [PrjMod, PrjMod, s(Event)]).
