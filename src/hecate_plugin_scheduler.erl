%%%-------------------------------------------------------------------
%%% @doc Cron-like recurring task scheduler for plugins.
%%%
%%% Plugins can schedule periodic tasks that run in their own process.
%%% Tasks are lightweight — each is a spawned process with a timer.
%%%
%%% Usage:
%%%   %% Run every 5 minutes
%%%   hecate_plugin_scheduler:every(5 * 60 * 1000, fun cleanup_expired/0).
%%%
%%%   %% Run every hour with a name (for cancellation)
%%%   Ref = hecate_plugin_scheduler:every(3600000, fun sync_remote/0),
%%%   hecate_plugin_scheduler:cancel(Ref).
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_plugin_scheduler).

-export([every/2, every/3, cancel/1]).

%% @doc Schedule a function to run every IntervalMs milliseconds.
%% Returns a reference that can be used to cancel.
-spec every(IntervalMs :: pos_integer(), Fun :: fun(() -> term())) ->
    reference().
every(IntervalMs, Fun) ->
    every(IntervalMs, Fun, #{}).

%% @doc Schedule with options.
%% Options:
%%   - initial_delay: milliseconds before first run (default: IntervalMs)
%%   - name: atom for logging (default: anonymous)
-spec every(pos_integer(), fun(() -> term()), map()) -> reference().
every(IntervalMs, Fun, Opts) ->
    Ref = make_ref(),
    InitialDelay = maps:get(initial_delay, Opts, IntervalMs),
    Name = maps:get(name, Opts, anonymous),
    Pid = spawn_link(fun() -> schedule_loop(Ref, IntervalMs, Fun, Name) end),
    erlang:send_after(InitialDelay, Pid, {run, Ref}),
    Ref.

%% @doc Cancel a scheduled task.
-spec cancel(reference()) -> ok.
cancel(Ref) ->
    put({scheduler_cancel, Ref}, true),
    ok.

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

schedule_loop(Ref, IntervalMs, Fun, Name) ->
    receive
        {run, Ref} ->
            schedule_run(get({scheduler_cancel, Ref}), Ref, IntervalMs, Fun, Name)
    end.

schedule_run(true, _Ref, _IntervalMs, _Fun, _Name) ->
    ok;
schedule_run(_, Ref, IntervalMs, Fun, Name) ->
    run_scheduled(Fun, Name),
    erlang:send_after(IntervalMs, self(), {run, Ref}),
    schedule_loop(Ref, IntervalMs, Fun, Name).

run_scheduled(Fun, Name) ->
    try Fun()
    catch
        Class:Reason:Stack ->
            logger:error("[scheduler] Task ~p failed: ~p:~p~n~p",
                         [Name, Class, Reason, Stack])
    end.
