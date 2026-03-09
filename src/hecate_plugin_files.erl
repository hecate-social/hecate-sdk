%%%-------------------------------------------------------------------
%%% @doc File upload/download helper for plugins.
%%%
%%% Handles multipart uploads and chunked downloads via cowboy.
%%% Files are stored under the plugin's data directory.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_plugin_files).

-export([read_body/1, read_body/2, save_upload/3, stream_file/3]).

%% @doc Read the full request body (up to 8MB default).
-spec read_body(cowboy_req:req()) -> {ok, binary(), cowboy_req:req()}.
read_body(Req) ->
    read_body(Req, #{length => 8388608, period => 15000}).

%% @doc Read the full request body with custom options.
-spec read_body(cowboy_req:req(), map()) -> {ok, binary(), cowboy_req:req()}.
read_body(Req, Opts) ->
    read_body_acc(Req, Opts, []).

%% @doc Save uploaded binary data to a file in the plugin's data directory.
-spec save_upload(PluginName :: string() | binary(),
                  RelativePath :: string(),
                  Data :: binary()) -> ok | {error, term()}.
save_upload(PluginName, RelativePath, Data) ->
    FullPath = filename:join(hecate_plugin_paths:base_dir(PluginName), RelativePath),
    ok = filelib:ensure_dir(FullPath),
    file:write_file(FullPath, Data).

%% @doc Stream a file as the response body (chunked transfer).
-spec stream_file(cowboy_req:req(), file:filename(), binary()) ->
    {ok, cowboy_req:req()}.
stream_file(Req0, FilePath, ContentType) ->
    {ok, FileInfo} = file:read_file_info(FilePath),
    FileSize = element(2, FileInfo),
    Req = cowboy_req:stream_reply(200, #{
        <<"content-type">> => ContentType,
        <<"content-length">> => integer_to_binary(FileSize)
    }, Req0),
    {ok, Fd} = file:open(FilePath, [read, binary, raw]),
    stream_chunks(Fd, Req),
    file:close(Fd),
    {ok, Req}.

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

read_body_acc(Req0, Opts, Acc) ->
    case cowboy_req:read_body(Req0, Opts) of
        {ok, Data, Req} ->
            {ok, iolist_to_binary(lists:reverse([Data | Acc])), Req};
        {more, Data, Req} ->
            read_body_acc(Req, Opts, [Data | Acc])
    end.

stream_chunks(Fd, Req) ->
    case file:read(Fd, 65536) of
        {ok, Data} ->
            cowboy_req:stream_body(Data, nofin, Req),
            stream_chunks(Fd, Req);
        eof ->
            cowboy_req:stream_body(<<>>, fin, Req)
    end.
