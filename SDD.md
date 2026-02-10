## Software Design Document (SDD)

**Project:** Workshop Bootstrap  
**Version:** 1.1  
**Date:** 2025-02-10  
**Requirements:** [SRS.md](SRS.md)

This document describes *how* the system is built. For *what* it must do, see the [SRS](SRS.md).

---

# 1. Design Goals

1. **Zero-prerequisite setup** -- only Git and a supported OS required
2. **DRY** -- OS entry points are thin wrappers; all logic is shared
3. **Repo-agnostic container** -- one image supports Python, Node.js, and hybrid stacks
4. **Extensibility** -- new repos require only files, no core code changes ([FR-008](SRS.md#32-multi-repository-support))
5. **Idempotency** -- every script converges on the desired state ([FR-003](SRS.md#31-bootstrap))
6. **Graceful degradation** -- if Cursor install fails, container setup continues

---

# 2. Architecture

## 2.1 System Diagram

```
┌───────────────────────────────────────────────────────────────────┐
│  HOST                                                             │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │  OS Entry Points                                           │   │
│  │  mac/bootstrap  |  linux/bootstrap  |  windows/bootstrap   │   │
│  │  mac/dev        |  linux/dev        |  windows/dev         │   │
│  └────────┬───────────────┬──────────────────┬────────────────┘   │
│           │               │                  │                    │
│           ▼               ▼                  ▼                    │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │  Shared Scripts (scripts/)                                 │   │
│  │  bootstrap-common.sh  dev-common.sh  utils.sh  utils.ps1   │   │
│  │  install-docker-*.sh  install-cursor-*.sh                  │   │
│  │  install-docker-*.ps1 install-cursor-*.ps1                 │   │
│  └────────┬───────────────────────────────────────────────────┘   │
│           │  docker compose build/up                              │
│           ▼                                                       │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │  Docker Container (workshop-dev)                           │   │
│  │                                                            │   │
│  │  /workspace/  (bind mount from host)                       │   │
│  │    ├── scripts/start-repo.sh   (generic repo manager)      │   │
│  │    ├── repos/demo-site/        (Flask on :8080)            │   │
│  │    ├── repos/cyvl-geoguesser/  (Vite :5173, API :8000)     │   │
│  │    └── logs/                   (PID + log files)           │   │
│  │                                                            │   │
│  │  Exposed ports: 8080, 5173, 8000, 3000                     │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                   │
│  Cursor IDE ←──bind mount──→ Container                            │
│  Host browser ←──port map──→ Container services                   │
└───────────────────────────────────────────────────────────────────┘
```

## 2.2 Component Map

| Component | Files | Fulfills |
|-----------|-------|----------|
| OS Entry Points | `mac/{bootstrap,dev}`, `linux/{bootstrap,dev}`, `windows/{bootstrap.ps1,dev.ps1}` | [FR-001](SRS.md#31-bootstrap), [FR-050](SRS.md#38-dev-helper-commands) |
| Bootstrap Engine | `scripts/bootstrap-common.sh` | [FR-002](SRS.md#31-bootstrap), [FR-003](SRS.md#31-bootstrap) |
| Dev Helper | `scripts/dev-common.sh` | [FR-050, FR-051](SRS.md#38-dev-helper-commands) |
| Utilities | `scripts/utils.sh`, `scripts/utils.ps1` | [FR-010](SRS.md#33-detection-and-decision-logic), [FR-034--036](SRS.md#36-port-management) |
| Docker Installers | `scripts/install-docker-{macos,linux,windows}.*` | [FR-020--023](SRS.md#34-docker-installation) |
| Cursor Installers | `scripts/install-cursor-{macos,linux,windows}.*` | [FR-030--033](SRS.md#35-cursor-installation) |
| Repo Manager | `scripts/start-repo.sh` | [FR-004--008](SRS.md#32-multi-repository-support), [FR-080](SRS.md#311-cursor-configuration-syncing) |
| Per-Repo Scripts | `repos/*/scripts/start.sh` | [FR-005](SRS.md#32-multi-repository-support) |
| Container Image | `Dockerfile` | [FR-040](SRS.md#37-development-container) |
| Compose Config | `docker-compose.yml` | [FR-040, FR-041](SRS.md#37-development-container) |
| Repo Metadata | `repos/*/repo.json` | [FR-004](SRS.md#32-multi-repository-support) |
| Devcontainer | `.devcontainer/devcontainer.json` | [FR-042](SRS.md#37-development-container) |

---

# 3. File Structure

```
workshop-bootstrap/
├── mac/                          # macOS entry points
│   ├── bootstrap
│   ├── dev
│   └── README.md
├── linux/                        # Linux entry points
│   ├── bootstrap
│   ├── dev
│   └── README.md
├── windows/                      # Windows entry points
│   ├── bootstrap.ps1
│   ├── dev.ps1
│   └── README.md
├── repos/                        # Application repositories
│   ├── demo-site/
│   │   ├── code/                 # Flask app (app.py, requirements.txt, templates/)
│   │   ├── scripts/start.sh
│   │   └── repo.json
│   └── cyvl-geoguesser/
│       ├── code/                 # React frontend (src/, vite.config.ts) + FastAPI backend (api/)
│       ├── scripts/start.sh
│       └── repo.json
├── scripts/                      # Shared logic
│   ├── bootstrap-common.sh
│   ├── dev-common.sh
│   ├── start-repo.sh
│   ├── utils.sh / utils.ps1
│   ├── install-docker-{macos,linux}.sh
│   ├── install-docker-windows.ps1
│   ├── install-cursor-{macos,linux}.sh
│   └── install-cursor-windows.ps1
├── data/                         # Public datasets (documentation)
├── .cursor/                      # Shared Cursor IDE config (rules, commands)
├── .devcontainer/devcontainer.json
├── .github/workflows/{test,lint}.yml
├── Dockerfile
├── docker-compose.yml
├── .gitignore
├── README.md
├── SRS.md
└── SDD.md
```

---

# 4. Detailed Design

## 4.1 OS Entry Points (Thin Wrapper + Strategy Pattern)

Each OS folder has two scripts (~5 lines each) that:
1. Set `$OS` (`macos` or `linux`) or implicitly run as Windows
2. Compute `$SCRIPT_DIR` as repo root (one level up)
3. Source the shared common script
4. Call `run_bootstrap "$@"` or `run_dev_command "$@"`

`bootstrap-common.sh` uses `$OS` to select OS-specific function references:

```bash
case "$OS" in
    macos)
        source "scripts/install-docker-macos.sh"
        source "scripts/install-cursor-macos.sh"
        START_DOCKER="start_docker_macos"
        OPEN_CURSOR="open_cursor_macos"
        DETECT_CURSOR="detect_cursor_macos"
        ;;
    linux)  # same pattern, linux functions
esac
```

Functions stored in variables and invoked indirectly (`$START_DOCKER "$TIMEOUT"`), keeping the orchestration logic OS-agnostic. Windows uses inline `if/else` in PowerShell since it doesn't source `.sh` files.

## 4.2 Bootstrap Engine (`bootstrap-common.sh`)

### Flow (implements [FR-002](SRS.md#31-bootstrap))

```
run_bootstrap()
  ├── print_banner()
  ├── parse_bootstrap_args()         # --repo, --force-ports, --no-open, --timeout, etc.
  ├── select_repo_interactive()      # if --repo not given: read repos/*/repo.json, numbered menu
  │   or validate_selected_repo()    # if --repo given: check dir + repo.json + start.sh exist
  ├── setup_docker()                 # detect → install if missing (or --reinstall-docker)
  ├── ensure_docker_running()        # docker info → $START_DOCKER → poll with timeout
  │   └── compose_available()
  ├── setup_cursor()                 # $DETECT_CURSOR → install if missing (or --reinstall-cursor)
  ├── check_required_ports()         # jq .ports from repo.json → check_and_free_ports()
  ├── setup_containers()             # docker compose build dev && docker compose up -d dev
  ├── start_repo_services()
  │   ├── exec: start-repo.sh install <repo>   # deps
  │   ├── exec -d: start-repo.sh <repo> start  # services (backgrounded)
  │   └── poll healthcheck URL (up to 60s, 2s interval)
  ├── open_editor()                  # $OPEN_CURSOR to repos/<repo>/code
  └── print_summary()                # repo name, URLs from repo.json, useful commands
```

### Configuration Defaults

| Variable | Default | CLI Override |
|----------|---------|-------------|
| `TIMEOUT` | 120s | `--timeout` |
| `REINSTALL_DOCKER` | false | `--reinstall-docker` |
| `REINSTALL_CURSOR` | false | `--reinstall-cursor` |
| `NO_OPEN` | false | `--no-open` |
| `FORCE_PORTS` | false | `--force-ports` |
| `SELECTED_REPO` | (interactive) | `--repo NAME` |
| `DEFAULT_PORTS` | 8080 5173 8000 3000 | from repo.json |

## 4.3 Dev Helper (`dev-common.sh`)

### State: `.selected-repo`

A plain-text file at repo root persists the active repo name (implements [FR-007](SRS.md#32-multi-repository-support)). Written by bootstrap and `./dev select`. Read by all `./dev` commands as default. Deleted by `./dev clean`.

### Command Dispatch (implements [FR-050](SRS.md#38-dev-helper-commands))

```
run_dev_command($cmd)
  ├── up       → docker compose up -d dev
  ├── down     → docker compose down
  ├── shell    → docker compose exec dev bash
  ├── start    → exec: start-repo.sh <repo> start
  ├── stop     → exec: start-repo.sh <repo> stop
  ├── restart  → exec: start-repo.sh <repo> restart
  ├── logs     → exec: start-repo.sh <repo> logs
  ├── status   → docker compose ps + exec: start-repo.sh <repo> status
  ├── install  → exec: start-repo.sh install <repo>
  ├── select   → interactive picker → write .selected-repo
  ├── list     → iterate repos/*/repo.json, show names + descriptions
  ├── build    → docker compose build --no-cache dev
  └── clean    → docker compose down --volumes --rmi local + rm .selected-repo
```

All commands that need the container call `ensure_container_running()` first (implements [FR-051](SRS.md#38-dev-helper-commands)), which runs `cmd_up()` if the container is not running.

## 4.4 Repo Manager (`start-repo.sh`) -- Runs Inside Container

This script bridges the generic dev helper and per-repo lifecycle scripts.

### Command Routing

| Invocation | Action |
|-----------|--------|
| `start-repo.sh install <repo>` | Validate repo, sync Cursor config ([FR-080](SRS.md#311-cursor-configuration-syncing)), install deps by stack ([FR-006](SRS.md#32-multi-repository-support)) |
| `start-repo.sh <repo> start` | Delegate to `repos/<repo>/scripts/start.sh start` |
| `start-repo.sh <repo> stop\|restart\|status\|logs` | Delegate to same |
| `start-repo.sh list` | Show all repos from `repos/*/repo.json` |
| `start-repo.sh info <repo>` | Show name, description, stack, URLs |

### Dependency Installation by Stack (implements [FR-006](SRS.md#32-multi-repository-support))

| Stack value | Steps |
|-------------|-------|
| `python` | `pip install -r code/requirements.txt` |
| `node` | `cd code && npm install` |
| `node+python` | `cd code && npm install` then `cd code/api && uv sync --all-packages` (falls back to pip if no pyproject.toml) |

### Cursor Config Syncing (implements [FR-080](SRS.md#311-cursor-configuration-syncing))

Copies `$WORKSPACE/.cursor/` → `repos/<repo>/code/.cursor/` if both directories exist. The `.gitignore` excludes `repos/*/code/.cursor/`.

## 4.5 Per-Repo Service Scripts (`repos/*/scripts/start.sh`)

### Interface Contract (implements [FR-005](SRS.md#32-multi-repository-support))

```bash
./start.sh start     # Start service(s) in background
./start.sh stop      # Stop service(s) gracefully
./start.sh restart   # Stop then start
./start.sh status    # Show running state + URLs
./start.sh logs      # Tail log file(s)
```

### Process Management Pattern

Both bundled repos use:
1. **Start:** `setsid <cmd> > $LOG_DIR/<name>.log 2>&1 &` (new process group)
2. **Record PID:** `echo $! > $LOG_DIR/<name>.pid`
3. **Liveness check:** `kill -0 $pid`
4. **Stop:** `kill -TERM -$pid` (negative PID kills entire process group)
5. **Fallback:** `pkill -f <pattern>` for orphans

### demo-site

* Single process: `python app.py` (Flask dev server, port 8080)
* `FLASK_ENV=development` enables auto-reload
* Files: `demo-site.pid`, `demo-site.log`

### cyvl-geoguesser

* Two processes:
  * Backend: `uv run uvicorn geolocation_api.app:app --reload --host 0.0.0.0 --port 8000`
  * Frontend: `npm run dev -- --host 0.0.0.0` (Vite on port 5173)
* Files: `backend.pid`, `backend.log`, `frontend.pid`, `frontend.log`
* On `start`: calls `stop_services` first to prevent port conflicts

---

# 5. Container Design

## 5.1 Dockerfile (implements [FR-040](SRS.md#37-development-container))

Two stages, no production target:

**`base` stage** (FROM `python:3.12-slim`):
* System packages: curl, git, ca-certificates, gnupg
* Node.js 22 via NodeSource apt repo (GPG verified)
* npm upgraded to latest globally; update notifier disabled
* uv installed from `astral.sh/uv/install.sh`
* ENV: `PYTHONDONTWRITEBYTECODE=1`, `PYTHONUNBUFFERED=1`, `PIP_NO_CACHE_DIR=1`
* PATH includes `/root/.local/bin` (uv)

**`development` stage** (FROM `base`):
* Dev tools: vim, less, htop, procps, jq
* Build args: `BUILD_TIME`, `VERSION`
* CMD: `sleep infinity`

## 5.2 Docker Compose (implements [FR-040, FR-041](SRS.md#37-development-container))

```yaml
services:
  dev:
    build: { context: ., target: development }
    container_name: workshop-dev
    volumes: [ ".:/workspace:cached" ]
    ports:
      - "${PORT_1:-8080}:8080"
      - "${PORT_2:-5173}:5173"
      - "${PORT_3:-8000}:8000"
      - "${PORT_4:-3000}:3000"
    environment: [ VERSION, SELECTED_REPO, FLASK_ENV=development ]
    command: sleep infinity
    restart: unless-stopped
```

Design decisions:
* **`:cached`** -- improves read perf on macOS Docker file sharing
* **`sleep infinity`** -- container stays alive; services start/stop independently inside it
* **`unless-stopped`** -- survives daemon restarts but respects `docker compose down`
* **Four ports** -- covers common web stacks without per-repo compose overrides

## 5.3 Devcontainer (implements [FR-042](SRS.md#37-development-container))

`.devcontainer/devcontainer.json` references the same compose file. Adds IDE extensions (Python, Pylance, Docker, Prettier, Tailwind CSS), editor settings, and port forwarding. Uses root as remote user for simplicity.

---

# 6. Data Model

## 6.1 `repo.json` Schema (implements [FR-004](SRS.md#32-multi-repository-support))

```json
{
  "name": "string",
  "description": "string",
  "stack": "python | node | node+python",
  "ports": [8080, 5173],
  "healthcheck": "http://localhost:8080/health",
  "urls": { "Label": "http://localhost:8080" }
}
```

## 6.2 Environment Variables (docker-compose.yml)

| Variable | Default | Purpose |
|----------|---------|---------|
| `BUILD_TIME` | `development` | ISO 8601 build timestamp |
| `VERSION` | `1.0.0` | App version |
| `SELECTED_REPO` | (empty) | Active repo |
| `FLASK_ENV` | `development` | Flask mode |
| `PORT_1`-`PORT_4` | 8080, 5173, 8000, 3000 | Host port overrides |

## 6.3 Process State (`/workspace/logs/`)

| File | Owner |
|------|-------|
| `demo-site.{pid,log}` | demo-site start.sh |
| `backend.{pid,log}` | cyvl-geoguesser start.sh |
| `frontend.{pid,log}` | cyvl-geoguesser start.sh |

---

# 7. Cross-Platform Design

## 7.1 Abstraction Layers

```
Layer 1  OS Entry Points        Set $OS, delegate
Layer 2  Shared Logic           OS-agnostic orchestration
Layer 3  OS Installers          Native package managers per platform
Layer 4  Container Runtime      Always Linux (inside container)
```

## 7.2 Docker Installation (implements [FR-020--022](SRS.md#34-docker-installation))

| OS | Primary | Fallback | Daemon |
|----|---------|----------|--------|
| macOS | `brew install --cask docker` | DMG download | Docker Desktop |
| Windows | `winget install Docker.DockerDesktop` | Direct download | Docker Desktop (WSL2) |
| Linux (Debian/Ubuntu) | Official Docker CE apt repo | `get.docker.com` | Docker Engine |
| Linux (Fedora) | Official Docker CE dnf repo | `get.docker.com` | Docker Engine |
| Linux (CentOS/RHEL) | Official Docker CE yum repo | `get.docker.com` | Docker Engine |
| Linux (Arch/Manjaro) | pacman community packages | `get.docker.com` | Docker Engine |

Linux also runs `configure_docker_user()` to add the user to the `docker` group.

## 7.3 Cursor Installation (implements [FR-030--032](SRS.md#35-cursor-installation))

| OS | Primary | Fallback | Post-Install |
|----|---------|----------|-------------|
| macOS | `brew install --cask cursor` | DMG | `setup_cursor_cli_macos` (CLI symlink) |
| Windows | `winget install Cursor.Cursor` | Direct download | PATH detection via `Get-CursorPath` |
| Linux | AppImage → `~/.local/bin/cursor.AppImage` | .deb package | Wrapper script, PATH update in `.bashrc`/`.zshrc`, `.desktop` entry |

## 7.4 Daemon Startup (implements [FR-011](SRS.md#33-detection-and-decision-logic))

| OS | Start command | Polling |
|----|--------------|---------|
| macOS | `open -a Docker` | `docker info` every 2s, up to `$TIMEOUT` |
| Windows | `Start-Process "Docker Desktop"` | Same polling |
| Linux | `systemctl start docker` (fallback: `service docker start`) | Same, plus sudo fallback |

## 7.5 Port Detection (implements [FR-034--036](SRS.md#36-port-management))

| OS | Tool chain |
|----|-----------|
| macOS/Linux | `lsof -nP -iTCP:$port` → `ss -tlnp` → `netstat -tlnp` |
| Windows | `Get-NetTCPConnection -LocalPort $port -State Listen` |

Kill escalation: SIGTERM → sudo SIGTERM → SIGKILL → sudo SIGKILL (bash); `Stop-Process -Force` (PowerShell).

## 7.6 Utility Function Mapping

| bash (`utils.sh`) | PowerShell (`utils.ps1`) |
|-------------------|-------------------------|
| `log_step()` | `Write-Step` |
| `log_info()` | `Write-Info` |
| `log_success()` | `Write-Success` |
| `log_warn()` | `Write-Warn` |
| `log_error()` | `Write-ErrorMsg` |
| `docker_installed()` | `Test-DockerInstalled` |
| `docker_running()` | `Test-DockerRunning` |
| `compose_available()` | `Test-ComposeAvailable` |
| `cursor_installed()` | `Test-CursorInstalled` |
| `port_in_use()` | `Test-PortInUse` |
| `get_port_process()` | `Get-PortProcess` |
| `kill_port_process()` | `Stop-PortProcess` |
| `check_and_free_ports()` | `Test-AndFreePorts` |
| `check_url()` | `Test-UrlReachable` |
| `wait_for()` | `Wait-ForCondition` |

---

# 8. Error Handling

## 8.1 Script Safety

All bash scripts use `set -euo pipefail`. PowerShell uses `$ErrorActionPreference = "Stop"`.

## 8.2 Graceful Degradation (implements [FR-070--072](SRS.md#310-ux-and-error-handling))

| Failure | Behavior |
|---------|----------|
| Docker install fails | Exit with error + manual instructions |
| Docker daemon won't start | Exit with retriable message |
| Cursor install fails | Log warning, continue container setup |
| Cursor won't open | Log warning, print manual path |
| Dependency install issues | Log warning, continue to service start |
| Port in use | Prompt or auto-kill (`--force-ports`) |
| Health check timeout (60s) | Log warning + "check logs" guidance, don't exit |
| Service start fails | Display log file path |

## 8.3 Idempotency (implements [FR-003](SRS.md#31-bootstrap))

| Operation | Guard |
|-----------|-------|
| Docker install | `docker_installed()` check first |
| Cursor install | `detect_cursor_*()` check first |
| Docker start | `docker_running()` check first |
| Container start | `docker compose up -d` is naturally idempotent |
| Port check | Re-scans each time |
| Deps install | Package managers handle already-installed |
| Service start | `is_running()` check or stop-before-start |

---

# 9. CI/CD Design

## 9.1 Workflow Architecture

```
test.yml (push/PR to main)
  ├── test-linux     (12 steps: full Docker build + run + endpoint tests)
  ├── test-macos     (8 steps: scripts + actual Cursor install)
  ├── test-windows   (8 steps: scripts + actual Cursor install)
  └── test-summary   (gate job: fails if any platform fails)

lint.yml (push/PR to main)
  ├── ShellCheck     (all .sh, severity warning+, exclude SC1091/SC2034/SC2155)
  ├── PSScriptAnalyzer (all .ps1, severity warning+)
  └── Hadolint       (Dockerfile, failure threshold error, DL3008 inline-ignored)
```

## 9.2 Linux Test Steps (Full)

1. Verify Docker pre-installed
2. Detection functions
3. Port management functions
4. Build container image
5. Start container
6. Bind mount verification
7. Install demo-site deps
8. Start demo-site service
9. Health endpoint from host
10. Main page from host
11. API info endpoint from host
12. Dev helper commands
13. Stop service + cleanup

---

# 10. Extension Guide

## 10.1 Adding a New Repository (implements [FR-008](SRS.md#32-multi-repository-support))

1. Create `repos/my-app/` with `code/`, `scripts/start.sh`, and `repo.json`
2. `repo.json` must have: `name`, `description`, `stack`, `ports`, `healthcheck`, `urls`
3. `start.sh` must handle: `start`, `stop`, `restart`, `status`, `logs`
4. Use the PID/log pattern from existing repos (setsid, process groups)
5. No core script changes needed -- it appears automatically in selection menus

## 10.2 Adding a New Stack

1. Add a case to `install_deps()` in `scripts/start-repo.sh`
2. If the container needs new tools, update the Dockerfile

## 10.3 Adding a New OS

1. Create OS folder with `bootstrap` and `dev` entry scripts
2. Create `scripts/install-docker-<os>.*` and `scripts/install-cursor-<os>.*`
3. Add a case branch in `bootstrap-common.sh`

---

# 11. Known Limitations

1. **Single container** -- all repos share one container; simultaneous multi-repo services may conflict on ports
2. **No production stage** -- Dockerfile only has `base` and `development`
3. **Linux-only container** -- Windows containers not supported
4. **Root in container** -- services run as root for simplicity
5. **PID-based process management** -- no systemd/supervisord; relies on `setsid` + process groups
6. **No persistent volumes** -- npm/pip caches lost on rebuild
7. **Basic health polling** -- fixed 2s interval, no backoff
