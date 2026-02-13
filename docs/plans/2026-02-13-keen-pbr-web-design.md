# keen-pbr-web Design

## Overview

Web UI for configuring keen-pbr on Keenetic routers running Entware.
Single Go binary with embedded Svelte SPA.

## Stack

- **Backend**: Go, net/http, pelletier/go-toml v2
- **Frontend**: Svelte 5, Vite, embedded via Go `embed`
- **Target**: Entware (mips, mipsel, aarch64)
- **Auth**: None (local network only)

## Architecture

Single Go binary (~5-8MB) serves:
- REST API at `/api/*`
- Embedded Svelte SPA at `/`

Reads/writes `/opt/etc/keen-pbr/keen-pbr.conf` (TOML).
Executes keen-pbr CLI commands for download/apply/self-check.

## API

| Method | URL | Description |
|--------|-----|-------------|
| GET | `/api/config` | Get config as JSON |
| PUT | `/api/config` | Save config (JSON -> TOML) |
| GET | `/api/lists` | List all list files |
| GET | `/api/lists/:name` | Get list file content |
| PUT | `/api/lists/:name` | Update list file content |
| POST | `/api/actions/download` | Run `keen-pbr download` |
| POST | `/api/actions/apply` | Restart keen-pbr + dnsmasq |
| POST | `/api/actions/self-check` | Run `keen-pbr self-check` |
| GET | `/api/status` | Status info |

## UI Pages

1. **Dashboard** - Status, action buttons (Download/Apply/Self-Check), command output
2. **Lists** - View/edit inline and file-based lists, view URL-based lists
3. **IPSets** - View ipset configs, list-to-interface bindings
4. **Config** - Raw TOML editor as fallback

## Config paths

- Config: `/opt/etc/keen-pbr/keen-pbr.conf` (configurable via CLI flag)
- Lists dir: from config `general.lists_output_dir`
- Default port: 3000

## Init script

`/opt/etc/init.d/S99keen-pbr-web` for autostart.
