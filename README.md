# Hecate Plugin SDK

The contract between the Hecate daemon and plugins.

Plugins are OTP applications that load into the daemon VM. The SDK provides:

- **Platform dependencies** — pinned versions, one `{hecate_sdk, "~> 0.4"}` dep
- **Plugin behaviour** — `hecate_plugin` callbacks the daemon calls
- **Observability** — structured JSON logging, metrics, health reporting (auto-wired)
- **Helpers** — paths, store setup, cowboy routes, WebSocket, validation, scheduling, rate limiting, file I/O

## Quick Start

```erlang
%% rebar.config
{deps, [
    {hecate_sdk, "~> 0.4"}
]}.
```

Implement the `hecate_plugin` behaviour:

```erlang
-module(my_plugin).
-behaviour(hecate_plugin).
-include_lib("hecate_sdk/include/hecate_plugin.hrl").

-export([init/1, routes/0, store_config/0, static_dir/0, manifest/0]).

init(_Config) ->
    {ok, #{}}.

routes() ->
    [{"/items", my_plugin_items_api, []},
     {"/items/:id", my_plugin_item_api, []}].

store_config() ->
    #hecate_store_config{
        store_id = my_items_store,
        dir_name = "items",
        description = "My plugin items store"
    }.

static_dir() ->
    code:priv_dir(my_plugin) ++ "/static".

manifest() ->
    #{
        name => <<"my-plugin">>,
        version => <<"0.1.0">>,
        min_sdk_version => <<"0.1.0">>,
        description => <<"My awesome plugin">>,
        native_capabilities => #{
            notifications => true
        }
    }.
```

## What You Get

### Platform Dependencies (all come transitively)

| Concern | Library |
|---------|---------|
| Event Sourcing | evoq |
| Event Store | reckon_db + reckon_gater + reckon_evoq |
| HTTP/WebSocket | cowboy |
| Read Models | esqlite (SQLite) |
| Mesh | macula |
| HTTP Client | hackney |
| Time | qdate |
| AI/ML | faber_tweann + faber_neuroevolution |
| Protobuf | gpb (optional) |

Plus OTP builtins: `json`, `ets`, `pg`, `logger`, `crypto`, `calendar`, `mnesia`.

### SDK Helpers

| Module | Purpose |
|--------|---------|
| `hecate_plugin` | Behaviour definition |
| `hecate_plugin_metrics` | Counters + gauges (lock-free) |
| `hecate_plugin_telemetry` | Auto-attach to evoq/reckon-db events |
| `hecate_plugin_logger` | JSON log formatter for OTP logger |
| `hecate_plugin_paths` | Standard directory layout |
| `hecate_plugin_store` | ReckonDB store creation + dispatch |
| `hecate_plugin_cowboy` | Route prefixing + static serving |
| `hecate_plugin_ws` | WebSocket upgrade + JSON framing |
| `hecate_plugin_validate` | Input validation rules |
| `hecate_plugin_scheduler` | Cron-like recurring tasks |
| `hecate_plugin_ratelimit` | Token bucket rate limiter |
| `hecate_plugin_files` | Upload/download helpers |
| `hecate_plugin_api` | JSON request/response utilities for Cowboy handlers |
| `hecate_plugin_routes` | Route discovery from OTP app metadata |
| `hecate_plugin_llm` | Capability-based LLM model selection |

## Frontend

Plugin frontends are static assets (HTML/JS/CSS) served by the daemon at `/plugin/{name}/`.
Build with any framework (SvelteKit, React, plain HTML) — just output to `priv/static/`.

Your frontend talks to the backend via:
- REST: `fetch('/plugin/{name}/api/...')`
- WebSocket: `new WebSocket('ws://localhost:4444/plugin/{name}/ws')`

For native OS access (file pickers, notifications, clipboard), use the Tauri bridge:
```javascript
window.__hecate_bridge.request({ action: 'file-picker', options: {} })
```

## License

Apache-2.0
