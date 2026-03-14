# Plugin Observability

Hecate 0.4.0 gives plugins structured logging, metrics, and health reporting
out of the box. Zero plugin code changes needed for the basics — the daemon
auto-wires observability when your plugin loads.

## What You Get For Free

When the daemon loads your plugin, it automatically:

1. **Initializes a metrics namespace** for your plugin
2. **Attaches telemetry handlers** to your event store (if you have one)
3. **Sets logger metadata** with your plugin name and version
4. **Collects health status** from your plugin (if you implement `health/0`)

This means your plugin's evoq commands, projections, and reckon-db operations
show up in `/metrics` without any code on your part.

## Structured JSON Logging

All log output is now JSON. Every log line your plugin emits includes the
plugin name automatically:

```json
{"ts":"2026-03-15T10:30:00.123456Z","level":"info","msg":"Store ready","plugin":"hecate-app-martha","pid":"<0.456.0>"}
```

No changes needed in your plugin code. Continue using `logger:info/1,2` as
normal — the daemon's JSON formatter enriches the output.

The `plugin` field comes from logger metadata set during plugin load. If you
spawn long-lived processes, propagate the metadata:

```erlang
%% In a gen_server init/1 that your plugin starts
init(Args) ->
    logger:update_process_metadata(#{plugin_name => <<"my-plugin">>}),
    {ok, #state{}}.
```

## Custom Metrics

For plugin-specific metrics beyond the auto-wired telemetry, use the macros
in `hecate_plugin.hrl`:

```erlang
-include_lib("hecate_sdk/include/hecate_plugin.hrl").

handle_request(Req, State) ->
    ?METRIC_INC(<<"api_requests">>),
    Body = process(Req),
    ?METRIC_ADD(<<"bytes_sent">>, byte_size(Body)),
    reply(200, Body, Req, State).

check_queue(State) ->
    Depth = length(State#state.queue),
    ?METRIC_SET(<<"queue_depth">>, Depth),
    State.
```

Three macros are available:

| Macro | Type | Description |
|-------|------|-------------|
| `?METRIC_INC(Name)` | counter | Increment by 1 |
| `?METRIC_ADD(Name, N)` | counter | Increment by N |
| `?METRIC_SET(Name, Val)` | gauge | Set to value |

Metric names are binaries. They appear in the `/metrics` endpoint with your
plugin name as a label:

```
# TYPE hecate_plugin_api_requests counter
hecate_plugin_api_requests{plugin="hecate-app-martha"} 42

# TYPE hecate_plugin_queue_depth gauge
hecate_plugin_queue_depth{plugin="hecate-app-martha"} 7
```

### How the macros work

The macros resolve your plugin name from `persistent_term` at call time.
The daemon sets `persistent_term:put(hecate_current_plugin, PluginName)`
during plugin load. Your plugin callback's `init/1` typically stores config
in `persistent_term` — the metrics use the same mechanism.

### Using the metrics API directly

If you prefer not to use macros, call `hecate_plugin_metrics` directly:

```erlang
hecate_plugin_metrics:counter(<<"my-plugin">>, <<"requests">>, 1).
hecate_plugin_metrics:gauge(<<"my-plugin">>, <<"connections">>, 5).
```

## Auto-Wired Telemetry Metrics

Plugins with an event store get these metrics automatically:

| Metric | Type | Source |
|--------|------|--------|
| `evoq_commands_dispatched` | counter | `[evoq, dispatch, stop]` |
| `evoq_commands_failed` | counter | `[evoq, dispatch, exception]` |
| `evoq_events_projected` | counter | `[evoq, projection, event]` |
| `evoq_projection_errors` | counter | `[evoq, projection, exception]` |
| `evoq_last_execute_duration_us` | gauge | `[evoq, aggregate, execute, stop]` |
| `reckon_db_stream_writes` | counter | `[reckon_db, stream, write, stop]` |
| `reckon_db_stream_reads` | counter | `[reckon_db, stream, read, stop]` |
| `reckon_db_events_delivered` | counter | `[reckon_db, subscription, event_delivered]` |

Each handler checks the `store_id` in telemetry metadata to ensure metrics
are attributed to the correct plugin. The daemon's own stores appear under
`plugin="hecate"`.

## Health Reporting

Implement the optional `health/0` callback to report plugin health:

```erlang
-module(app_martha).
-behaviour(hecate_plugin).

-export([health/0]).
%% ... other callbacks ...

health() ->
    case check_llm_connectivity() of
        ok -> ok;
        {error, timeout} -> degraded;
        {error, Reason} -> {unhealthy, iolist_to_binary(io_lib:format("~p", [Reason]))}
    end.
```

Return values:

| Value | Meaning |
|-------|---------|
| `ok` | Fully functional |
| `degraded` | Running with reduced capability |
| `{unhealthy, Reason}` | Not functional, with explanation |

If you don't implement `health/0`, your plugin is assumed healthy.

The daemon aggregates plugin health into `GET /health`:

```json
{
  "status": "healthy",
  "ready": true,
  "service": "hecate",
  "version": "0.16.3",
  "plugins": {
    "hecate-app-martha": "ok",
    "hecate-app-scribe": "degraded"
  }
}
```

## The `/metrics` Endpoint

`GET /metrics` returns Prometheus text exposition format, scrapeable by
Prometheus, VictoriaMetrics, Grafana Agent, or any compatible tool.

The endpoint includes both plugin metrics and daemon-level metrics:

```
# TYPE hecate_plugin_evoq_commands_dispatched counter
hecate_plugin_evoq_commands_dispatched{plugin="hecate-app-martha"} 42
hecate_plugin_evoq_commands_dispatched{plugin="hecate"} 156

# TYPE hecate_daemon_memory_bytes gauge
hecate_daemon_memory_bytes 134217728

# TYPE hecate_daemon_process_count gauge
hecate_daemon_process_count 1234

# TYPE hecate_daemon_uptime_seconds gauge
hecate_daemon_uptime_seconds 86400
```

### Scraping with Prometheus

Add to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'hecate'
    static_configs:
      - targets: ['localhost:4444']
    metrics_path: '/metrics'
```

Prometheus is not required — the endpoint is there when you need it.

## Architecture

```
Plugin code                      SDK (auto-wired by loader)
----                             ----
logger:info(Msg)          -->    hecate_plugin_logger (JSON formatter)
                                   --> journald (machine-parseable)

?METRIC_INC(Name)         -->    hecate_plugin_metrics (counters + ETS)
                                   --> GET /metrics (Prometheus text)

health/0 callback         -->    hecate_plugin_loader collects
                                   --> GET /health {plugins: {...}}

(automatic)               -->    hecate_plugin_telemetry
                                   attaches to evoq + reckon_db events
                                   --> feeds hecate_plugin_metrics
```

### Implementation details

**Metrics storage:** One `counters:new(64, [write_concurrency])` per plugin,
backed by atomics (lock-free). An ETS table maps `{PluginName, MetricName}`
to counter slots. This is extremely lightweight — no processes, no message
passing.

**Telemetry bridging:** `hecate_plugin_telemetry` attaches OTP `telemetry`
handlers to existing evoq and reckon-db events. Handlers filter by `store_id`
in metadata, so each plugin's metrics are isolated.

**Logger formatter:** `hecate_plugin_logger` implements the OTP `logger`
formatter behaviour. It uses the built-in `json` module (OTP 27+). Messages
are truncated at 4096 characters.

## Lifecycle

| Event | What happens |
|-------|-------------|
| Plugin loads | Metrics initialized, telemetry attached, logger metadata set |
| Plugin runs | Telemetry auto-increments, macros available |
| Plugin unloads | Telemetry detached, metrics cleaned up |

No cleanup needed in your plugin code — the daemon handles it.
