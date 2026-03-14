-module(hecate_plugin_paths_tests).
-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% base_dir/1
%%====================================================================

base_dir_binary_name_test() ->
    Dir = hecate_plugin_paths:base_dir(<<"scribe">>),
    ?assert(is_list(Dir)),
    ?assertNotEqual(nomatch, string:find(Dir, "plugins/scribe")).

base_dir_string_name_test() ->
    Dir = hecate_plugin_paths:base_dir("scribe"),
    ?assertNotEqual(nomatch, string:find(Dir, "plugins/scribe")).

%%====================================================================
%% sqlite paths
%%====================================================================

sqlite_dir_test() ->
    Dir = hecate_plugin_paths:sqlite_dir(<<"myplugin">>),
    ?assertNotEqual(nomatch, string:find(Dir, "plugins/myplugin/sqlite")).

sqlite_path_test() ->
    Path = hecate_plugin_paths:sqlite_path(<<"myplugin">>, "read_model.db"),
    ?assertNotEqual(nomatch, string:find(Path, "plugins/myplugin/sqlite/read_model.db")).

%%====================================================================
%% reckon paths
%%====================================================================

reckon_dir_test() ->
    Dir = hecate_plugin_paths:reckon_dir(<<"myplugin">>),
    ?assertNotEqual(nomatch, string:find(Dir, "plugins/myplugin/reckon-db")).

reckon_path_test() ->
    Path = hecate_plugin_paths:reckon_path(<<"myplugin">>, "events"),
    ?assertNotEqual(nomatch, string:find(Path, "plugins/myplugin/reckon-db/events")).

%%====================================================================
%% run paths
%%====================================================================

run_dir_test() ->
    Dir = hecate_plugin_paths:run_dir(<<"myplugin">>),
    ?assertNotEqual(nomatch, string:find(Dir, "plugins/myplugin/run")).

run_path_test() ->
    Path = hecate_plugin_paths:run_path(<<"myplugin">>, "daemon.pid"),
    ?assertNotEqual(nomatch, string:find(Path, "plugins/myplugin/run/daemon.pid")).

%%====================================================================
%% ensure_layout/1
%%====================================================================

ensure_layout_creates_directories_test() ->
    TmpDir = filename:join(os:getenv("HOME"), ".hecate-test-sdk-" ++
        integer_to_list(erlang:unique_integer([positive]))),
    os:putenv("HECATE_HOME", TmpDir),
    try
        ok = hecate_plugin_paths:ensure_layout(<<"testplugin">>),
        ?assert(filelib:is_dir(hecate_plugin_paths:sqlite_dir(<<"testplugin">>))),
        ?assert(filelib:is_dir(hecate_plugin_paths:reckon_dir(<<"testplugin">>))),
        ?assert(filelib:is_dir(hecate_plugin_paths:run_dir(<<"testplugin">>)))
    after
        os:unsetenv("HECATE_HOME"),
        os:cmd("rm -rf " ++ TmpDir)
    end.

%%====================================================================
%% Path consistency
%%====================================================================

subdirs_are_under_base_dir_test() ->
    Base = hecate_plugin_paths:base_dir(<<"check">>),
    ?assertNotEqual(nomatch, string:find(hecate_plugin_paths:sqlite_dir(<<"check">>), Base)),
    ?assertNotEqual(nomatch, string:find(hecate_plugin_paths:reckon_dir(<<"check">>), Base)),
    ?assertNotEqual(nomatch, string:find(hecate_plugin_paths:run_dir(<<"check">>), Base)).
