# Changelog

## 0.4.0 — 2026-03-15

### Added

- `hecate_plugin_metrics` — lightweight metrics facade using OTP `counters` + ETS
  - `counter/3` for monotonically increasing values
  - `gauge/3` for point-in-time values
  - `get_all/0` and `get_plugin/1` for reading metrics
  - `?METRIC_INC`, `?METRIC_ADD`, `?METRIC_SET` macros in `hecate_plugin.hrl`
- `hecate_plugin_telemetry` — auto-attaches to evoq and reckon-db telemetry events
  - 8 handlers: dispatch, projection, aggregate execute, stream write/read, subscription delivery
  - Filters by `store_id` for per-plugin metric isolation
- `hecate_plugin_logger` — OTP logger JSON formatter
  - One JSON line per log event with timestamp, level, message, plugin name
  - Enriches output with logger metadata (plugin_name, mfa, pid, domain)
  - Truncates messages at 4096 characters
- Optional `health/0` callback on `hecate_plugin` behaviour
  - Return `ok`, `degraded`, or `{unhealthy, Reason}`
  - Plugins that don't implement it are assumed healthy
- `telemetry` as explicit dependency (was transitive via evoq)
- Observability guide (`guides/observability.md`)

## 0.3.0 — 2026-03-14

- Add `hecate_plugin_llm` — capability-based LLM model selection for plugins
  - `select_model/1` — pick a model by capability tier (fast/balanced/smart)
  - `list_models/0` — list all daemon-managed models
  - `chat/2,3` and `chat_stream/3` — delegate to daemon's serve_llm domain
  - Classifies models by name patterns (Claude, GPT, Gemini, etc.) and parameter size
  - Optional provider filtering via `#{provider => <<"openai">>}`
- Bump evoq dependency to 1.9.1

## 0.2.0 — 2026-03-09

- Add `flag_maps/0` callback to `hecate_plugin` behaviour
  - Every plugin with CMD aggregates exposes its bit flag maps
  - Daemon auto-mounts at `GET /plugin/{name}/api/flag-maps`
  - Frontends decode raw status integers into labels
- Add guide extras to ex_doc configuration

## 0.1.0 — 2026-03-09

Initial release.

- `hecate_plugin` behaviour with callbacks: `init/1`, `routes/0`, `store_config/0`, `static_dir/0`, `manifest/0`
- `hecate_plugin_paths` — standard directory layout for plugin data
- `hecate_plugin_store` — ReckonDB store creation and command dispatch
- `hecate_plugin_cowboy` — route prefixing and static file serving
- `hecate_plugin_ws` — WebSocket upgrade and JSON message framing
- `hecate_plugin_validate` — input validation with type checking
- `hecate_plugin_scheduler` — periodic task scheduling
- `hecate_plugin_ratelimit` — token bucket rate limiter
- `hecate_plugin_files` — file upload/download helpers
- Platform dependencies pinned: evoq, reckon_db, reckon_gater, reckon_evoq, cowboy, esqlite, macula, hackney, qdate, faber_tweann, faber_neuroevolution, gpb
