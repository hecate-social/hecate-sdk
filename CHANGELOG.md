# Changelog

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
