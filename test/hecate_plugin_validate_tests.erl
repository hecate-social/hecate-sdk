-module(hecate_plugin_validate_tests).
-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% check/2 — required fields
%%====================================================================

check_required_present_test() ->
    Rules = [{title, required, binary}],
    Input = #{<<"title">> => <<"Hello">>},
    ?assertMatch({ok, #{title := <<"Hello">>}}, hecate_plugin_validate:check(Input, Rules)).

check_required_missing_test() ->
    Rules = [{title, required, binary}],
    Input = #{},
    ?assertMatch({error, [{title, <<"is required">>}]},
                 hecate_plugin_validate:check(Input, Rules)).

check_required_atom_key_test() ->
    Rules = [{title, required, binary}],
    Input = #{title => <<"Hello">>},
    ?assertMatch({ok, #{title := <<"Hello">>}}, hecate_plugin_validate:check(Input, Rules)).

check_required_wrong_type_test() ->
    Rules = [{title, required, binary}],
    Input = #{<<"title">> => 42},
    ?assertMatch({error, [{title, _}]}, hecate_plugin_validate:check(Input, Rules)).

%%====================================================================
%% check/2 — optional fields
%%====================================================================

check_optional_present_test() ->
    Rules = [{tags, optional, {list, binary}, []}],
    Input = #{<<"tags">> => [<<"a">>, <<"b">>]},
    {ok, Result} = hecate_plugin_validate:check(Input, Rules),
    ?assertEqual([<<"a">>, <<"b">>], maps:get(tags, Result)).

check_optional_missing_uses_default_test() ->
    Rules = [{tags, optional, {list, binary}, []}],
    Input = #{},
    {ok, Result} = hecate_plugin_validate:check(Input, Rules),
    ?assertEqual([], maps:get(tags, Result)).

check_optional_wrong_type_test() ->
    Rules = [{priority, optional, integer, 0}],
    Input = #{<<"priority">> => <<"high">>},
    ?assertMatch({error, _}, hecate_plugin_validate:check(Input, Rules)).

%%====================================================================
%% check/2 — type checks
%%====================================================================

check_integer_type_test() ->
    Rules = [{count, required, integer}],
    ?assertMatch({ok, #{count := 5}},
                 hecate_plugin_validate:check(#{<<"count">> => 5}, Rules)).

check_float_type_test() ->
    Rules = [{score, required, float}],
    ?assertMatch({ok, #{score := 3.14}},
                 hecate_plugin_validate:check(#{<<"score">> => 3.14}, Rules)).

check_boolean_type_test() ->
    Rules = [{active, required, boolean}],
    ?assertMatch({ok, #{active := true}},
                 hecate_plugin_validate:check(#{<<"active">> => true}, Rules)).

check_any_type_test() ->
    Rules = [{data, required, any}],
    ?assertMatch({ok, #{data := #{<<"nested">> := true}}},
                 hecate_plugin_validate:check(#{<<"data">> => #{<<"nested">> => true}}, Rules)).

check_one_of_valid_test() ->
    Rules = [{level, required, {one_of, [low, medium, high]}}],
    ?assertMatch({ok, #{level := medium}},
                 hecate_plugin_validate:check(#{<<"level">> => medium}, Rules)).

check_one_of_invalid_test() ->
    Rules = [{level, required, {one_of, [low, medium, high]}}],
    ?assertMatch({error, [{level, _}]},
                 hecate_plugin_validate:check(#{<<"level">> => extreme}, Rules)).

check_list_of_integers_test() ->
    Rules = [{ids, required, {list, integer}}],
    ?assertMatch({ok, #{ids := [1, 2, 3]}},
                 hecate_plugin_validate:check(#{<<"ids">> => [1, 2, 3]}, Rules)).

check_list_wrong_inner_type_test() ->
    Rules = [{ids, required, {list, integer}}],
    ?assertMatch({error, [{ids, _}]},
                 hecate_plugin_validate:check(#{<<"ids">> => [1, <<"two">>, 3]}, Rules)).

%%====================================================================
%% check/2 — multiple rules
%%====================================================================

check_multiple_rules_test() ->
    Rules = [
        {title, required, binary},
        {body, required, binary},
        {tags, optional, {list, binary}, []}
    ],
    Input = #{<<"title">> => <<"Test">>, <<"body">> => <<"Content">>},
    {ok, Result} = hecate_plugin_validate:check(Input, Rules),
    ?assertEqual(<<"Test">>, maps:get(title, Result)),
    ?assertEqual(<<"Content">>, maps:get(body, Result)),
    ?assertEqual([], maps:get(tags, Result)).

check_multiple_errors_test() ->
    Rules = [
        {title, required, binary},
        {body, required, binary}
    ],
    Input = #{},
    {error, Errors} = hecate_plugin_validate:check(Input, Rules),
    ?assertEqual(2, length(Errors)).

%%====================================================================
%% require/2, require_binary/2, require_integer/2
%%====================================================================

require_found_binary_key_test() ->
    ?assertEqual({ok, <<"val">>}, hecate_plugin_validate:require(#{<<"key">> => <<"val">>}, key)).

require_found_atom_key_test() ->
    ?assertEqual({ok, <<"val">>}, hecate_plugin_validate:require(#{key => <<"val">>}, key)).

require_missing_test() ->
    ?assertEqual({error, {key, <<"required">>}}, hecate_plugin_validate:require(#{}, key)).

require_binary_valid_test() ->
    ?assertMatch({ok, <<"hello">>},
                 hecate_plugin_validate:require_binary(#{<<"name">> => <<"hello">>}, name)).

require_binary_wrong_type_test() ->
    ?assertMatch({error, {name, <<"must be a string">>}},
                 hecate_plugin_validate:require_binary(#{<<"name">> => 42}, name)).

require_integer_valid_test() ->
    ?assertMatch({ok, 42},
                 hecate_plugin_validate:require_integer(#{<<"count">> => 42}, count)).

require_integer_wrong_type_test() ->
    ?assertMatch({error, {count, <<"must be an integer">>}},
                 hecate_plugin_validate:require_integer(#{<<"count">> => <<"nope">>}, count)).
