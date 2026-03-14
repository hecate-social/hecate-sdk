%%%-------------------------------------------------------------------
%%% @doc JSON log formatter for OTP logger.
%%%
%%% Produces one JSON line per log event, suitable for journald
%%% and machine parsing. Uses the OTP 27 json module.
%%%
%%% Output example:
%%%   {"ts":"2026-03-15T10:30:00.123456Z","level":"info",
%%%    "msg":"Store ready","plugin":"martha","pid":"pid"}
%%%
%%% Configure in sys.config:
%%%   {kernel, [{logger, [{handler, default, logger_std_h, #{
%%%       formatter => {hecate_plugin_logger, #{}}
%%%   }}]}]}
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_plugin_logger).

-export([format/2, check_config/1]).

-define(MAX_MSG_LEN, 4096).

%%--------------------------------------------------------------------
%% @doc Format a log event as a single JSON line.
%% @end
%%--------------------------------------------------------------------
-spec format(logger:log_event(), logger:formatter_config()) -> unicode:chardata().
format(#{level := Level, msg := Msg, meta := Meta}, _Config) ->
    Timestamp = format_timestamp(Meta),
    Message = format_message(Msg),
    TruncatedMsg = truncate(Message, ?MAX_MSG_LEN),

    Base = #{
        ts => Timestamp,
        level => atom_to_binary(Level),
        msg => TruncatedMsg
    },

    Enriched = enrich_from_metadata(Base, Meta),
    [json:encode(Enriched), $\n].

%%--------------------------------------------------------------------
%% @doc Validate formatter config. Accepts any map.
%% @end
%%--------------------------------------------------------------------
-spec check_config(logger:formatter_config()) -> ok | {error, term()}.
check_config(Config) when is_map(Config) ->
    ok;
check_config(Config) ->
    {error, {invalid_config, Config}}.

%%====================================================================
%% Internal
%%====================================================================

format_timestamp(#{time := Time}) ->
    list_to_binary(calendar:system_time_to_rfc3339(Time, [{unit, microsecond}, {offset, "Z"}]));
format_timestamp(_) ->
    Now = erlang:system_time(microsecond),
    list_to_binary(calendar:system_time_to_rfc3339(Now, [{unit, microsecond}, {offset, "Z"}])).

format_message({string, Msg}) ->
    unicode:characters_to_binary(Msg);
format_message({report, Report}) when is_map(Report) ->
    try
        json:encode(Report)
    catch _:_ ->
        unicode:characters_to_binary(io_lib:format("~p", [Report]))
    end;
format_message({report, Report}) ->
    unicode:characters_to_binary(io_lib:format("~p", [Report]));
format_message({Format, Args}) ->
    unicode:characters_to_binary(io_lib:format(Format, Args)).

truncate(Msg, MaxLen) when is_binary(Msg), byte_size(Msg) > MaxLen ->
    <<Truncated:MaxLen/binary, _/binary>> = Msg,
    <<Truncated/binary, "...">>;
truncate(Msg, _MaxLen) when is_binary(Msg) ->
    Msg;
truncate(Msg, MaxLen) ->
    truncate(iolist_to_binary(Msg), MaxLen).

enrich_from_metadata(Base, Meta) ->
    %% Extract well-known keys
    WithPlugin = case maps:get(plugin_name, Meta, undefined) of
        undefined -> Base;
        PN -> Base#{plugin => PN}
    end,
    WithMfa = case maps:get(mfa, Meta, undefined) of
        undefined -> WithPlugin;
        {M, F, A} ->
            MfaStr = io_lib:format("~s:~s/~b", [M, F, A]),
            WithPlugin#{mfa => iolist_to_binary(MfaStr)}
    end,
    WithPid = case maps:get(pid, Meta, undefined) of
        undefined -> WithMfa;
        Pid -> WithMfa#{pid => list_to_binary(pid_to_list(Pid))}
    end,
    WithDomain = case maps:get(domain, Meta, undefined) of
        undefined -> WithPid;
        Domain -> WithPid#{domain => [atom_to_binary(D) || D <- Domain]}
    end,
    %% Include plugin_version if present
    case maps:get(plugin_version, Meta, undefined) of
        undefined -> WithDomain;
        PV -> WithDomain#{plugin_version => PV}
    end.
