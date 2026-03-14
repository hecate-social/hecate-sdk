# Getting Started

This guide walks you through creating your first Hecate plugin.

## Prerequisites

- Erlang/OTP 27+
- rebar3
- A running Hecate daemon (for testing)

## Create Your Plugin Project

```bash
mkdir my_plugin && cd my_plugin
rebar3 new app my_plugin
```

Add the SDK dependency to `rebar.config`:

```erlang
{deps, [
    {hecate_sdk, "0.1.0"}
]}.
```

## Implement the Plugin Behaviour

Create your callback module. This is the entry point the daemon calls when loading your plugin.

```erlang
%% src/my_plugin.erl
-module(my_plugin).
-behaviour(hecate_plugin).
-include_lib("hecate_sdk/include/hecate_plugin.hrl").

-export([init/1, routes/0, store_config/0, static_dir/0, manifest/0]).

init(#{plugin_name := Name, store_id := StoreId, data_dir := DataDir}) ->
    logger:info("[my-plugin] Starting ~s", [Name]),
    %% Start your supervision tree here
    {ok, #{}}.

routes() ->
    [{"/items", my_items_api, []},
     {"/items/:id", my_item_api, []}].

store_config() ->
    #hecate_store_config{
        store_id = my_items_store,
        dir_name = "items",
        description = "My plugin item store"
    }.

static_dir() -> none.  %% No frontend yet

manifest() ->
    #{
        name => <<"my-plugin">>,
        version => <<"0.1.0">>,
        min_sdk_version => <<"0.1.0">>,
        description => <<"My first Hecate plugin">>
    }.
```

## The Five Callbacks

Every plugin must implement these callbacks:

### init/1

Called once when the daemon loads your plugin. The config map contains:

| Key | Type | Description |
|-----|------|-------------|
| `plugin_name` | `binary()` | Your plugin's name (e.g., `<<"my-plugin">>`) |
| `store_id` | `atom()` | The ReckonDB store created for you (or `none`) |
| `data_dir` | `string()` | Absolute path to your plugin's data directory |

Return `{ok, State}` on success or `{error, Reason}` to abort loading.

### routes/0

Return a list of cowboy route tuples. The daemon mounts these under `/plugin/{name}/api/` automatically. You only provide relative paths:

```erlang
routes() ->
    [{"/items", my_items_api, []},           %% -> /plugin/my-plugin/api/items
     {"/items/:id", my_item_api, []},        %% -> /plugin/my-plugin/api/items/123
     {"/items/:id/comments", comments_api, []}].
```

### store_config/0

Return a `#hecate_store_config{}` record if your plugin uses event sourcing. The daemon creates a ReckonDB store for you before calling `init/1`. Return `none` if you only need SQLite or ETS.

```erlang
store_config() ->
    #hecate_store_config{
        store_id = my_items_store,    %% Atom you use in dispatch opts
        dir_name = "items",           %% Directory under your data path
        description = "Item events"   %% For logging
    }.
```

### static_dir/0

Return a relative path to your frontend assets directory, or `none`. The daemon serves static files at `/plugin/{name}/`:

```erlang
static_dir() -> "priv/static".  %% -> /plugin/my-plugin/index.html
```

### manifest/0

Return a map with your plugin's metadata. Required keys: `name`, `version`, `min_sdk_version`.

## Write an API Handler

Plugin handlers are standard cowboy REST handlers:

```erlang
%% src/my_items_api.erl
-module(my_items_api).

-export([init/2]).

init(Req0, State) ->
    Method = cowboy_req:method(Req0),
    handle(Method, Req0, State).

handle(<<"GET">>, Req0, State) ->
    Items = get_all_items(),
    Body = json:encode(#{<<"items">> => Items}),
    Req = cowboy_req:reply(200, #{
        <<"content-type">> => <<"application/json">>
    }, Body, Req0),
    {ok, Req, State};

handle(<<"POST">>, Req0, State) ->
    {ok, RawBody, Req1} = hecate_plugin_files:read_body(Req0),
    Input = json:decode(RawBody),
    %% Validate input
    Rules = [{title, required, binary}, {body, optional, binary, <<>>}],
    case hecate_plugin_validate:check(Input, Rules) of
        {ok, #{title := Title, body := Body}} ->
            %% Dispatch command to your aggregate...
            Resp = json:encode(#{<<"ok">> => true}),
            Req = cowboy_req:reply(201, #{
                <<"content-type">> => <<"application/json">>
            }, Resp, Req1),
            {ok, Req, State};
        {error, Errors} ->
            ErrBody = json:encode(#{<<"errors">> => format_errors(Errors)}),
            Req = cowboy_req:reply(400, #{
                <<"content-type">> => <<"application/json">>
            }, ErrBody, Req1),
            {ok, Req, State}
    end;

handle(_, Req0, State) ->
    Req = cowboy_req:reply(405, #{}, <<>>, Req0),
    {ok, Req, State}.

get_all_items() -> [].  %% Query your read model

format_errors(Errors) ->
    [#{<<"field">> => atom_to_binary(F), <<"error">> => E}
     || {F, E} <- Errors].
```

## Package Your Plugin

Create a packaging script at `scripts/package.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$ROOT_DIR/_build/plugin"
STAGING_DIR="$BUILD_DIR/staging"

rebar3 compile

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/ebin"

# Copy all .beam files
cp "$ROOT_DIR/_build/default/lib/my_plugin/ebin"/*.beam "$STAGING_DIR/ebin/"

# Copy static assets (if any)
if [ -d "$ROOT_DIR/priv/static" ]; then
    mkdir -p "$STAGING_DIR/priv"
    cp -r "$ROOT_DIR/priv/static" "$STAGING_DIR/priv/static"
fi

# Create manifest
cat > "$STAGING_DIR/manifest.json" <<'EOF'
{
  "name": "my-plugin",
  "version": "0.1.0",
  "callback_module": "my_plugin",
  "plugin_type": "in_vm",
  "min_sdk_version": "0.1.0"
}
EOF

cd "$STAGING_DIR"
tar czf "$BUILD_DIR/my-plugin.tar.gz" .
echo "Package: $BUILD_DIR/my-plugin.tar.gz"
```

## Install Your Plugin

```bash
# Place the tarball where the daemon expects it
mkdir -p ~/.hecate/plugins/my-plugin/
cp _build/plugin/my-plugin.tar.gz ~/.hecate/plugins/my-plugin/

# Install via daemon API
curl -X POST http://localhost:4444/api/plugins/install \
  -H 'Content-Type: application/json' \
  -d '{"plugin_id": "my-plugin", "plugin_type": "in_vm", "callback_module": "my_plugin"}'
```

The daemon will extract the tarball, add the code path, create your store, call `init/1`, mount your routes, and hot-swap cowboy's dispatch table.

## Next Steps

- Read the [Plugin Architecture](plugin-architecture.html) guide for the full lifecycle
- Read the [Packaging Guide](packaging.html) for production packaging
- Explore the SDK helper modules: validation, rate limiting, scheduling, WebSocket, file I/O
