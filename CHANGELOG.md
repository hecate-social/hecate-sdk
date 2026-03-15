# Changelog

## 0.5.0 — 2026-03-15

### Added

- `hecate_plugin_codegen` — code generation for plugin scaffolding
  - `plugin/1` — full plugin skeleton (callback, supervisor, app.src, rebar.config, manifest.json)
  - `division/1` — aggregate + state + state/status headers + CMD/PRJ/QRY department apps
  - `desk/1` — CMD desk (command, event, handler, API, tests), PRJ desk (projection, tests), QRY desk (page/by_id endpoint, tests)
  - `integration/1` — emitter, listener, process manager, requester, responder (each with supervisor)
  - All functions idempotent (skip existing files), return `{ok, [FilePath]}`
  - Templates split across 5 focused sub-modules for maintainability:
    - `hecate_plugin_codegen_plugin` — plugin + division templates
    - `hecate_plugin_codegen_cmd` — CMD desk templates
    - `hecate_plugin_codegen_prj` — PRJ desk templates
    - `hecate_plugin_codegen_qry` — QRY desk templates
    - `hecate_plugin_codegen_integration` — integration templates
  - Designed for Martha's coder agent roles to call programmatically from BEAM

## 0.4.2 — 2026-03-15

### Added

- `hecate_plugin_routes` — route discovery from OTP app metadata
  - `discover_routes/1` — scans app modules for `routes/0` exports, collects route tuples
  - `strip_api_prefix/1` — removes "/api" prefix to avoid double-nesting under plugin mount
  - Plugins no longer need to copy-paste route discovery logic
- `hecate_plugin_store:start_extra_stores/2` — create additional ReckonDB stores
  - Takes base data dir + list of `{StoreId, SubDir, Label}` specs
  - Handles directory creation, store startup, already_started, and error logging
- `hecate_plugin_store:start_subscriptions/1` — start evoq event delivery for stores
  - Wires up `evoq_store_subscription` for each store ID

## 0.4.1 — 2026-03-15

### Added

- `hecate_plugin_api` — JSON API utilities for plugin Cowboy handlers
  - `json_response/3`, `json_ok/2,3`, `json_error/3` — consistent JSON responses
  - `read_json_body/1` — decode JSON request bodies
  - `get_field/2,3` — extract fields from maps with atom/binary key support
  - `format_error/1` — convert error terms to binary
  - `sanitize_for_json/1` — recursively convert `undefined` to `null`
  - `method_not_allowed/1`, `not_found/1`, `bad_request/2` — standard HTTP errors
  - Built-in metric counting: api_requests on every response, api_errors on error responses
  - Plugins no longer need to copy-paste api_utils modules

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
