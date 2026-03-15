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
%% division/1 with custom FLAGS
%% ===================================================================

division_with_flags_test() ->
    Dir = make_temp_dir("flags"),
    AppsDir = filename:join(Dir, "apps"),
    ok = filelib:ensure_dir(filename:join(AppsDir, "x")),
    {ok, Files} = hecate_plugin_codegen:division(#{
        subject => <<"invoice">>,
        cmd_app => <<"guide_billing">>,
        prj_app => <<"project_billings">>,
        qry_app => <<"query_billings">>,
        output_dir => AppsDir,
        flags => [{<<"INITIATED">>, 1}, {<<"ARCHIVED">>, 2}, {<<"ISSUED">>, 4}]
    }),
    ?assert(length(Files) >= 10),
    %% Check status.hrl contains custom ISSUED flag
    StatusHrl = filename:join([AppsDir, "guide_billing", "include", "invoice_status.hrl"]),
    ?assert(filelib:is_regular(StatusHrl)),
    {ok, Content} = file:read_file(StatusHrl),
    ?assertNotEqual(nomatch, binary:match(Content, <<"ISSUED">>)),
    ?assertNotEqual(nomatch, binary:match(Content, <<"4">>)),
    cleanup_temp_dir(Dir).

%% ===================================================================
%% delivery/1 -- generates delivery artifacts
%% ===================================================================

delivery_in_vm_generates_files_test() ->
    Dir = make_temp_dir("deliver_vm"),
    ok = filelib:ensure_dir(filename:join(Dir, "x")),
    {ok, Files} = hecate_plugin_codegen:delivery(#{
        plugin_name => <<"hecate-app-billing">>,
        plugin_type => in_vm,
        otp_version => <<"27">>,
        output_dir => Dir
    }),
    ?assert(length(Files) >= 3),
    %% Should have ci.yml, release.yml, package.sh
    CiYml = filename:join([Dir, ".github", "workflows", "ci.yml"]),
    ?assert(filelib:is_regular(CiYml)),
    ReleaseYml = filename:join([Dir, ".github", "workflows", "release.yml"]),
    ?assert(filelib:is_regular(ReleaseYml)),
    PackageSh = filename:join([Dir, "scripts", "package.sh"]),
    ?assert(filelib:is_regular(PackageSh)),
    %% Should NOT have Dockerfile or docker.yml
    ?assertNot(filelib:is_regular(filename:join(Dir, "Dockerfile"))),
    ?assertNot(filelib:is_regular(filename:join([Dir, ".github", "workflows", "docker.yml"]))),
    cleanup_temp_dir(Dir).

delivery_container_generates_files_test() ->
    Dir = make_temp_dir("deliver_ctr"),
    ok = filelib:ensure_dir(filename:join(Dir, "x")),
    {ok, Files} = hecate_plugin_codegen:delivery(#{
        plugin_name => <<"hecate-app-trader">>,
        plugin_type => container,
        otp_version => <<"27">>,
        port => <<"4444">>,
        output_dir => Dir
    }),
    ?assert(length(Files) >= 3),
    %% Should have ci.yml, Dockerfile, docker.yml
    CiYml = filename:join([Dir, ".github", "workflows", "ci.yml"]),
    ?assert(filelib:is_regular(CiYml)),
    Dockerfile = filename:join(Dir, "Dockerfile"),
    ?assert(filelib:is_regular(Dockerfile)),
    DockerYml = filename:join([Dir, ".github", "workflows", "docker.yml"]),
    ?assert(filelib:is_regular(DockerYml)),
    %% Should NOT have release.yml or package.sh
    ?assertNot(filelib:is_regular(filename:join([Dir, ".github", "workflows", "release.yml"]))),
    ?assertNot(filelib:is_regular(filename:join([Dir, "scripts", "package.sh"]))),
    %% Dockerfile should contain the port
    {ok, DfContent} = file:read_file(Dockerfile),
    ?assertNotEqual(nomatch, binary:match(DfContent, <<"4444">>)),
    cleanup_temp_dir(Dir).

%% ===================================================================
%% bump_version/1 -- updates version strings
%% ===================================================================

bump_version_test() ->
    Dir = make_temp_dir("bumpvsn"),
    ok = filelib:ensure_dir(filename:join(Dir, "x")),
    %% Create a manifest.json
    ManifestPath = filename:join(Dir, "manifest.json"),
    ok = file:write_file(ManifestPath, <<"{\"version\": \"0.1.0\", \"name\": \"test\"}">>),
    %% Create a .app.src
    SrcDir = filename:join(Dir, "src"),
    ok = filelib:ensure_dir(filename:join(SrcDir, "x")),
    AppSrcPath = filename:join(SrcDir, "test.app.src"),
    ok = file:write_file(AppSrcPath, <<"{application, test, [{vsn, \"0.1.0\"}]}.">>),
    %% Bump
    ok = hecate_plugin_codegen_delivery:bump_version(#{
        version => <<"0.2.0">>,
        changelog => <<"Added new feature">>,
        output_dir => Dir
    }),
    %% Verify manifest updated
    {ok, ManifestContent} = file:read_file(ManifestPath),
    ?assertNotEqual(nomatch, binary:match(ManifestContent, <<"0.2.0">>)),
    ?assertEqual(nomatch, binary:match(ManifestContent, <<"0.1.0">>)),
    %% Verify .app.src updated
    {ok, AppSrcContent} = file:read_file(AppSrcPath),
    ?assertNotEqual(nomatch, binary:match(AppSrcContent, <<"0.2.0">>)),
    %% Verify CHANGELOG.md created
    ChangelogPath = filename:join(Dir, "CHANGELOG.md"),
    ?assert(filelib:is_regular(ChangelogPath)),
    {ok, ChangelogContent} = file:read_file(ChangelogPath),
    ?assertNotEqual(nomatch, binary:match(ChangelogContent, <<"0.2.0">>)),
    ?assertNotEqual(nomatch, binary:match(ChangelogContent, <<"Added new feature">>)),
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
