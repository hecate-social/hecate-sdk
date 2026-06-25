%%% @doc QRY desk templates for code generation.
%%%
%%% Templates for: list (page) endpoint, get-by-id endpoint, QRY tests.
%%% @end
-module(hecate_plugin_codegen_qry).

-export([desk/1]).

-import(hecate_plugin_codegen, [fmt/2, s/1, write_files/1,
    pluralize/1, replace_src_with_test/1]).

%% ===================================================================
%% desk/1 -- QRY desk entry point
%% ===================================================================

-spec desk(map()) -> {ok, [string()]}.
desk(#{subject := Subject} = Opts) ->
    OutDir = maps:get(output_dir, Opts, "src"),
    TestDir = maps:get(test_dir, Opts, replace_src_with_test(OutDir)),
    Type = maps:get(type, Opts, page),
    Plural = pluralize(s(Subject)),
    {DeskName, ApiMod, _ApiPath, Template, TestTpl} =
        qry_codegen_spec(Type, Subject, Plural),
    DeskDir = filename:join(OutDir, DeskName),

    Files = [
        {filename:join(DeskDir, ApiMod ++ ".erl"), Template()},
        {filename:join(TestDir, ApiMod ++ "_tests.erl"), TestTpl()}
    ],
    write_files(Files).

qry_codegen_spec(page, _Subject, Plural) ->
    DN = "get_" ++ Plural ++ "_page",
    AM = DN ++ "_api",
    {DN, AM, "/api/" ++ Plural,
     fun() -> tpl_qry_page_api(AM, Plural) end,
     fun() -> tpl_qry_page_tests(AM, Plural) end};
qry_codegen_spec(by_id, Subject, Plural) ->
    DN = "get_" ++ s(Subject) ++ "_by_id",
    AM = DN ++ "_api",
    {DN, AM, "/api/" ++ Plural ++ "/:id",
     fun() -> tpl_qry_by_id_api(AM, s(Subject)) end,
     fun() -> tpl_qry_by_id_tests(AM, s(Subject)) end}.

%% ===================================================================
%% Templates
%% ===================================================================

tpl_qry_page_api(ApiMod, Plural) ->
    fmt("%%% @doc API handler: GET /api/~s\n"
        "-module(~s).\n"
        "-export([init/2, routes/0]).\n"
        "\n"
        "routes() -> [{\"/api/~s\", ?MODULE, []}].\n"
        "\n"
        "init(Req0, State) ->\n"
        "    case cowboy_req:method(Req0) of\n"
        "        <<\"GET\">> -> handle_get(Req0, State);\n"
        "        _ -> hecate_plugin_api:method_not_allowed(Req0)\n"
        "    end.\n"
        "\n"
        "handle_get(Req0, _State) ->\n"
        "    QS = cowboy_req:parse_qs(Req0),\n"
        "    Filters = build_filters(QS, #{}),\n"
        "    %% TODO: Call read model query\n"
        "    hecate_plugin_api:json_ok(#{~s => [], filters => Filters}, Req0).\n"
        "\n"
        "build_filters(QS, Acc) ->\n"
        "    lists:foldl(fun parse_filter/2, Acc, QS).\n"
        "\n"
        "parse_filter({<<\"limit\">>, V}, Acc) -> maybe_int(limit, V, Acc);\n"
        "parse_filter({<<\"offset\">>, V}, Acc) -> maybe_int(offset, V, Acc);\n"
        "parse_filter(_, Acc) -> Acc.\n"
        "\n"
        "maybe_int(Key, V, Acc) ->\n"
        "    case catch binary_to_integer(V) of\n"
        "        I when is_integer(I) -> Acc#{Key => I};\n"
        "        _ -> Acc\n"
        "    end.\n",
        [Plural, ApiMod, Plural, Plural]).

tpl_qry_by_id_api(ApiMod, Subject) ->
    Plural = pluralize(Subject),
    IdField = Subject ++ "_id",
    fmt("%%% @doc API handler: GET /api/~s/:id\n"
        "-module(~s).\n"
        "-export([init/2, routes/0]).\n"
        "\n"
        "routes() -> [{\"/api/~s/:id\", ?MODULE, []}].\n"
        "\n"
        "init(Req0, State) ->\n"
        "    case cowboy_req:method(Req0) of\n"
        "        <<\"GET\">> -> handle_get(Req0, State);\n"
        "        _ -> hecate_plugin_api:method_not_allowed(Req0)\n"
        "    end.\n"
        "\n"
        "handle_get(Req0, _State) ->\n"
        "    Id = cowboy_req:binding(id, Req0),\n"
        "    %% TODO: Look up from read model\n"
        "    hecate_plugin_api:json_ok(#{~s => Id}, Req0).\n",
        [Plural, ApiMod, Plural, IdField]).

tpl_qry_page_tests(ApiMod, Plural) ->
    fmt("-module(~s_tests).\n"
        "-include_lib(\"eunit/include/eunit.hrl\").\n"
        "\n"
        "routes_test() ->\n"
        "    Routes = ~s:routes(),\n"
        "    ?assertMatch([{\"/api/~s\", _, _}], Routes).\n",
        [ApiMod, ApiMod, Plural]).

tpl_qry_by_id_tests(ApiMod, Subject) ->
    Plural = pluralize(Subject),
    fmt("-module(~s_tests).\n"
        "-include_lib(\"eunit/include/eunit.hrl\").\n"
        "\n"
        "routes_test() ->\n"
        "    Routes = ~s:routes(),\n"
        "    ?assertMatch([{\"/api/~s/:id\", _, _}], Routes).\n",
        [ApiMod, ApiMod, Plural]).
