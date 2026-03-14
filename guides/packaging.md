# Packaging Guide

This guide covers how to build, package, and distribute your Hecate plugin.

## Package Format

A plugin package is a `.tar.gz` archive containing:

```
scribe.tar.gz
  ebin/               All compiled .beam files
  priv/static/        Frontend assets (optional)
  manifest.json       Plugin metadata
```

The daemon extracts this to `~/.hecate/plugins/{name}/` and loads the code into the VM.

## manifest.json

Every package must include a `manifest.json`:

```json
{
  "name": "my-plugin",
  "version": "0.1.0",
  "callback_module": "my_plugin",
  "description": "What my plugin does",
  "icon": "puzzle-piece",
  "plugin_type": "in_vm",
  "min_sdk_version": "0.1.0"
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique plugin identifier (lowercase, hyphens allowed) |
| `version` | Yes | Semver version string |
| `callback_module` | Yes | Erlang module implementing `hecate_plugin` |
| `plugin_type` | Yes | Must be `"in_vm"` |
| `min_sdk_version` | Yes | Minimum SDK version required |
| `description` | No | Human-readable description |
| `icon` | No | Icon name (Lucide icon set) |

## Building the Package

### Single-App Plugin

For a simple plugin with one OTP application:

```bash
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
BUILD_DIR="_build/plugin"
STAGING_DIR="$BUILD_DIR/staging"

rebar3 compile

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/ebin"

cp _build/default/lib/my_plugin/ebin/*.beam "$STAGING_DIR/ebin/"

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
```

### Umbrella Plugin

For plugins with multiple OTP applications (CMD, PRJ, QRY):

```bash
# Consolidate .beam files from all apps into one ebin/
for ebin_dir in \
    "_build/default/lib/my_plugin/ebin" \
    "_build/default/lib/guide_item_lifecycle/ebin" \
    "_build/default/lib/project_items/ebin" \
    "_build/default/lib/query_items/ebin"; do
    if [ -d "$ebin_dir" ]; then
        cp "$ebin_dir"/*.beam "$STAGING_DIR/ebin/" 2>/dev/null || true
    fi
done
```

All `.beam` files go into a single `ebin/` directory. The daemon adds this one path to the code loader.

### Frontend Assets

If your plugin has a web frontend, build it and include the output:

```bash
# Build frontend (SvelteKit, React, etc.)
cd frontend && npm run build

# Copy to staging
mkdir -p "$STAGING_DIR/priv"
cp -r frontend/build "$STAGING_DIR/priv/static"
```

The daemon serves these at `/plugin/{name}/` automatically.

## Installing a Package

### Manual Installation

```bash
# Place the tarball
mkdir -p ~/.hecate/plugins/my-plugin/
cp my-plugin.tar.gz ~/.hecate/plugins/my-plugin/

# Tell the daemon to install it
curl -X POST http://localhost:4444/api/plugins/install \
  -H 'Content-Type: application/json' \
  -d '{
    "plugin_id": "my-plugin",
    "plugin_type": "in_vm",
    "callback_module": "my_plugin"
  }'
```

### Via the AppStore

When published to the Hecate AppStore, users install with one click. The daemon:

1. Downloads the `.tar.gz` to `~/.hecate/plugins/{name}/`
2. Dispatches the install command
3. Process managers handle extract, activate, load automatically

## Version Upgrades

To upgrade a plugin:

1. Build the new package
2. Replace the tarball at `~/.hecate/plugins/{name}/{name}.tar.gz`
3. The daemon can reload via `hecate_plugin_loader:reload_plugin/2`

Reload is atomic: unload old code, load new code. Running requests complete before unload.

## Dependency Management

Your plugin should depend only on `hecate_sdk`. All platform libraries come transitively:

```erlang
%% rebar.config
{deps, [
    {hecate_sdk, "0.1.0"}
]}.
```

Do **not** add `cowboy`, `evoq`, `reckon_db`, etc. as direct dependencies. Version conflicts will break loading.

If you need a library not in the SDK, add it as a dependency and include its `.beam` files in your package's `ebin/`.

## Troubleshooting

### "ebin_not_found" error

The daemon looks for `ebin/` at `~/.hecate/plugins/{name}/ebin/`. Check:
- Did the tarball extract correctly?
- Is the tarball structure flat (files at root, not nested in a subdirectory)?

### "callback_not_loadable" error

The callback module's `.beam` file is not in `ebin/`. Check:
- Is the module name in `manifest.json` correct?
- Did `rebar3 compile` succeed before packaging?
- Is the `.beam` file included in the tarball?

### Routes not appearing

Check that your `routes/0` returns valid cowboy routes. The daemon logs route count during hot-swap:
```
[plugin-loader] Routes hot-swapped (3 plugin API, 1 plugin static)
```

### Store not created

If `store_config/0` returns a config but the store fails:
- Check that ReckonDB infrastructure is running (the daemon starts it at boot)
- Check logs for `[plugin-store] Creating ...` messages
- Verify your `store_id` atom is unique across all plugins
