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
    {Validated, Errors} =
        lists:foldl(fun(Rule, Acc) -> apply_rule(check_rule(Input, Rule), Acc) end,
                    {#{}, []}, Rules),
    check_result(Errors, Validated).

apply_rule({ok, Key, Value}, {Acc, Errs}) -> {Acc#{Key => Value}, Errs};
apply_rule({error, Err}, {Acc, Errs}) -> {Acc, [Err | Errs]}.

check_result([], Validated) -> {ok, Validated};
check_result(Errors, _Validated) -> {error, lists:reverse(Errors)}.

%% @doc Require a key exists in a map. Returns value or error.
-spec require(map(), atom()) -> {ok, term()} | {error, {atom(), binary()}}.
require(Map, Key) ->
    BinKey = atom_to_binary(Key),
    require_found(maps:find(BinKey, Map), Map, Key).

require_found({ok, Value}, _Map, _Key) ->
    {ok, Value};
require_found(error, Map, Key) ->
    require_atom_key(maps:find(Key, Map), Key).

require_atom_key({ok, Value}, _Key) -> {ok, Value};
require_atom_key(error, Key) -> {error, {Key, <<"required">>}}.

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
    required_bin(maps:find(BinKey, Input), Input, Key, Type);
check_rule(Input, {Key, optional, Type, Default}) ->
    BinKey = atom_to_binary(Key),
    optional_bin(maps:find(BinKey, Input), Input, Key, Type, Default).

required_bin({ok, Value}, _Input, Key, Type) ->
    validate_type(Key, Value, Type);
required_bin(error, Input, Key, Type) ->
    required_atom(maps:find(Key, Input), Key, Type).

required_atom({ok, Value}, Key, Type) -> validate_type(Key, Value, Type);
required_atom(error, Key, _Type) -> {error, {Key, <<"is required">>}}.

optional_bin({ok, Value}, _Input, Key, Type, _Default) ->
    validate_type(Key, Value, Type);
optional_bin(error, Input, Key, Type, Default) ->
    optional_atom(maps:find(Key, Input), Key, Type, Default).

optional_atom({ok, Value}, Key, Type, _Default) -> validate_type(Key, Value, Type);
optional_atom(error, Key, _Type, Default) -> {ok, Key, Default}.

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
    AllMatch = lists:all(fun(V) -> type_matches(V, InnerType) end, Value),
    validate_list_result(AllMatch, Key, Value);
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

validate_list_result(true, Key, Value) ->
    {ok, Key, Value};
validate_list_result(false, Key, _Value) ->
    {error, {Key, <<"list items have wrong type">>}}.

type_matches(V, binary)  -> is_binary(V);
type_matches(V, integer) -> is_integer(V);
type_matches(V, float)   -> is_float(V);
type_matches(V, boolean) -> is_boolean(V);
type_matches(V, atom)    -> is_atom(V);
type_matches(_, any)     -> true;
type_matches(_, _)       -> false.
