-module(hecate_plugin_ratelimit_tests).
-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% Setup/Teardown
%%====================================================================

setup() ->
    %% Clean up ETS table between tests if it exists
    case ets:info(hecate_plugin_ratelimit) of
        undefined -> ok;
        _ -> ets:delete(hecate_plugin_ratelimit)
    end.

%%====================================================================
%% new/3
%%====================================================================

new_creates_config_test() ->
    setup(),
    ?assertEqual(ok, hecate_plugin_ratelimit:new(test_limit, 10, 1000)).

%%====================================================================
%% check/2
%%====================================================================

check_allows_within_limit_test() ->
    setup(),
    ok = hecate_plugin_ratelimit:new(api_limit, 5, 1000),
    ?assertEqual(ok, hecate_plugin_ratelimit:check(api_limit, <<"user1">>)),
    ?assertEqual(ok, hecate_plugin_ratelimit:check(api_limit, <<"user1">>)),
    ?assertEqual(ok, hecate_plugin_ratelimit:check(api_limit, <<"user1">>)).

check_blocks_over_limit_test() ->
    setup(),
    ok = hecate_plugin_ratelimit:new(strict_limit, 2, 60000),
    ?assertEqual(ok, hecate_plugin_ratelimit:check(strict_limit, <<"client">>)),
    ?assertEqual(ok, hecate_plugin_ratelimit:check(strict_limit, <<"client">>)),
    %% Third request should be blocked
    Result = hecate_plugin_ratelimit:check(strict_limit, <<"client">>),
    ?assertMatch({error, _}, Result).

check_different_keys_independent_test() ->
    setup(),
    ok = hecate_plugin_ratelimit:new(per_user, 1, 60000),
    ?assertEqual(ok, hecate_plugin_ratelimit:check(per_user, <<"alice">>)),
    ?assertEqual(ok, hecate_plugin_ratelimit:check(per_user, <<"bob">>)),
    %% Alice is blocked, but bob already used his
    ?assertMatch({error, _}, hecate_plugin_ratelimit:check(per_user, <<"alice">>)),
    ?assertMatch({error, _}, hecate_plugin_ratelimit:check(per_user, <<"bob">>)).

check_no_config_allows_all_test() ->
    setup(),
    %% No config created for this limiter name — should allow
    ?assertEqual(ok, hecate_plugin_ratelimit:check(nonexistent, <<"anyone">>)).

check_retry_after_is_positive_test() ->
    setup(),
    ok = hecate_plugin_ratelimit:new(tiny, 1, 5000),
    ok = hecate_plugin_ratelimit:check(tiny, <<"x">>),
    {error, RetryAfter} = hecate_plugin_ratelimit:check(tiny, <<"x">>),
    ?assert(is_integer(RetryAfter)),
    ?assert(RetryAfter > 0).

%%====================================================================
%% reset/2
%%====================================================================

reset_allows_again_test() ->
    setup(),
    ok = hecate_plugin_ratelimit:new(resettable, 1, 60000),
    ok = hecate_plugin_ratelimit:check(resettable, <<"user">>),
    ?assertMatch({error, _}, hecate_plugin_ratelimit:check(resettable, <<"user">>)),
    ok = hecate_plugin_ratelimit:reset(resettable, <<"user">>),
    ?assertEqual(ok, hecate_plugin_ratelimit:check(resettable, <<"user">>)).
