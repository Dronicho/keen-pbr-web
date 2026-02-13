# keen-pbr-web Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Web UI for configuring keen-pbr on Keenetic routers — manage lists, ipsets, and restart services.

**Architecture:** Go HTTP server with embedded Svelte 5 SPA. Go reads/writes TOML config and executes keen-pbr CLI commands. Svelte frontend built with Vite via Bun, output embedded into Go binary via `embed`.

**Tech Stack:** Go 1.25, pelletier/go-toml v2, Svelte 5, Vite, Bun, TailwindCSS

---

### Task 1: Initialize Go module and project structure

**Files:**
- Create: `go.mod`
- Create: `main.go`
- Create: `Makefile`

**Step 1: Init Go module**

Run: `cd /Users/dronich/personal/keen-pbr-web && go mod init keen-pbr-web`

**Step 2: Create main.go skeleton**

```go
package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
)

func main() {
	port := flag.Int("port", 3000, "HTTP server port")
	flag.Parse()

	addr := fmt.Sprintf(":%d", *port)
	log.Printf("keen-pbr-web starting on %s", addr)
	log.Fatal(http.ListenAndServe(addr, nil))
}
```

**Step 3: Create Makefile**

```makefile
.PHONY: dev build frontend backend clean

FRONTEND_DIR = frontend
BACKEND_DIR = .
BUILD_DIR = dist

dev-backend:
	go run main.go -config ./testdata/keen-pbr.conf

dev-frontend:
	cd $(FRONTEND_DIR) && bun run dev

frontend:
	cd $(FRONTEND_DIR) && bun run build

backend: frontend
	go build -o $(BUILD_DIR)/keen-pbr-web .

build: backend

clean:
	rm -rf $(BUILD_DIR) $(FRONTEND_DIR)/dist
```

**Step 4: Create testdata directory with example config**

Create `testdata/keen-pbr.conf` with the example config from keen-pbr repo (for local development).

Create `testdata/lists.d/` with a sample `local.lst`.

**Step 5: Verify**

Run: `go build -o /dev/null .`
Expected: compiles without errors

**Step 6: Commit**

```bash
git init && git add -A && git commit -m "feat: init Go project structure"
```

---

### Task 2: Initialize Svelte frontend with Bun

**Files:**
- Create: `frontend/` (Svelte project via Bun)

**Step 1: Scaffold Svelte project**

Run:
```bash
cd /Users/dronich/personal/keen-pbr-web
bun create svelte@latest frontend
```

Choose: Skeleton project, TypeScript, no additional options.

Then:
```bash
cd frontend && bun install
```

**Step 2: Add TailwindCSS**

```bash
cd /Users/dronich/personal/keen-pbr-web/frontend
bun add -d tailwindcss @tailwindcss/vite
```

Update `frontend/vite.config.ts` to add TailwindCSS plugin and proxy API requests to Go backend:

```ts
import { sveltekit } from '@sveltejs/kit';
import tailwindcss from '@tailwindcss/vite';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [tailwindcss(), sveltekit()],
});
```

Add to `frontend/src/app.css`:
```css
@import 'tailwindcss';
```

**Step 3: Configure SvelteKit as SPA (static adapter)**

```bash
cd /Users/dronich/personal/keen-pbr-web/frontend
bun add -d @sveltejs/adapter-static
```

Update `frontend/svelte.config.js`:
```js
import adapter from '@sveltejs/adapter-static';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

export default {
	preprocess: vitePreprocess(),
	kit: {
		adapter: adapter({
			pages: 'dist',
			assets: 'dist',
			fallback: 'index.html'
		})
	}
};
```

**Step 4: Verify frontend builds**

Run: `cd /Users/dronich/personal/keen-pbr-web/frontend && bun run build`
Expected: `frontend/dist/` directory with `index.html`

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: init Svelte frontend with Bun + TailwindCSS"
```

---

### Task 3: Go embed + static file serving

**Files:**
- Create: `server/static.go`
- Modify: `main.go`

**Step 1: Create static.go for embedding frontend dist**

```go
package main

import (
	"embed"
	"io/fs"
	"net/http"
	"strings"
)

//go:embed frontend/dist/*
var frontendFS embed.FS

func staticHandler() http.Handler {
	dist, _ := fs.Sub(frontendFS, "frontend/dist")
	fileServer := http.FileServer(http.FS(dist))

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// API routes are not handled here
		if strings.HasPrefix(r.URL.Path, "/api/") {
			http.NotFound(w, r)
			return
		}
		// Try to serve static file, fallback to index.html for SPA routing
		fileServer.ServeHTTP(w, r)
	})
}
```

**Step 2: Update main.go to use mux with static handler**

Wire up the static handler as the default fallback in the HTTP mux.

**Step 3: Build and test**

Run: `make build && ./dist/keen-pbr-web -port 3000`
Open: `http://localhost:3000` — should show Svelte app

**Step 4: Commit**

```bash
git add -A && git commit -m "feat: embed Svelte dist into Go binary"
```

---

### Task 4: Config TOML parsing (Go backend)

**Files:**
- Create: `internal/config/config.go`
- Create: `internal/config/config_test.go`

**Step 1: Add go-toml dependency**

Run: `go get github.com/pelletier/go-toml/v2`

**Step 2: Write config structs**

```go
package config

type Config struct {
	General General `toml:"general" json:"general"`
	IPSets  []IPSet `toml:"ipset" json:"ipsets"`
	Lists   []List  `toml:"list" json:"lists"`
}

type General struct {
	ListsOutputDir string `toml:"lists_output_dir" json:"lists_output_dir"`
	UseKeeneticAPI bool   `toml:"use_keenetic_api" json:"use_keenetic_api"`
	UseKeeneticDNS bool   `toml:"use_keenetic_dns" json:"use_keenetic_dns"`
	FallbackDNS    string `toml:"fallback_dns" json:"fallback_dns"`
}

type IPSet struct {
	IPSetName          string   `toml:"ipset_name" json:"ipset_name"`
	Lists              []string `toml:"lists" json:"lists"`
	IPVersion          int      `toml:"ip_version" json:"ip_version"`
	FlushBeforeApplying bool   `toml:"flush_before_applying" json:"flush_before_applying"`
	Routing            Routing  `toml:"routing" json:"routing"`
}

type Routing struct {
	Interfaces  []string `toml:"interfaces" json:"interfaces"`
	KillSwitch  bool     `toml:"kill_switch" json:"kill_switch"`
	FWMark      int      `toml:"fwmark" json:"fwmark"`
	Table       int      `toml:"table" json:"table"`
	Priority    int      `toml:"priority" json:"priority"`
	OverrideDNS string   `toml:"override_dns,omitempty" json:"override_dns,omitempty"`
}

type List struct {
	ListName string   `toml:"list_name" json:"list_name"`
	URL      string   `toml:"url,omitempty" json:"url,omitempty"`
	File     string   `toml:"file,omitempty" json:"file,omitempty"`
	Hosts    []string `toml:"hosts,omitempty" json:"hosts,omitempty"`
}
```

**Step 3: Write Load/Save functions**

```go
func Load(path string) (*Config, error)
func Save(path string, cfg *Config) error
```

Use `toml.Unmarshal` / `toml.Marshal`.

**Step 4: Write test using testdata/keen-pbr.conf**

Test that Load parses the example config correctly, and Save round-trips it.

**Step 5: Run tests**

Run: `go test ./internal/config/ -v`
Expected: PASS

**Step 6: Commit**

```bash
git add -A && git commit -m "feat: TOML config parsing with Load/Save"
```

---

### Task 5: API handlers — config endpoints

**Files:**
- Create: `internal/api/api.go`
- Create: `internal/api/config_handler.go`

**Step 1: Create API router setup**

```go
package api

type Server struct {
	configPath string
	mux        *http.ServeMux
}

func New(configPath string) *Server
func (s *Server) Handler() http.Handler
```

**Step 2: Implement GET /api/config**

Read TOML, return JSON.

**Step 3: Implement PUT /api/config**

Accept JSON, write TOML.

**Step 4: Test manually with curl**

Run server, then:
```bash
curl http://localhost:3000/api/config | jq .
```

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: GET/PUT /api/config endpoints"
```

---

### Task 6: API handlers — lists endpoints

**Files:**
- Create: `internal/api/lists_handler.go`

**Step 1: Implement GET /api/lists**

Scan the lists from config — return list of list names with their types (inline/file/url).

**Step 2: Implement GET /api/lists/{name}**

For file-based lists: read the file, return lines as JSON array.
For inline lists: return hosts from config.
For URL lists: return the URL (content is remote).

**Step 3: Implement PUT /api/lists/{name}**

For file-based: write lines to file.
For inline: update config hosts array and save TOML.

**Step 4: Test with curl**

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: lists API endpoints"
```

---

### Task 7: API handlers — actions endpoints

**Files:**
- Create: `internal/api/actions_handler.go`

**Step 1: Implement POST /api/actions/download**

Execute `keen-pbr download`, stream output as response.

**Step 2: Implement POST /api/actions/apply**

Execute:
1. `/opt/etc/init.d/S80keen-pbr restart`
2. `/opt/etc/init.d/S56dnsmasq restart`

Return combined output.

**Step 3: Implement POST /api/actions/self-check**

Execute `keen-pbr self-check`, return output.

**Step 4: Implement GET /api/status**

Return JSON with:
- keen-pbr version (from `keen-pbr --version` or similar)
- config path
- lists count

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: action endpoints (download, apply, self-check)"
```

---

### Task 8: Svelte — layout and navigation

**Files:**
- Modify: `frontend/src/routes/+layout.svelte`
- Create: `frontend/src/lib/components/Nav.svelte`

**Step 1: Create layout with sidebar navigation**

Pages: Dashboard, Lists, IPSets, Config.
Use TailwindCSS for styling. Clean minimal design suitable for router admin panel.

**Step 2: Verify dev mode works**

Run: `cd frontend && bun run dev`
Check: navigation works between pages.

**Step 3: Commit**

```bash
git add -A && git commit -m "feat: Svelte layout with navigation"
```

---

### Task 9: Svelte — Dashboard page

**Files:**
- Modify: `frontend/src/routes/+page.svelte`
- Create: `frontend/src/lib/api.ts`

**Step 1: Create API client module**

```ts
const API_BASE = '/api';

export async function getConfig() { ... }
export async function getStatus() { ... }
export async function runAction(action: string) { ... }
// etc.
```

**Step 2: Build Dashboard page**

- Status card (config path, lists count)
- Three action buttons: Download Lists, Apply Config, Self-Check
- Output area showing command results
- Loading states for actions

**Step 3: Commit**

```bash
git add -A && git commit -m "feat: Dashboard page with action buttons"
```

---

### Task 10: Svelte — Lists page

**Files:**
- Create: `frontend/src/routes/lists/+page.svelte`
- Create: `frontend/src/lib/components/ListEditor.svelte`

**Step 1: Build Lists page**

- Show all lists from config
- For each list show type badge (inline/file/url)
- Click to expand/edit

**Step 2: Build ListEditor component**

- For inline/file lists: textarea with one entry per line
- Add entry input (IP/domain/CIDR) with validation
- Save button → PUT /api/lists/{name}
- For URL lists: show URL as read-only

**Step 3: Commit**

```bash
git add -A && git commit -m "feat: Lists page with editor"
```

---

### Task 11: Svelte — IPSets page

**Files:**
- Create: `frontend/src/routes/ipsets/+page.svelte`

**Step 1: Build IPSets page**

- Show all ipsets from config
- For each: name, interfaces, lists, routing params
- Read-only view (editing ipsets is complex, use Config page for that)

**Step 2: Commit**

```bash
git add -A && git commit -m "feat: IPSets overview page"
```

---

### Task 12: Svelte — Config page (raw editor)

**Files:**
- Create: `frontend/src/routes/config/+page.svelte`

**Step 1: Add raw TOML endpoint to Go API**

Add `GET /api/config/raw` — returns raw TOML string.
Add `PUT /api/config/raw` — accepts raw TOML string, validates, saves.

**Step 2: Build Config page**

- Textarea with monospace font showing raw TOML
- Save button
- Error display if TOML is invalid

**Step 3: Commit**

```bash
git add -A && git commit -m "feat: raw TOML config editor page"
```

---

### Task 13: Wire everything together + build

**Files:**
- Modify: `main.go` — wire all API routes and static handler

**Step 1: Update main.go**

```go
func main() {
	port := flag.Int("port", 3000, "HTTP server port")
	configPath := flag.String("config", "/opt/etc/keen-pbr/keen-pbr.conf", "path to keen-pbr config")
	flag.Parse()

	apiServer := api.New(*configPath)
	mux := http.NewServeMux()
	mux.Handle("/api/", apiServer.Handler())
	mux.Handle("/", staticHandler())

	addr := fmt.Sprintf(":%d", *port)
	log.Printf("keen-pbr-web listening on %s (config: %s)", addr, *configPath)
	log.Fatal(http.ListenAndServe(addr, mux))
}
```

**Step 2: Full build and test**

```bash
make build
./dist/keen-pbr-web -config ./testdata/keen-pbr.conf -port 3000
```

Open http://localhost:3000, verify all pages work.

**Step 3: Commit**

```bash
git add -A && git commit -m "feat: wire API + frontend, full build working"
```

---

### Task 14: Cross-compilation and init script

**Files:**
- Modify: `Makefile` — add cross-compile targets
- Create: `package/S99keen-pbr-web`

**Step 1: Add cross-compile to Makefile**

```makefile
build-mips:
	cd $(FRONTEND_DIR) && bun run build
	GOOS=linux GOARCH=mipsle GOMIPS=softfloat go build -ldflags="-s -w" -o $(BUILD_DIR)/keen-pbr-web-mipsle .

build-aarch64:
	cd $(FRONTEND_DIR) && bun run build
	GOOS=linux GOARCH=arm64 go build -ldflags="-s -w" -o $(BUILD_DIR)/keen-pbr-web-arm64 .
```

**Step 2: Create init script**

```bash
#!/bin/sh
PROCS=keen-pbr-web
ARGS="-port 3000"
PREARGS=""
DESC=$PROCS
PATH=/opt/sbin:/opt/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

. /opt/etc/init.d/rc.func
```

**Step 3: Commit**

```bash
git add -A && git commit -m "feat: cross-compilation + Entware init script"
```

---

## Summary

14 tasks total. After all tasks, the project delivers:
- Single Go binary with embedded Svelte SPA
- Config viewing/editing via JSON API + raw TOML fallback
- List management (view, add, edit entries)
- IPSet overview
- Action buttons (download, apply, self-check)
- Cross-compilation for Entware (mipsle, arm64)
- Init script for autostart
