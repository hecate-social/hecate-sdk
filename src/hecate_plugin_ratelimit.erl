%%%-------------------------------------------------------------------
%%% @doc Token bucket rate limiter for plugins.
%%%
%%% In-memory, per-process rate limiting using ETS.
%%% Suitable for API endpoint protection.
%%%
%%% Usage:
%%%   %% Create a bucket: 10 requests per second
%%%   hecate_plugin_ratelimit:new(my_api_limit, 10, 1000).
%%%
%%%   %% Check rate limit (returns ok or {error, retry_after_ms})
%%%   case hecate_plugin_ratelimit:check(my_api_limit, ClientId) of
%%%       ok -> handle_request();
%%%       {error, RetryAfterMs} -> reply_429(RetryAfterMs)
%%%   end.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_plugin_ratelimit).

-export([new/3, check/2, reset/2]).

%% @doc Create a new rate limiter bucket.
%% - Name: atom identifier for this limiter
%% - MaxTokens: maximum tokens (requests) allowed per window
%% - WindowMs: time window in milliseconds for token refill
-spec new(Name :: atom(), MaxTokens :: pos_integer(),
          WindowMs :: pos_integer()) -> ok.
new(Name, MaxTokens, WindowMs) ->
    Tab = ensure_table(),
    ets:insert(Tab, {{config, Name}, MaxTokens, WindowMs}),
    ok.

%% @doc Check if a request is allowed for a given key.
%% Returns 'ok' if allowed, or {error, RetryAfterMs} if rate limited.
-spec check(Name :: atom(), Key :: term()) ->
    ok | {error, pos_integer()}.
check(Name, Key) ->
    Tab = ensure_table(),
    Now = erlang:monotonic_time(millisecond),
    check_config(ets:lookup(Tab, {config, Name}), Tab, Name, Key, Now).

check_config([{{config, Name}, MaxTokens, WindowMs}], Tab, Name, Key, Now) ->
    BucketKey = {bucket, Name, Key},
    check_bucket(ets:lookup(Tab, BucketKey), Tab, BucketKey, MaxTokens, WindowMs, Now);
check_config([], _Tab, _Name, _Key, _Now) ->
    ok.  %% No config = no limit

check_bucket([{BucketKey, Tokens, LastRefill}], Tab, BucketKey, MaxTokens, WindowMs, Now) ->
    Elapsed = Now - LastRefill,
    Refilled = min(MaxTokens, Tokens + (Elapsed * MaxTokens div WindowMs)),
    check_refilled(Refilled > 0, Tab, BucketKey, Refilled, WindowMs, Elapsed, Now);
check_bucket([], Tab, BucketKey, MaxTokens, _WindowMs, Now) ->
    ets:insert(Tab, {BucketKey, MaxTokens - 1, Now}),
    ok.

check_refilled(true, Tab, BucketKey, Refilled, _WindowMs, _Elapsed, Now) ->
    ets:insert(Tab, {BucketKey, Refilled - 1, Now}),
    ok;
check_refilled(false, _Tab, _BucketKey, _Refilled, WindowMs, Elapsed, _Now) ->
    RetryAfter = WindowMs - Elapsed,
    {error, max(1, RetryAfter)}.

%% @doc Reset rate limit for a specific key.
-spec reset(Name :: atom(), Key :: term()) -> ok.
reset(Name, Key) ->
    Tab = ensure_table(),
    ets:delete(Tab, {bucket, Name, Key}),
    ok.

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

ensure_table() ->
    case ets:info(hecate_plugin_ratelimit) of
        undefined ->
            ets:new(hecate_plugin_ratelimit, [
                named_table, public, set, {write_concurrency, true}
            ]);
        _ ->
            hecate_plugin_ratelimit
    end.
