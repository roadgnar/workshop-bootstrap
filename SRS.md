## Software Requirements Specification (SRS)

**Project:** Cross-platform "clone-and-run" repo bootstrap for Docker + Cursor + demo web app  
**Target OS:** macOS, Windows, Linux  
**Primary outcome:** A user can clone the repo, navigate to their OS folder, and run a single command that (1) installs/starts Docker, (2) installs Cursor, (3) launches a dev container with dependencies, and (4) runs a demo website accessible from the host.

**Status:** ✅ Implemented

---

# 1. Introduction

## 1.1 Purpose

Define functional and non-functional requirements for a repository that provides an automated developer environment setup using Docker and Cursor across macOS, Windows, and Linux, including a containerized demo web application reachable from outside the container.

## 1.2 Scope

The repo includes:

* OS-specific folders (`mac/`, `linux/`, `windows/`) with platform-specific entry points and documentation.
* Shared bootstrap logic in `scripts/` to maintain DRY principles.
* Detection and conditional installation of Docker and Cursor.
* Automated container launch with dependencies preconfigured.
* A demo web project (Flask) served from within the container and accessible at `http://localhost:8080` on the host.
* Optional devcontainer configuration for editor-to-container development workflows.
* GitHub Actions CI/CD for automated testing on all platforms.

Out of scope:

* Full elimination of interactive OS security prompts for Docker Desktop on macOS/Windows.
* Enterprise device management (MDM), corporate proxy configuration, and locked-down environments beyond documented guidance.

## 1.3 Definitions

* **Docker daemon:** Background service that runs containers.
* **Docker Desktop:** Docker daemon + UI + VM backend for macOS/Windows.
* **Docker Engine:** Lightweight Docker daemon for Linux (no GUI).
* **Compose:** Multi-container orchestration (`docker compose`).
* **Dev container:** Editor-attached development environment (optional).
* **Idempotent:** Safe to run repeatedly; script should converge on the desired state.

---

# 2. Overall Description

## 2.1 Product Perspective

This is a self-contained repository template that:

* Provides a "one command" developer setup path per OS.
* Organizes entry points by operating system for clarity (`mac/`, `linux/`, `windows/`).
* Shares common logic via `scripts/` to avoid duplication.
* Uses Docker Compose and bind mounts to allow editing code on the host (via Cursor) while running it inside the container.
* Optionally supports a devcontainer-style workflow for attaching the editor to the container.
* Includes CI/CD via GitHub Actions to validate functionality on all platforms.

## 2.2 User Classes

* **New user (fresh laptop):** No Docker and/or Cursor installed.
* **Existing user:** Has Docker and/or Cursor installed; may have Docker not running.
* **Linux user:** Uses Docker Engine (not Docker Desktop).

## 2.3 Operating Environment

* macOS: Apple Silicon and Intel supported; Docker Desktop via Homebrew.
* Windows: Windows 10/11 with PowerShell; Docker Desktop via WinGet (WSL2-backed).
* Linux: Debian/Ubuntu baseline (Fedora, Arch best-effort); Docker Engine via apt/dnf/pacman.

## 2.4 Constraints

* Installation steps may require admin privileges (sudo / UAC).
* Docker Desktop on macOS/Windows may require first-run interactive confirmation (permissions, license).
* Network access required to fetch installers/images.

## 2.5 Assumptions and Dependencies

* Git is available (or user can download repo as zip).
* A supported package manager exists or can be installed:
  * macOS: Homebrew preferred
  * Windows: WinGet preferred
  * Linux: apt preferred (baseline), dnf/pacman supported
* Docker Hub or configured registry reachable for pulling images.

---

# 3. Functional Requirements

## 3.1 Bootstrap Command

**FR-001** ✅ The repo provides OS-specific entry points in dedicated folders:

* macOS: `cd mac && ./bootstrap`
* Linux: `cd linux && ./bootstrap`
* Windows: `cd windows; .\bootstrap.ps1`

**FR-002** ✅ Bootstrap performs:

1. Detect Docker installation state
2. Install Docker if missing (Desktop on macOS/Windows, Engine on Linux)
3. Ensure Docker daemon is running
4. Detect Cursor installation state
5. Install Cursor if missing
6. Build + start dev container(s)
7. Start the demo web service
8. Open Cursor to the repo (best-effort, skippable with `--no-open`)

**FR-003** ✅ Bootstrap is idempotent and safe to rerun.

## 3.2 Detection and Decision Logic

**FR-010** ✅ The system detects:

* Docker CLI presence and version
* Docker daemon availability (`docker info` success)
* Docker Compose availability (`docker compose version`)
* Cursor CLI presence (`cursor --version`) OR Cursor application installed (OS-specific detection)

**FR-011** ✅ If Docker is installed but daemon is not running, bootstrap attempts to start it and waits up to a configurable timeout (default: 120s).

**FR-012** ✅ If Docker and/or Cursor are already installed, bootstrap does NOT reinstall by default; `--reinstall-docker` and `--reinstall-cursor` options are available.

## 3.3 Docker Installation

**FR-020** ✅ macOS: Docker Desktop installed via Homebrew cask, with DMG fallback.

**FR-021** ✅ Windows: Docker Desktop installed via WinGet, with direct download fallback.

**FR-022** ✅ Linux: Docker Engine installed via official apt repo (Debian/Ubuntu), dnf (Fedora), yum (CentOS), pacman (Arch), or convenience script fallback.

**FR-023** ✅ Bootstrap validates post-install that `docker` works and surfaces actionable errors.

## 3.4 Cursor Installation

**FR-030** ✅ macOS: Cursor installed via Homebrew cask, with DMG fallback.

**FR-031** ✅ Windows: Cursor installed via WinGet, with direct download fallback.

**FR-032** ✅ Linux: Cursor installed via AppImage to `~/.local/bin/`, with desktop entry created.

**FR-033** ✅ After install, bootstrap verifies Cursor is launchable (best-effort). If not, it continues container setup and provides next steps.

## 3.5 Containerized Dev Environment

**FR-040** ✅ The repo includes:

* `Dockerfile` (multi-stage: development and production targets)
* `docker-compose.yml` defining a dev service
* Bind mount of repository into the container at `/workspace`
* Default command `sleep infinity` to keep container alive for development

**FR-041** ✅ The repo provides helper commands in each OS folder:

* macOS: `./dev up|down|shell|logs|restart|demo|build|status|clean`
* Linux: `./dev up|down|shell|logs|restart|demo|build|status|clean`
* Windows: `.\dev.ps1 up|down|shell|logs|restart|demo|build|status|clean`

**FR-042** ✅ The container exposes port 8080 (configurable via `$PORT` env var).

## 3.6 Demo Web Project

**FR-050** ✅ The repo includes a demo web project (`demo-site/`) that:

* Flask 3.0 application with Gunicorn for production
* Serves HTTP on configurable port (default: 8080)
* Reachable from host at `http://localhost:8080`
* Returns styled "It Works!" confirmation page with hostname, version, server time

**FR-051** ✅ The demo starts automatically after bootstrap; URL is printed in summary.

**FR-052** ✅ The demo supports hot reload in development mode (`FLASK_ENV=development`).

**FR-053** ✅ Health and info endpoints:

* `GET /health` → `{"status": "healthy", "version": "...", "timestamp": "..."}`
* `GET /api/info` → Detailed build and runtime information

## 3.7 Cursor-to-Container Editing Workflow

**Mode A (baseline, required):** ✅ Cursor edits host files; container runs code via bind mount.

**FR-060** ✅ This mode works without any Cursor extension or container attachment.

**Mode B (optional):** ✅ Devcontainer-style attachment.

**FR-061** ✅ `.devcontainer/devcontainer.json` included for compatibility with devcontainer-capable editors.

**FR-062** ✅ Bootstrap does not block baseline mode; devcontainer is optional.

## 3.8 UX, Logging, and Errors

**FR-070** ✅ Bootstrap emits:

* Step-by-step progress log with colored output
* Clear error messages with remediation steps
* Exit codes: `0` success, non-zero failure

**FR-071** ✅ If Docker Desktop needs first-run manual action, bootstrap:

* Launches Docker Desktop (best-effort)
* Explains what user must do
* Exits cleanly with retriable message

**FR-072** ✅ Bootstrap avoids destructive actions by default (no deleting images/volumes). `dev clean` available for explicit cleanup.

---

# 4. External Interface Requirements

## 4.1 CLI Interface

### macOS / Linux

```bash
cd mac  # or linux
./bootstrap [--reinstall-docker] [--reinstall-cursor] [--port 8080] [--no-open] [--timeout 120]
./dev <command>  # up|down|shell|logs|restart|demo|build|status|clean
```

### Windows

```powershell
cd windows
.\bootstrap.ps1 [-ReinstallDocker] [-ReinstallCursor] [-Port 8080] [-NoOpen] [-TimeoutSec 120]
.\dev.ps1 <command>  # up|down|shell|logs|restart|demo|build|status|clean
```

## 4.2 File/Repo Structure

```
workshop-bootstrap/
├── mac/                          # macOS entry points
│   ├── bootstrap                 # Main setup script
│   ├── dev                       # Development helper
│   └── README.md                 # macOS-specific docs
│
├── linux/                        # Linux entry points
│   ├── bootstrap
│   ├── dev
│   └── README.md
│
├── windows/                      # Windows entry points
│   ├── bootstrap.ps1
│   ├── dev.ps1
│   └── README.md
│
├── scripts/                      # Shared logic (DRY)
│   ├── bootstrap-common.sh       # Shared bootstrap logic (macOS/Linux)
│   ├── dev-common.sh             # Shared dev helper logic (macOS/Linux)
│   ├── utils.sh                  # Shell utilities
│   ├── utils.ps1                 # PowerShell utilities
│   ├── install-docker-macos.sh
│   ├── install-docker-linux.sh
│   ├── install-docker-windows.ps1
│   ├── install-cursor-macos.sh
│   ├── install-cursor-linux.sh
│   └── install-cursor-windows.ps1
│
├── demo-site/                    # Demo web application
│   ├── app.py                    # Flask application
│   ├── requirements.txt          # Python dependencies
│   └── templates/
│       └── index.html            # Styled demo page
│
├── .devcontainer/
│   └── devcontainer.json         # VS Code/Cursor devcontainer config
│
├── .github/workflows/            # CI/CD
│   ├── test.yml                  # Multi-platform tests
│   └── lint.yml                  # Script linting
│
├── Dockerfile                    # Multi-stage container definition
├── docker-compose.yml            # Container orchestration
├── README.md                     # Main documentation
└── SRS.md                        # This specification
```

---

# 5. Non-Functional Requirements

## 5.1 Portability

**NFR-001** ✅ Scripts run on:

* macOS: bash/zsh (10.15+, Intel and Apple Silicon)
* Linux: bash (Debian/Ubuntu primary, Fedora/Arch best-effort)
* Windows: PowerShell 5.1+ (PS7 compatible)

## 5.2 Reliability

**NFR-010** ✅ Bootstrap is idempotent and converges to a working setup.

**NFR-011** ✅ Timeouts are configurable; readiness checks use `docker info` and HTTP health checks.

## 5.3 Security

**NFR-020** ✅ Downloads use HTTPS exclusively.

**NFR-021** ✅ Scripts do not exfiltrate data; no telemetry beyond package managers' defaults.

**NFR-022** ✅ Privileged operations are minimal and clearly indicated (sudo prompts).

## 5.4 Maintainability

**NFR-030** ✅ Install methods encapsulated per OS in `scripts/`.

**NFR-031** ✅ Shared logic in `bootstrap-common.sh` and `dev-common.sh` to avoid duplication.

**NFR-032** ✅ Dependencies pinned: Python 3.12-slim base image, Flask 3.0.0, Gunicorn 21.2.0.

## 5.5 Performance

**NFR-040** ✅ First successful setup completes with minimal manual steps beyond OS prompts.

**NFR-041** ✅ Subsequent runs are fast (no rebuild unless `dev build` is called).

---

# 6. Acceptance Criteria

**AC-001** ✅ Fresh machine (no Docker, no Cursor): running bootstrap results in either:

* Fully working environment with container up, demo site reachable, Cursor installed/opened; OR
* A single documented manual step required (e.g., Docker Desktop first-run), after which rerunning bootstrap succeeds.

**AC-002** ✅ Machine with Docker installed but not running: bootstrap starts Docker and proceeds.

**AC-003** ✅ Machine with Cursor installed: bootstrap does not reinstall Cursor and proceeds.

**AC-004** ✅ Demo website is reachable from host browser at `http://localhost:8080`.

**AC-005** ✅ `dev shell` provides an interactive shell in the dev container.

**AC-006** ✅ Each OS folder has its own README with platform-specific instructions.

---

# 7. Test Plan

## 7.1 OS Matrix (CI/CD)

GitHub Actions workflows test on:

* 🐧 Linux: `ubuntu-latest` — **Full Docker container tests** (Docker runs natively)
* 🍎 macOS: `macos-latest` — Scripts + Docker CLI + Cursor installation (daemon can't run)
* 🪟 Windows: `windows-latest` — Scripts + Docker CLI + Cursor installation (Linux containers unavailable)

> **Note:** GitHub Actions runners don't support nested virtualization on macOS/Windows, so the Docker daemon cannot run containers. CI calls the **actual install functions** from the scripts for Cursor installation.

## 7.2 Automated Tests (`.github/workflows/test.yml`)

| Test | Linux | macOS | Windows |
|------|-------|-------|---------|
| Utility functions | ✅ | ✅ | ✅ |
| Detection functions | ✅ | ✅ | ✅ |
| Script syntax validation | ✅ | ✅ | ✅ |
| **Cursor install (actual script)** | — | ✅ `install_cursor_macos()` | ✅ `Install-CursorWindows` |
| Cursor detection after install | — | ✅ | ✅ |
| Docker CLI available | ✅ | ✅ Homebrew | ✅ pre-installed |
| Docker detection functions | ✅ | ✅ | ✅ |
| Docker daemon running | ✅ | ❌ (no virt) | ❌ (Windows containers) |
| Build container | ✅ | — | — |
| Start container | ✅ | — | — |
| Bind mount verification | ✅ | — | — |
| Health endpoint from host | ✅ | — | — |
| Main page from host | ✅ | — | — |
| API info from host | ✅ | — | — |
| Dev helper commands | ✅ | ✅ | ✅ |

### What CI Cannot Test

| Component | Reason |
|-----------|--------|
| Docker Desktop install | CI runners don't support nested virtualization |
| Docker daemon on macOS/Windows | Same limitation |
| Full end-to-end bootstrap | Would require Docker Desktop to start

## 7.3 Linting (`.github/workflows/lint.yml`)

* **ShellCheck:** All `.sh` files
* **PSScriptAnalyzer:** All `.ps1` files
* **Hadolint:** `Dockerfile`

## 7.4 Manual Test Scenarios

* T1: Fresh install path (all tools missing)
* T2: Docker already installed, daemon stopped
* T3: Cursor already installed
* T4: Both installed, bootstrap is no-op except container launch
* T5: Network unavailable (verify graceful failure messaging)
* T6: Port already in use (verify `--port` option or clear error)

---

# 8. Implementation Details

## 8.1 Demo Web Application

* **Framework:** Flask 3.0
* **Server:** Gunicorn (production), Flask dev server (development)
* **Port:** 8080 (configurable via `$PORT`)
* **Endpoints:**
  * `GET /` — Styled "It Works!" page with build info
  * `GET /health` — JSON health check
  * `GET /api/info` — Detailed runtime info

## 8.2 Container Configuration

* **Base Image:** `python:3.12-slim`
* **Multi-stage Build:** `development` (with dev tools) and `production` targets
* **Workspace:** `/workspace` (bind-mounted from host)
* **Default Command:** `sleep infinity` (keeps container alive for development)

## 8.3 Architecture (DRY)

```
OS Entry Points          Shared Logic
┌─────────────┐         ┌───────────────────────┐
│ mac/        │         │ scripts/              │
│  bootstrap ─┼────────►│  bootstrap-common.sh  │
│  dev       ─┼────────►│  dev-common.sh        │
├─────────────┤         │  utils.sh             │
│ linux/      │         │  install-*.sh         │
│  bootstrap ─┼────────►│                       │
│  dev       ─┼────────►│                       │
├─────────────┤         ├───────────────────────┤
│ windows/    │         │  utils.ps1            │
│  bootstrap ─┼────────►│  install-*.ps1        │
│  dev       ─┼────────►│                       │
└─────────────┘         └───────────────────────┘
```

---

# 9. Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Initial | Original SRS |
| 2.0 | Current | Updated to reflect implementation: OS-specific folders, shared scripts, CI/CD, Flask demo app |
