-module(hecate_plugin_api_tests).
-include_lib("eunit/include/eunit.hrl").

%%% Tests for hecate_plugin_api utilities.
%%% Response functions require cowboy which is not available in unit tests,
%%% so we test the pure functions: format_error, sanitize_for_json, get_field.

%% ===================================================================
%% format_error/1
%% ===================================================================

format_error_binary_test() ->
    ?assertEqual(<<"bad input">>, hecate_plugin_api:format_error(<<"bad input">>)).

format_error_atom_test() ->
    ?assertEqual(<<"not_found">>, hecate_plugin_api:format_error(not_found)).

format_error_tuple_test() ->
    Result = hecate_plugin_api:format_error({validation, missing_field}),
    ?assert(is_binary(Result)),
    ?assertNotEqual(<<>>, Result).

format_error_other_test() ->
    Result = hecate_plugin_api:format_error(42),
    ?assert(is_binary(Result)).

%% ===================================================================
%% sanitize_for_json/1
%% ===================================================================

sanitize_undefined_test() ->
    ?assertEqual(null, hecate_plugin_api:sanitize_for_json(undefined)).

sanitize_map_test() ->
    Input = #{name => <<"alice">>, email => undefined},
    Expected = #{name => <<"alice">>, email => null},
    ?assertEqual(Expected, hecate_plugin_api:sanitize_for_json(Input)).

sanitize_nested_map_test() ->
    Input = #{user => #{name => <<"bob">>, phone => undefined}},
    Expected = #{user => #{name => <<"bob">>, phone => null}},
    ?assertEqual(Expected, hecate_plugin_api:sanitize_for_json(Input)).

sanitize_list_test() ->
    Input = [<<"a">>, undefined, <<"c">>],
    Expected = [<<"a">>, null, <<"c">>],
    ?assertEqual(Expected, hecate_plugin_api:sanitize_for_json(Input)).

sanitize_passthrough_test() ->
    ?assertEqual(42, hecate_plugin_api:sanitize_for_json(42)),
    ?assertEqual(true, hecate_plugin_api:sanitize_for_json(true)),
    ?assertEqual(<<"hello">>, hecate_plugin_api:sanitize_for_json(<<"hello">>)).

sanitize_map_with_list_test() ->
    Input = #{items => [#{name => undefined}, #{name => <<"x">>}]},
    Expected = #{items => [#{name => null}, #{name => <<"x">>}]},
    ?assertEqual(Expected, hecate_plugin_api:sanitize_for_json(Input)).

%% ===================================================================
%% get_field/2,3
%% ===================================================================

get_field_atom_key_test() ->
    Map = #{name => <<"alice">>},
    ?assertEqual(<<"alice">>, hecate_plugin_api:get_field(name, Map)).

get_field_binary_key_test() ->
    Map = #{<<"name">> => <<"bob">>},
    ?assertEqual(<<"bob">>, hecate_plugin_api:get_field(name, Map)).

get_field_atom_preferred_test() ->
    Map = #{name => <<"atom">>, <<"name">> => <<"binary">>},
    ?assertEqual(<<"atom">>, hecate_plugin_api:get_field(name, Map)).

get_field_missing_test() ->
    Map = #{age => 30},
    ?assertEqual(undefined, hecate_plugin_api:get_field(name, Map)).

get_field_default_test() ->
    Map = #{age => 30},
    ?assertEqual(<<"unknown">>, hecate_plugin_api:get_field(name, Map, <<"unknown">>)).
