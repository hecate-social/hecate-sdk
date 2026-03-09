%%%-------------------------------------------------------------------
%%% @doc Input validation helpers for plugin API handlers.
%%%
%%% Validates maps (typically JSON request bodies) against rules.
%%% Returns {ok, Validated} with only declared fields, or
%%% {error, Errors} with a list of validation failures.
%%%
%%% Example:
%%%   Rules = [
%%%       {title, required, binary},
%%%       {body, required, binary},
%%%       {tags, optional, {list, binary}, []},
%%%       {priority, optional, {one_of, [low, medium, high]}, medium}
%%%   ],
%%%   case hecate_plugin_validate:check(Input, Rules) of
%%%       {ok, #{title := T, body := B}} -> ...;
%%%       {error, Errors} -> ...
%%%   end.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_plugin_validate).

-export([check/2, require/2, require_binary/2, require_integer/2]).

-type rule() :: {atom(), required, type()}
              | {atom(), optional, type(), term()}.
-type type() :: binary | integer | float | boolean | atom
              | {list, type()} | {one_of, [term()]} | any.
-type error() :: {atom(), binary()}.

%% @doc Validate a map against a list of rules.
-spec check(Input :: map(), Rules :: [rule()]) ->
    {ok, map()} | {error, [error()]}.
check(Input, Rules) ->
    {Validated, Errors} = lists:foldl(fun(Rule, {Acc, Errs}) ->
        case check_rule(Input, Rule) of
            {ok, Key, Value} -> {Acc#{Key => Value}, Errs};
            {error, Err}     -> {Acc, [Err | Errs]}
        end
    end, {#{}, []}, Rules),
    case Errors of
        [] -> {ok, Validated};
        _  -> {error, lists:reverse(Errors)}
    end.

%% @doc Require a key exists in a map. Returns value or error.
-spec require(map(), atom()) -> {ok, term()} | {error, {atom(), binary()}}.
require(Map, Key) ->
    BinKey = atom_to_binary(Key),
    case maps:find(BinKey, Map) of
        {ok, Value} -> {ok, Value};
        error ->
            case maps:find(Key, Map) of
                {ok, Value} -> {ok, Value};
                error -> {error, {Key, <<"required">>}}
            end
    end.

%% @doc Require a binary value.
-spec require_binary(map(), atom()) -> {ok, binary()} | {error, {atom(), binary()}}.
require_binary(Map, Key) ->
    case require(Map, Key) of
        {ok, V} when is_binary(V) -> {ok, V};
        {ok, _} -> {error, {Key, <<"must be a string">>}};
        Err -> Err
    end.

%% @doc Require an integer value.
-spec require_integer(map(), atom()) -> {ok, integer()} | {error, {atom(), binary()}}.
require_integer(Map, Key) ->
    case require(Map, Key) of
        {ok, V} when is_integer(V) -> {ok, V};
        {ok, _} -> {error, {Key, <<"must be an integer">>}};
        Err -> Err
    end.

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

check_rule(Input, {Key, required, Type}) ->
    BinKey = atom_to_binary(Key),
    case maps:find(BinKey, Input) of
        {ok, Value} -> validate_type(Key, Value, Type);
        error ->
            case maps:find(Key, Input) of
                {ok, Value} -> validate_type(Key, Value, Type);
                error -> {error, {Key, <<"is required">>}}
            end
    end;
check_rule(Input, {Key, optional, Type, Default}) ->
    BinKey = atom_to_binary(Key),
    case maps:find(BinKey, Input) of
        {ok, Value} -> validate_type(Key, Value, Type);
        error ->
            case maps:find(Key, Input) of
                {ok, Value} -> validate_type(Key, Value, Type);
                error -> {ok, Key, Default}
            end
    end.

validate_type(Key, Value, binary) when is_binary(Value) ->
    {ok, Key, Value};
validate_type(Key, Value, integer) when is_integer(Value) ->
    {ok, Key, Value};
validate_type(Key, Value, float) when is_float(Value) ->
    {ok, Key, Value};
validate_type(Key, Value, boolean) when is_boolean(Value) ->
    {ok, Key, Value};
validate_type(Key, Value, atom) when is_atom(Value) ->
    {ok, Key, Value};
validate_type(Key, Value, any) ->
    {ok, Key, Value};
validate_type(Key, Value, {list, InnerType}) when is_list(Value) ->
    case lists:all(fun(V) -> type_matches(V, InnerType) end, Value) of
        true  -> {ok, Key, Value};
        false -> {error, {Key, <<"list items have wrong type">>}}
    end;
validate_type(Key, Value, {one_of, Allowed}) ->
    case lists:member(Value, Allowed) of
        true  -> {ok, Key, Value};
        false ->
            AllowedBin = iolist_to_binary(io_lib:format("~p", [Allowed])),
            {error, {Key, <<"must be one of: ", AllowedBin/binary>>}}
    end;
validate_type(Key, _Value, Type) ->
    TypeBin = iolist_to_binary(io_lib:format("~p", [Type])),
    {error, {Key, <<"must be ", TypeBin/binary>>}}.

type_matches(V, binary)  -> is_binary(V);
type_matches(V, integer) -> is_integer(V);
type_matches(V, float)   -> is_float(V);
type_matches(V, boolean) -> is_boolean(V);
type_matches(V, atom)    -> is_atom(V);
type_matches(_, any)     -> true;
type_matches(_, _)       -> false.
