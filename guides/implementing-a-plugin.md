# Implementing a Hecate Plugin

A practical, end-to-end guide for building an in-VM Hecate plugin.
Uses the real Snake Duel arcade game as a worked example.

## What You Will Build

A plugin has two parts:

| Part | Technology | Delivered As |
|------|-----------|--------------|
| **Daemon** | Erlang/OTP umbrella | `.beam` files in `ebin/` |
| **Frontend** | Svelte/React/vanilla JS | Web component in `priv/static/` |

The daemon handles business logic, data, and API endpoints.
The frontend renders inside the Hecate desktop app as a custom element.

## Repository Layout

Every plugin repository follows this structure:

```
hecate-app-{name}/
  manifest.json                  Plugin metadata (read by daemon)
  hecate-app-{name}d/            Daemon (Erlang umbrella)
    rebar.config
    src/                         Root app (plugin callback + utilities)
    apps/                        Domain apps (CMD, QRY, PRJ)
    priv/static/                 Compiled frontend assets
  hecate-app-{name}w/            Frontend (SvelteKit, etc.)
    src/
    package.json
```

The `d` suffix = daemon, `w` suffix = web. This is a convention, not a requirement.

## Step 1: The Plugin Callback

The callback module is your plugin's entry point. The daemon calls it when
loading your plugin into the VM.

Create `src/app_{name}.erl` implementing `hecate_plugin`:

```erlang
-module(app_snake_duel).
-behaviour(hecate_plugin).
-include_lib("hecate_sdk/include/hecate_plugin.hrl").

-export([init/1, routes/0, store_config/0, static_dir/0, manifest/0, flag_maps/0]).

init(#{plugin_name := PluginName, data_dir := DataDir} = Config) ->
    StoreId = maps:get(store_id, Config, none),
    persistent_term:put(app_snake_duel_config, #{
        plugin_name => PluginName,
        store_id => StoreId,
        data_dir => DataDir
    }),
    case app_snake_duel_sup:start_link() of
        {ok, Pid} -> {ok, #{sup_pid => Pid}};
        {error, {already_started, Pid}} -> {ok, #{sup_pid => Pid}};
        {error, Reason} -> {error, Reason}
    end.

routes() ->
    [{"/matches", start_duel_api, []},
     {"/matches/:match_id/stream", stream_duel_api, []},
     {"/matches/:match_id/result", get_match_by_id_api, []},
     {"/leaderboard", get_leaderboard_api, []},
     {"/history", get_match_history_api, []}].

store_config() -> none.    %% No event sourcing needed

static_dir() -> "priv/static".

manifest() ->
    #{name => <<"hecate-app-snake-duel">>,
      display_name => <<"Snake Duel">>,
      version => <<"0.2.0">>,
      description => <<"AI vs AI Snake Duel Arena">>,
      icon => <<"snake">>,
      tag => <<"snake-duel-studio">>,
      min_sdk_version => <<"0.1.0">>}.
```

### Key decisions in the callback

**`init/1`** stores config in `persistent_term` so domain modules can access
paths without coupling to the plugin loader. Then starts the supervision tree.

**`routes/0`** returns *relative* paths. The daemon automatically mounts them
under `/plugin/hecate-app-snake-duel/api/`. So `/matches` becomes
`/plugin/hecate-app-snake-duel/api/matches`.

**`store_config/0`** returns `none` here because Snake Duel games are
ephemeral (live in memory, results go to SQLite). If your plugin uses event
sourcing, return a `#hecate_store_config{}` record instead.

**`manifest/0`** provides metadata for the daemon and frontend. The `tag`
field is the HTML custom element name (`<snake-duel-studio>`).

## Step 2: The Plugin Supervisor

Create `src/app_{name}_sup.erl` to supervise your domain applications:

```erlang
-module(app_snake_duel_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 60},
    Children = [
        #{id => query_snake_duel_sup,
          start => {query_snake_duel_sup, start_link, []},
          restart => permanent, type => supervisor},
        #{id => run_snake_duel_sup,
          start => {run_snake_duel_sup, start_link, []},
          restart => permanent, type => supervisor}
    ],
    {ok, {SupFlags, Children}}.
```

Start QRY before CMD. The QRY supervisor starts the SQLite store,
which CMD processes (like `duel_proc`) call to record results.

## Step 3: The OTP Application Shell

The root `.app.src` and `*_app.erl` are kept for OTP compliance but become
no-ops in plugin mode. The real work happens in the plugin callback.

```erlang
%% src/hecate_app_snake_dueld_app.erl
-module(hecate_app_snake_dueld_app).
-behaviour(application).
-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    logger:info("[hecate_app_snake_dueld] Application started (in-VM mode)"),
    hecate_app_snake_dueld_sup:start_link().

stop(_State) -> ok.
```

```erlang
%% src/hecate_app_snake_dueld_sup.erl — empty supervisor
init([]) ->
    {ok, {#{strategy => one_for_one, intensity => 10, period => 60}, []}}.
```

**Why keep them?** OTP requires an application callback. In standalone mode
(local development), the release config starts apps normally. In plugin mode,
the daemon calls `app_snake_duel:init/1` instead.

## Step 4: Domain Apps (Vertical Slices)

Organize business logic into domain apps under `apps/`:

```
apps/
  run_snake_duel/           CMD — game lifecycle
    src/
      run_snake_duel_sup.erl
      duel_proc_sup.erl     Dynamic supervisor for live duels
      duel_proc.erl         One gen_server per live game
      snake_duel_engine.erl Pure game logic (no side effects)
      snake_duel_ai.erl     AI decision making
      start_duel/           Desk: create a new duel
        start_duel_v1.erl
        duel_started_v1.erl
        maybe_start_duel.erl
        start_duel_api.erl
      stream_duel/          Desk: SSE streaming
        stream_duel_api.erl
  query_snake_duel/         QRY — match history, leaderboard
    src/
      query_snake_duel_sup.erl
      query_snake_duel_store.erl  SQLite gen_server
      get_leaderboard/
        get_leaderboard_api.erl
      get_match_history/
        get_match_history_api.erl
      get_match_by_id/
        get_match_by_id_api.erl
```

Each desk is a directory containing all related code. Directory names scream
business intent: `start_duel/`, `stream_duel/`, `get_leaderboard/`.

## Step 5: Path Resolution

Your domain modules need to find data directories. Use `persistent_term` to
bridge between the plugin config and your internal modules:

```erlang
-module(app_snake_dueld_paths).
-export([base_dir/0, sqlite_dir/0, sqlite_path/1, ensure_layout/0]).

base_dir() ->
    case persistent_term:get(app_snake_duel_config, undefined) of
        #{data_dir := DataDir} -> DataDir;
        undefined -> base_dir_fallback()
    end.

base_dir_fallback() ->
    case os:getenv("HECATE_HOME") of
        false ->
            case application:get_env(hecate_app_snake_dueld, data_dir) of
                {ok, Dir} -> expand_path(Dir);
                undefined -> expand_path("~/.hecate/hecate-app-snake-dueld")
            end;
        HecateHome ->
            filename:join(HecateHome, "hecate-app-snake-dueld")
    end.

sqlite_dir()   -> filename:join(base_dir(), "sqlite").
sqlite_path(N) -> filename:join(sqlite_dir(), N).

ensure_layout() ->
    Dirs = [sqlite_dir()],
    lists:foreach(fun(Dir) -> ok = filelib:ensure_path(Dir) end, Dirs).

expand_path("~/" ++ Rest) -> filename:join(os:getenv("HOME"), Rest);
expand_path(Path)         -> Path.
```

The pattern: check `persistent_term` first (in-VM mode), fall back to
application env or defaults (standalone mode). Your code works in both modes.

## Step 6: API Handlers

API handlers are standard cowboy handlers. Routes are declared in the plugin
callback, not in individual handler modules:

```erlang
-module(start_duel_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> app_snake_dueld_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case app_snake_dueld_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            %% Parse params, create command, dispatch
            {ok, Cmd} = start_duel_v1:new(Params),
            case maybe_start_duel:dispatch(Cmd) of
                {ok, MatchId, _Pid} ->
                    app_snake_dueld_api_utils:json_ok(201,
                        #{match_id => MatchId}, Req1);
                {error, Reason} ->
                    app_snake_dueld_api_utils:json_error(500, Reason, Req1)
            end;
        {error, invalid_json, Req1} ->
            app_snake_dueld_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.
```

Keep a small `api_utils` module for JSON response helpers. This is shared
infrastructure within your plugin, not a horizontal layer.

## Step 7: SSE Streaming via pg Groups

For real-time features (live game state, notifications), use OTP `pg` groups
and Server-Sent Events:

```erlang
%% In the game process — broadcast state to all SSE clients
broadcast(MatchId, Game) ->
    Msg = {snake_duel_state, game_to_map(MatchId, Game)},
    Members = pg:get_members(pg, {snake_duel, MatchId}),
    [Pid ! Msg || Pid <- Members, Pid =/= self()].

%% In the SSE handler — join group and forward to HTTP
start_stream(MatchId, Req0, _State) ->
    pg:join(pg, {snake_duel, MatchId}, self()),
    Req1 = cowboy_req:stream_reply(200, #{
        <<"content-type">> => <<"text/event-stream">>,
        <<"cache-control">> => <<"no-cache">>
    }, Req0),
    stream_loop(Req1).

stream_loop(Req) ->
    receive
        {snake_duel_state, StateMap} ->
            Data = iolist_to_binary(json:encode(StateMap)),
            cowboy_req:stream_body(
                <<"data: ", Data/binary, "\n\n">>, nofin, Req),
            stream_loop(Req);
        heartbeat ->
            cowboy_req:stream_body(<<": heartbeat\n\n">>, nofin, Req),
            erlang:send_after(15000, self(), heartbeat),
            stream_loop(Req)
    end.
```

The `pg` module is built into OTP. No external dependencies needed.

## Step 8: SQLite Read Models

For query endpoints that need persistence (leaderboard, history), use SQLite
via `esqlite`:

```erlang
-module(query_snake_duel_store).
-behaviour(gen_server).

init([]) ->
    ok = app_snake_dueld_paths:ensure_layout(),
    DbPath = app_snake_dueld_paths:sqlite_path("query_snake_duel.db"),
    {ok, Db} = esqlite3:open(DbPath),
    ok = esqlite3:exec(Db, "PRAGMA journal_mode=WAL;"),
    ok = esqlite3:exec(Db, "PRAGMA synchronous=NORMAL;"),
    ok = create_tables(Db),
    {ok, #state{db = Db}}.
```

The store creates its tables on startup and rebuilds from scratch if needed.
No migrations required for simple read models.

**esqlite3 gotcha:** `esqlite3:fetchall/1` returns a list of *lists*, not
tuples. Pattern match with `[Col1, Col2 | _]`, not `{Col1, Col2}`.

## Step 9: manifest.json

The root `manifest.json` is read by the daemon's plugin loader:

```json
{
  "name": "hecate-app-snake-duel",
  "version": "0.2.0",
  "icon": "\ud83d\udc0d",
  "description": "AI vs AI Snake Duel Arena",
  "tag": "snake-duel-studio",
  "callback_module": "app_snake_duel",
  "plugin_type": "in_vm",
  "min_daemon_version": "0.14.0",
  "appstore": {
    "plugin_name": "Snake Duel",
    "org": "hecate-apps",
    "tags": "game,arcade,snake,ai",
    "license_type": "free",
    "group_name": "GAMES",
    "group_icon": "gamepad-2"
  }
}
```

| Field | Purpose |
|-------|---------|
| `callback_module` | Erlang module implementing `hecate_plugin` |
| `plugin_type` | Must be `"in_vm"` |
| `tag` | HTML custom element name for the frontend |
| `appstore.group_name` | Sidebar group label (e.g. `"GAMES"`, `"OFFICE"`) |
| `appstore.group_icon` | Lucide icon name for the sidebar group (e.g. `"gamepad-2"`, `"briefcase"`) |
| `appstore` | Metadata shown in the Hecate AppStore UI |

## Step 10: rebar.config

Depend only on `hecate_sdk`. All platform libraries come transitively:

```erlang
{deps, [
    {cowboy, "2.12.0"},
    {esqlite, "0.8.8"},
    {hecate_sdk, "~> 0.1"}
]}.
```

**Why cowboy and esqlite are listed separately:** Your API handlers call
cowboy functions directly, and your SQLite store calls esqlite directly.
Listing them makes dialyzer aware of the dependency.

Do **not** add `reckon_db`, `evoq`, or `reckon_evoq` unless your plugin
actually uses event sourcing. They come via the SDK for plugins that need them.

Keep a `relx` section for standalone development, but it is not used in
plugin mode:

```erlang
{relx, [
    {release, {hecate_app_snake_dueld, "0.2.0"}, [
        hecate_app_snake_dueld,
        run_snake_duel,
        query_snake_duel,
        sasl
    ]},
    {mode, dev},
    {dev_mode, true},
    {include_erts, false},
    {extended_start_script, true}
]}.
```

## Step 11: The Frontend Web Component

The frontend is built as a web component (custom element) that the Hecate
desktop app mounts inside its plugin host page.

### Build setup (SvelteKit example)

```typescript
// svelte.config.js
export default {
    compilerOptions: {
        customElement: true  // Compile as web component
    }
};
```

### Root component

```svelte
<!-- src/lib/SnakeDuelStudio.svelte -->
<svelte:options customElement={{ tag: "snake-duel-studio", shadow: "none" }} />

<script lang="ts">
    let { api } = $props();  // Injected by hecate-web
</script>

<div class="snake-duel-container">
    <!-- Your UI here -->
</div>
```

The `api` prop is a `PluginApi` object injected by hecate-web. It provides:

- `api.fetch(path, options)` -- HTTP requests to your daemon routes
- `api.connectSse(path, handlers)` -- SSE streaming
- `api.getPluginUrl(path)` -- Resolve plugin-relative URLs

### API client

```typescript
let api: PluginApi;

export function setApi(pluginApi: PluginApi) { api = pluginApi; }

export async function startMatch(af1: number, af2: number, tickMs: number) {
    const res = await api.fetch('/matches', {
        method: 'POST',
        body: JSON.stringify({ af1, af2, tick_ms: tickMs })
    });
    return res.json();
}
```

Paths are relative. The API object handles prefixing.

### Build output

Build the frontend as an ES module that gets copied to `priv/static/`:

```bash
npm run build:lib   # Output: dist/component.js
cp dist/component.js ../hecate-app-snake-dueld/priv/static/
```

The daemon serves this at `/plugin/hecate-app-snake-duel/component.js`.
Hecate-web loads it dynamically and mounts the custom element.

## Step 12: CI/CD

With in-VM plugins, there is no OCI image to build. CI produces a plugin
tarball instead:

```yaml
# .github/workflows/ci.yml
jobs:
  package:
    name: Package plugin
    needs: [frontend, daemon]
    steps:
      - name: Package plugin tar.gz
        run: |
          mkdir -p _build/plugin/hecate-app-snake-duel/ebin
          mkdir -p _build/plugin/hecate-app-snake-duel/priv/static
          # Consolidate all .beam files from umbrella apps
          cp _build/default/lib/hecate_app_snake_dueld/ebin/*.beam \
             _build/plugin/hecate-app-snake-duel/ebin/
          for app in run_snake_duel query_snake_duel; do
            cp _build/default/lib/$app/ebin/*.beam \
               _build/plugin/hecate-app-snake-duel/ebin/
          done
          cp -r priv/static/* \
               _build/plugin/hecate-app-snake-duel/priv/static/
          cp ../manifest.json _build/plugin/hecate-app-snake-duel/
          cd _build/plugin
          tar czf hecate-app-snake-duel.tar.gz hecate-app-snake-duel/
```

The resulting `.tar.gz` is what gets distributed via the AppStore or manual
install.

## What NOT to Include

When converting from a standalone daemon to an in-VM plugin, remove:

| File | Why |
|------|-----|
| `Dockerfile` | No OCI image needed |
| `.github/workflows/docker.yml` | No image to push |
| `config/sys.config` | Daemon provides runtime config |
| `config/vm.args` | Daemon owns the VM |
| `*_health_api.erl` | Daemon provides `/health` |
| `*_manifest_api.erl` | Daemon auto-mounts manifests |
| `*_plugin_registrar.erl` | In-VM loading replaces socket registration |

These files exist to run the plugin as a standalone process. In plugin mode,
the daemon handles all of this.

## Checklist

Before shipping your plugin:

- [ ] `app_{name}.erl` implements `hecate_plugin` behaviour
- [ ] `app_{name}_sup.erl` supervises all domain apps
- [ ] Root `*_app.erl` is a no-op (in-VM mode)
- [ ] `manifest.json` has `callback_module` and `plugin_type: "in_vm"`
- [ ] Routes are relative (no `/api/...` prefix)
- [ ] Paths use `persistent_term` with standalone fallback
- [ ] Domain apps don't list each other in `.app.src` dependencies
- [ ] `rebar3 compile` succeeds
- [ ] `rebar3 eunit` passes
- [ ] Frontend builds as web component with correct `tag`
- [ ] `.beam` files from all umbrella apps included in package
- [ ] No standalone infrastructure remains (Dockerfile, health API, etc.)

## Next Steps

- [Getting Started](getting-started.html) for a minimal plugin
- [Plugin Architecture](plugin-architecture.html) for the full lifecycle
- [Observability](observability.html) for metrics, logging, and health
- [Packaging Guide](packaging.html) for distribution
