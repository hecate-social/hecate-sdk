%%% @doc JSON API utilities for plugin Cowboy handlers.
%%%
%%% Provides consistent JSON request/response handling for all plugins.
%%% Every function that sends a response automatically increments the
%%% appropriate metric counter (api_requests for all responses, api_errors
%%% for error responses).
%%%
%%% Response format follows the hecate convention:
%%%   Success: {ok: true, ...fields}
%%%   Error:   {ok: false, error: "reason"}
%%%
%%% Values of `undefined' are sanitized to `null' before JSON encoding,
%%% so OTP json produces JSON null instead of the string "undefined".
%%% @end
-module(hecate_plugin_api).

-include("hecate_plugin.hrl").

-export([json_response/3, json_reply/3, json_ok/2, json_ok/3, json_error/3]).
-export([format_error/1, sanitize_for_json/1]).
-export([method_not_allowed/1, not_found/1, bad_request/2]).
-export([read_json_body/1]).
-export([get_field/2, get_field/3]).

%% @doc Send a JSON response with status code.
%% Increments the api_requests metric. Sanitizes undefined to null.
-spec json_response(StatusCode :: non_neg_integer(), Body :: map(), Req :: cowboy_req:req()) ->
    {ok, cowboy_req:req(), []}.
json_response(StatusCode, Body, Req0) ->
    ?METRIC_INC(<<"api_requests">>),
    JsonBody = json:encode(sanitize_for_json(Body)),
    Req = cowboy_req:reply(StatusCode, #{
        <<"content-type">> => <<"application/json">>
    }, JsonBody, Req0),
    {ok, Req, []}.

%% @doc Send a JSON response (alias for json_response/3).
-spec json_reply(StatusCode :: non_neg_integer(), Body :: map(), Req :: cowboy_req:req()) ->
    {ok, cowboy_req:req(), []}.
json_reply(StatusCode, Body, Req) ->
    json_response(StatusCode, Body, Req).

%% @doc Send a 200 OK response with {ok: true} merged.
-spec json_ok(Result :: map(), Req :: cowboy_req:req()) ->
    {ok, cowboy_req:req(), []}.
json_ok(Result, Req) ->
    json_response(200, maps:merge(#{ok => true}, Result), Req).

%% @doc Send OK response with custom status code and {ok: true} merged.
-spec json_ok(StatusCode :: non_neg_integer(), Result :: map(), Req :: cowboy_req:req()) ->
    {ok, cowboy_req:req(), []}.
json_ok(StatusCode, Result, Req) ->
    json_response(StatusCode, maps:merge(#{ok => true}, Result), Req).

%% @doc Send an error response with {ok: false, error: reason}.
%% Increments the api_errors metric in addition to api_requests.
-spec json_error(StatusCode :: non_neg_integer(), Reason :: term(), Req :: cowboy_req:req()) ->
    {ok, cowboy_req:req(), []}.
json_error(StatusCode, Reason, Req) ->
    ?METRIC_INC(<<"api_errors">>),
    json_response(StatusCode, #{ok => false, error => format_error(Reason)}, Req).

%% @doc 405 Method Not Allowed.
-spec method_not_allowed(Req :: cowboy_req:req()) -> {ok, cowboy_req:req(), []}.
method_not_allowed(Req) ->
    json_error(405, <<"Method not allowed">>, Req).

%% @doc 404 Not Found.
-spec not_found(Req :: cowboy_req:req()) -> {ok, cowboy_req:req(), []}.
not_found(Req) ->
    json_error(404, <<"Not found">>, Req).

%% @doc 400 Bad Request.
-spec bad_request(Reason :: term(), Req :: cowboy_req:req()) -> {ok, cowboy_req:req(), []}.
bad_request(Reason, Req) ->
    json_error(400, Reason, Req).

%% @doc Format error term to binary for JSON encoding.
-spec format_error(term()) -> binary().
format_error(Reason) when is_binary(Reason) -> Reason;
format_error(Reason) when is_atom(Reason) -> atom_to_binary(Reason);
format_error({Type, Details}) ->
    iolist_to_binary(io_lib:format("~p: ~p", [Type, Details]));
format_error(Reason) ->
    iolist_to_binary(io_lib:format("~p", [Reason])).

%% @doc Read and decode JSON body from request.
-spec read_json_body(Req :: cowboy_req:req()) ->
    {ok, map(), cowboy_req:req()} | {error, invalid_json, cowboy_req:req()}.
read_json_body(Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    try
        {ok, json:decode(Body), Req1}
    catch
        _:_ ->
            {error, invalid_json, Req1}
    end.

%% @doc Get field from map, supporting both atom and binary keys.
-spec get_field(Key :: atom(), Map :: map()) -> term().
get_field(Key, Map) ->
    get_field(Key, Map, undefined).

%% @doc Get field from map with default, supporting both atom and binary keys.
-spec get_field(Key :: atom(), Map :: map(), Default :: term()) -> term().
get_field(Key, Map, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    maps:get(Key, Map, maps:get(BinKey, Map, Default)).

%% @doc Recursively sanitize data for JSON encoding.
%% Converts atom `undefined' to `null' so json:encode/1 produces
%% JSON null instead of the string "undefined".
-spec sanitize_for_json(term()) -> term().
sanitize_for_json(undefined) -> null;
sanitize_for_json(Map) when is_map(Map) ->
    maps:map(fun(_K, V) -> sanitize_for_json(V) end, Map);
sanitize_for_json(List) when is_list(List) ->
    [sanitize_for_json(E) || E <- List];
sanitize_for_json(Other) -> Other.
