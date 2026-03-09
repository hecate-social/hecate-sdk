%%%-------------------------------------------------------------------
%%% @doc WebSocket helper for plugin live UIs.
%%%
%%% Provides a base behaviour for plugin WebSocket handlers.
%%% Handles JSON encoding/decoding and standard message framing.
%%%
%%% Usage in a plugin:
%%%   -module(my_plugin_ws).
%%%   -behaviour(cowboy_websocket).
%%%   -export([init/2, websocket_init/1, websocket_handle/2,
%%%            websocket_info/2]).
%%%
%%%   init(Req, State) ->
%%%       hecate_plugin_ws:upgrade(Req, State).
%%%
%%%   websocket_handle({text, Data}, State) ->
%%%       Msg = hecate_plugin_ws:decode(Data),
%%%       %% handle Msg ...
%%%       {reply, hecate_plugin_ws:encode(Response), State}.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_plugin_ws).

-export([upgrade/2, encode/1, decode/1, reply_json/2, reply_error/3]).

%% @doc Upgrade an HTTP request to WebSocket.
-spec upgrade(cowboy_req:req(), term()) ->
    {cowboy_websocket, cowboy_req:req(), term()}.
upgrade(Req, State) ->
    {cowboy_websocket, Req, State, #{
        idle_timeout => 60000,
        max_frame_size => 1048576  %% 1MB
    }}.

%% @doc Encode a term as a JSON text frame.
-spec encode(term()) -> {text, iodata()}.
encode(Term) ->
    {text, json:encode(Term)}.

%% @doc Decode a JSON binary into a map.
-spec decode(binary()) -> map().
decode(Data) ->
    json:decode(Data).

%% @doc Send a JSON reply with a type tag.
-spec reply_json(Type :: binary(), Payload :: map()) -> {text, iodata()}.
reply_json(Type, Payload) ->
    encode(Payload#{<<"type">> => Type}).

%% @doc Send a JSON error reply.
-spec reply_error(Code :: binary(), Message :: binary(), Details :: map()) ->
    {text, iodata()}.
reply_error(Code, Message, Details) ->
    encode(#{
        <<"type">> => <<"error">>,
        <<"code">> => Code,
        <<"message">> => Message,
        <<"details">> => Details
    }).
