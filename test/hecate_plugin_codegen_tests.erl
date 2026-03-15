-module(hecate_plugin_codegen_tests).
-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% Helpers
%% ===================================================================

helpers_s_test() ->
    ?assertEqual("foo", hecate_plugin_codegen:s(<<"foo">>)),
    ?assertEqual("bar", hecate_plugin_codegen:s(bar)),
    ?assertEqual("baz", hecate_plugin_codegen:s("baz")).

helpers_b_test() ->
    ?assertEqual(<<"foo">>, hecate_plugin_codegen:b("foo")),
    ?assertEqual(<<"bar">>, hecate_plugin_codegen:b(<<"bar">>)),
    ?assertEqual(<<"baz">>, hecate_plugin_codegen:b(baz)).

callback_module_name_test() ->
    ?assertEqual("app_martha", hecate_plugin_codegen:callback_module_name(<<"hecate-app-martha">>)),
    ?assertEqual("my_plugin", hecate_plugin_codegen:callback_module_name(<<"my-plugin">>)).

app_atom_name_test() ->
    ?assertEqual("hecate_app_marthad", hecate_plugin_codegen:app_atom_name(<<"hecate-app-martha">>)).

store_name_test() ->
    ?assertEqual("martha", hecate_plugin_codegen:store_name(<<"hecate-app-martha">>)),
    ?assertEqual("foo", hecate_plugin_codegen:store_name(<<"foo">>)).

subject_from_cmd_test() ->
    ?assertEqual("venture", hecate_plugin_codegen:subject_from_cmd("initiate_venture_v1")),
    ?assertEqual("division", hecate_plugin_codegen:subject_from_cmd(<<"design_division_v1">>)).

pluralize_test() ->
    ?assertEqual("ventures", hecate_plugin_codegen:pluralize("venture")),
    ?assertEqual("categories", hecate_plugin_codegen:pluralize("category")),
    ?assertEqual("statuses", hecate_plugin_codegen:pluralize("status")).

replace_src_with_test_test() ->
    ?assertEqual("apps/foo/test", hecate_plugin_codegen:replace_src_with_test("apps/foo/src")).

%% ===================================================================
%% plugin/1 -- generates files to a temp dir
%% ===================================================================

plugin_generates_files_test() ->
    Dir = make_temp_dir("plugin"),
    DaemonDir = filename:join(Dir, "daemon"),
    ok = filelib:ensure_dir(filename:join(DaemonDir, "x")),
    {ok, Files} = hecate_plugin_codegen:plugin(#{
        name => <<"hecate-app-test">>,
        display_name => <<"Test">>,
        output_dir => DaemonDir
    }),
    ?assert(length(Files) > 0),
    %% Check that files exist on disk
    lists:foreach(fun(F) -> ?assert(filelib:is_regular(F)) end, Files),
    %% Idempotent -- second call generates nothing
    {ok, []} = hecate_plugin_codegen:plugin(#{
        name => <<"hecate-app-test">>,
        display_name => <<"Test">>,
        output_dir => DaemonDir
    }),
    cleanup_temp_dir(Dir).

%% ===================================================================
%% desk/1 CMD -- generates command desk
%% ===================================================================

cmd_desk_generates_files_test() ->
    Dir = make_temp_dir("cmd"),
    SrcDir = filename:join(Dir, "src"),
    TestDir = filename:join(Dir, "test"),
    ok = filelib:ensure_dir(filename:join(SrcDir, "x")),
    ok = filelib:ensure_dir(filename:join(TestDir, "x")),
    {ok, Files} = hecate_plugin_codegen:desk(#{
        dept => cmd,
        verb => <<"initiate">>,
        subject => <<"venture">>,
        past_verb => <<"initiated">>,
        output_dir => SrcDir,
        test_dir => TestDir
    }),
    ?assertEqual(5, length(Files)),
    cleanup_temp_dir(Dir).

%% ===================================================================
%% desk/1 PRJ -- generates projection desk
%% ===================================================================

prj_desk_generates_files_test() ->
    Dir = make_temp_dir("prj"),
    SrcDir = filename:join(Dir, "src"),
    TestDir = filename:join(Dir, "test"),
    ok = filelib:ensure_dir(filename:join(SrcDir, "x")),
    ok = filelib:ensure_dir(filename:join(TestDir, "x")),
    {ok, Files} = hecate_plugin_codegen:desk(#{
        dept => prj,
        event => <<"venture_initiated">>,
        target => <<"ventures">>,
        output_dir => SrcDir,
        test_dir => TestDir
    }),
    ?assertEqual(2, length(Files)),
    cleanup_temp_dir(Dir).

%% ===================================================================
%% desk/1 QRY -- generates query desk
%% ===================================================================

qry_page_desk_generates_files_test() ->
    Dir = make_temp_dir("qry_page"),
    SrcDir = filename:join(Dir, "src"),
    TestDir = filename:join(Dir, "test"),
    ok = filelib:ensure_dir(filename:join(SrcDir, "x")),
    ok = filelib:ensure_dir(filename:join(TestDir, "x")),
    {ok, Files} = hecate_plugin_codegen:desk(#{
        dept => qry,
        subject => <<"venture">>,
        type => page,
        output_dir => SrcDir,
        test_dir => TestDir
    }),
    ?assertEqual(2, length(Files)),
    cleanup_temp_dir(Dir).

qry_by_id_desk_generates_files_test() ->
    Dir = make_temp_dir("qry_byid"),
    SrcDir = filename:join(Dir, "src"),
    TestDir = filename:join(Dir, "test"),
    ok = filelib:ensure_dir(filename:join(SrcDir, "x")),
    ok = filelib:ensure_dir(filename:join(TestDir, "x")),
    {ok, Files} = hecate_plugin_codegen:desk(#{
        dept => qry,
        subject => <<"venture">>,
        type => by_id,
        output_dir => SrcDir,
        test_dir => TestDir
    }),
    ?assertEqual(2, length(Files)),
    cleanup_temp_dir(Dir).

%% ===================================================================
%% integration/1 -- generates integration files
%% ===================================================================

integration_emitter_test() ->
    Dir = make_temp_dir("emitter"),
    SrcDir = filename:join(Dir, "src"),
    ok = filelib:ensure_dir(filename:join(SrcDir, "x")),
    {ok, Files} = hecate_plugin_codegen:integration(#{
        type => emitter,
        event => <<"venture_initiated">>,
        target => mesh,
        output_dir => SrcDir
    }),
    ?assertEqual(1, length(Files)),
    cleanup_temp_dir(Dir).

integration_listener_test() ->
    Dir = make_temp_dir("listener"),
    SrcDir = filename:join(Dir, "src"),
    ok = filelib:ensure_dir(filename:join(SrcDir, "x")),
    {ok, Files} = hecate_plugin_codegen:integration(#{
        type => listener,
        fact => <<"capability_available">>,
        output_dir => SrcDir
    }),
    ?assertEqual(2, length(Files)),
    cleanup_temp_dir(Dir).

integration_pm_test() ->
    Dir = make_temp_dir("pm"),
    SrcDir = filename:join(Dir, "src"),
    ok = filelib:ensure_dir(filename:join(SrcDir, "x")),
    {ok, Files} = hecate_plugin_codegen:integration(#{
        type => process_manager,
        source_event => <<"venture_initiated">>,
        verb => <<"create">>,
        subject => <<"division">>,
        output_dir => SrcDir
    }),
    ?assertEqual(2, length(Files)),
    cleanup_temp_dir(Dir).

integration_requester_test() ->
    Dir = make_temp_dir("requester"),
    SrcDir = filename:join(Dir, "src"),
    ok = filelib:ensure_dir(filename:join(SrcDir, "x")),
    {ok, Files} = hecate_plugin_codegen:integration(#{
        type => requester,
        hope => <<"weather_forecast">>,
        output_dir => SrcDir
    }),
    ?assertEqual(2, length(Files)),
    cleanup_temp_dir(Dir).

integration_responder_test() ->
    Dir = make_temp_dir("responder"),
    SrcDir = filename:join(Dir, "src"),
    ok = filelib:ensure_dir(filename:join(SrcDir, "x")),
    {ok, Files} = hecate_plugin_codegen:integration(#{
        type => responder,
        hope => <<"weather_forecast">>,
        output_dir => SrcDir
    }),
    ?assertEqual(2, length(Files)),
    cleanup_temp_dir(Dir).

%% ===================================================================
%% division/1 -- generates aggregate + state + department scaffolds
%% ===================================================================

division_generates_files_test() ->
    Dir = make_temp_dir("division"),
    AppsDir = filename:join(Dir, "apps"),
    ok = filelib:ensure_dir(filename:join(AppsDir, "x")),
    {ok, Files} = hecate_plugin_codegen:division(#{
        subject => <<"venture">>,
        cmd_app => <<"guide_venture_lifecycle">>,
        prj_app => <<"project_ventures">>,
        qry_app => <<"query_ventures">>,
        output_dir => AppsDir
    }),
    ?assert(length(Files) >= 10),
    cleanup_temp_dir(Dir).

%% ===================================================================
%% Temp dir helpers
%% ===================================================================

make_temp_dir(Prefix) ->
    Ts = integer_to_list(erlang:system_time(microsecond)),
    Dir = filename:join(["/tmp", "codegen_test_" ++ Prefix ++ "_" ++ Ts]),
    ok = filelib:ensure_dir(filename:join(Dir, "x")),
    Dir.

cleanup_temp_dir(Dir) ->
    os:cmd("rm -rf " ++ Dir),
    ok.
