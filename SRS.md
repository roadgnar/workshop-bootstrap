## Software Requirements Specification (SRS)

**Project:** Workshop Bootstrap  
**Target OS:** macOS, Windows, Linux  
**Primary outcome:** A user can clone the repo, navigate to their OS folder, and run a single command that installs Docker and Cursor, selects and launches an application in a container, and opens the editor -- all with zero prerequisites beyond Git and a supported OS.

**Status:** Implemented

---

# 1. Introduction

## 1.1 Purpose

Define functional and non-functional requirements for a cross-platform, automated developer environment bootstrap supporting Docker, Cursor IDE, and multiple selectable application repositories.

## 1.2 Scope

In scope:

* One-command setup per OS that installs Docker, installs Cursor, and launches a selected application.
* Multi-repository support: users choose which application to run at bootstrap time.
* Port conflict detection and resolution.
* Day-to-day development commands for container and service lifecycle.
* CI/CD validation on all three platforms.

Out of scope:

* Elimination of interactive OS security prompts for Docker Desktop.
* Enterprise MDM, corporate proxy, or locked-down environment support.

## 1.3 Definitions

| Term | Meaning |
|------|---------|
| Docker daemon | Background service that runs containers |
| Docker Desktop | Docker daemon + UI + VM backend (macOS/Windows) |
| Docker Engine | Lightweight Docker daemon for Linux (no GUI) |
| Compose | Multi-container orchestration (`docker compose`) |
| Dev container | Editor-attached development environment (optional) |
| Idempotent | Safe to run repeatedly; converges on desired state |

---

# 2. Overall Description

## 2.1 Product Perspective

A self-contained repository template that provides a one-command developer setup per OS, supports multiple application repositories, uses bind mounts for host-side editing with container-side execution, and includes CI/CD validation.

## 2.2 User Classes

| User | Description |
|------|-------------|
| New user | Fresh laptop, no Docker or Cursor installed |
| Existing user | Has Docker and/or Cursor; Docker may not be running |
| Linux user | Uses Docker Engine (not Desktop) |
| Workshop organizer | Adds application repos for participants |

## 2.3 Operating Environment

| OS | Notes |
|----|-------|
| macOS | Apple Silicon and Intel; 10.15+ |
| Windows | 10/11 with PowerShell 5.1+; WSL2 required for Docker |
| Linux | Debian/Ubuntu primary; Fedora, Arch best-effort |

## 2.4 Constraints

* Installation may require admin privileges (sudo/UAC).
* Docker Desktop may require first-run interactive confirmation.
* Network access required to fetch installers and container images.

## 2.5 Assumptions

* Git is available (or user downloads repo as zip).
* A supported package manager is available (Homebrew, WinGet, apt/dnf/pacman).
* Docker Hub or a configured registry is reachable.

---

# 3. Functional Requirements

## 3.1 Bootstrap

**FR-001** OS-specific entry points:
* macOS: `cd mac && ./bootstrap`
* Linux: `cd linux && ./bootstrap`
* Windows: `cd windows; .\bootstrap.ps1`

**FR-002** Bootstrap performs these steps in order:
1. Prompt user to select a repository (or accept `--repo NAME`)
2. Validate the selected repo
3. Install Docker if missing; ensure the daemon is running
4. Install Cursor if missing
5. Check required ports; resolve conflicts
6. Build and start the development container
7. Install dependencies for the selected repo inside the container
8. Start the repo's services inside the container
9. Wait for the health check (if configured)
10. Open Cursor to the repo's code folder (skippable with `--no-open`)
11. Print a summary with URLs and useful commands

**FR-003** Bootstrap must be idempotent and safe to rerun.

## 3.2 Multi-Repository Support

**FR-004** The system must support multiple application repositories, each self-describing via a metadata file (`repo.json`) that specifies name, description, technology stack, required ports, health check URL, and user-facing URLs.

**FR-005** Each repo must provide a lifecycle script (`start.sh`) supporting `start`, `stop`, `restart`, `status`, and `logs` commands.

**FR-006** Dependencies must be installed automatically based on the declared stack (`python`, `node`, `node+python`).

**FR-007** If no repo is specified via CLI, bootstrap must present an interactive selection menu. The chosen repo must be persisted so subsequent dev commands default to it.

**FR-008** Adding a new repo must not require changes to any core scripts -- only new files under `repos/`.

## 3.3 Detection and Decision Logic

**FR-010** The system must detect: Docker CLI presence, Docker daemon availability, Docker Compose availability, and Cursor installation (CLI or application).

**FR-011** If Docker is installed but the daemon is not running, bootstrap must attempt to start it and wait up to a configurable timeout (default: 120s).

**FR-012** Already-installed tools must not be reinstalled unless explicitly requested (`--reinstall-docker`, `--reinstall-cursor`).

## 3.4 Docker Installation

**FR-020** macOS: Install Docker Desktop via Homebrew cask, with fallback to direct download.

**FR-021** Windows: Install Docker Desktop via WinGet, with fallback to direct download.

**FR-022** Linux: Install Docker Engine via the distro's native package manager (apt, dnf, yum, pacman), with fallback to the Docker convenience script. Configure the current user for non-root Docker access.

**FR-023** Post-install, validate that `docker` works and surface actionable errors if it does not.

## 3.5 Cursor Installation

**FR-030** macOS: Install via Homebrew cask with fallback. Set up CLI access.

**FR-031** Windows: Install via WinGet with fallback.

**FR-032** Linux: Install via AppImage. Ensure it is on PATH and has a desktop entry.

**FR-033** If Cursor cannot be verified after install, continue setup and provide manual instructions.

## 3.6 Port Management

**FR-034** Before starting services, check that all ports required by the selected repo are available.

**FR-035** Required ports are defined in the repo's metadata. Fall back to a default set if not specified.

**FR-036** If ports are occupied: display the blocking process info, and either prompt the user for permission to kill it or kill automatically if `--force-ports` is set.

## 3.7 Development Container

**FR-040** The container must support both Python and Node.js projects, keep alive for interactive development, and bind-mount the repo so host edits are reflected immediately.

**FR-041** The container must expose ports for common web services (HTTP, Vite, FastAPI, etc.).

**FR-042** A devcontainer configuration must be included for IDE-attached workflows, but must not be required for baseline operation.

## 3.8 Dev Helper Commands

**FR-050** Each OS folder must provide a `dev` script (bash or PowerShell) with the following commands:

| Command | Requirement |
|---------|-------------|
| `up` | Start the development container |
| `down` | Stop all containers |
| `shell` | Open an interactive shell inside the container |
| `start [repo]` | Start the selected repo's services |
| `stop [repo]` | Stop the selected repo's services |
| `restart [repo]` | Restart services |
| `logs [repo]` | Tail service logs |
| `status` | Show container status and active repo info |
| `install [repo]` | Install repo dependencies |
| `select` | Interactively change the active repository |
| `list` | List all available repositories |
| `build` | Rebuild the container image from scratch |
| `clean` | Remove containers, volumes, images, and persisted state |

**FR-051** If the container is not running when a command requires it, it must be started automatically.

## 3.9 Bundled Repositories

**FR-060** A `demo-site` repo must be included:
* Python/Flask web application on port 8080
* Endpoints: `GET /` (styled page), `GET /health` (JSON), `GET /api/info` (JSON)
* Hot reload in development mode

**FR-061** A `cyvl-geoguesser` repo must be included:
* React + Vite frontend on port 5173
* FastAPI backend on port 8000 with auto-generated API docs
* Hot reload for both frontend (HMR) and backend

## 3.10 UX and Error Handling

**FR-070** Bootstrap must emit step-by-step progress with colored output and clear error messages with remediation steps.

**FR-071** If Docker Desktop needs a first-run manual action, bootstrap must explain what the user needs to do and exit cleanly so they can rerun.

**FR-072** Bootstrap must not perform destructive actions (deleting images/volumes) by default.

## 3.11 Cursor Configuration Syncing

**FR-080** Each repo's `code/` directory must include its own `.cursor/` configuration (rules, commands) so that Cursor inherits them when opened to that directory.

---

# 4. CLI Interface

## 4.1 Bootstrap

### macOS / Linux

```
./bootstrap [--repo NAME] [--force-ports] [--reinstall-docker] [--reinstall-cursor] [--no-open] [--timeout SECONDS]
```

### Windows

```
.\bootstrap.ps1 [-Repo NAME] [-ForcePorts] [-ReinstallDocker] [-ReinstallCursor] [-NoOpen] [-TimeoutSec SECONDS]
```

## 4.2 Dev Helper

### macOS / Linux

```
./dev <command> [repo-name]
```

### Windows

```
.\dev.ps1 <command> [repo-name]
```

---

# 5. Non-Functional Requirements

**NFR-001 Portability:** Scripts must run on macOS (bash/zsh), Linux (bash), and Windows (PowerShell 5.1+).

**NFR-010 Reliability:** Bootstrap must be idempotent. Timeouts and health checks must be configurable.

**NFR-020 Security:** All downloads over HTTPS. No telemetry. Minimal privilege escalation, clearly indicated.

**NFR-021 Security:** Sensitive files (`.env`, credentials) must be excluded from version control.

**NFR-030 Maintainability:** OS-specific logic must be encapsulated per platform. Shared logic must not be duplicated. Dependencies must be pinned.

**NFR-031 Extensibility:** Adding a new repo must require only new files, no core script changes (see FR-008).

**NFR-040 Performance:** First setup must complete with minimal manual steps. Subsequent runs must be fast (no rebuild unless explicitly requested).

---

# 6. Acceptance Criteria

| ID | Criterion |
|----|-----------|
| AC-001 | Fresh machine: bootstrap results in a working environment, or one documented manual step after which rerun succeeds |
| AC-002 | Docker installed but not running: bootstrap starts it and proceeds |
| AC-003 | Cursor already installed: bootstrap does not reinstall it |
| AC-004 | Selected repo's URLs are reachable from the host browser |
| AC-005 | `dev shell` opens an interactive shell in the container |
| AC-006 | Each OS folder has a README with platform-specific instructions |
| AC-007 | Port conflicts are detected and can be resolved with `--force-ports` |
| AC-008 | `dev start`/`dev stop` correctly manage per-repo services |
| AC-009 | A new repo added under `repos/` with correct structure is automatically selectable |

---

# 7. Test Plan

## 7.1 CI/CD Matrix

| Platform | Runner | Docker Tests | Cursor Install Test | Script Tests |
|----------|--------|-------------|--------------------|--------------| 
| Linux | `ubuntu-latest` | Full (build, run, endpoints) | -- | Yes |
| macOS | `macos-latest` | CLI only (no daemon) | Yes (actual script) | Yes |
| Windows | `windows-latest` | CLI only (Windows containers) | Yes (actual script) | Yes |

## 7.2 What CI Tests

* Utility and detection functions (all platforms)
* Port management functions (all platforms)
* Script syntax validation (all platforms)
* Docker CLI availability (all platforms)
* Cursor installation and detection (macOS, Windows)
* Container build, start, bind mount, dependency install, service start, health/main/API endpoints, service stop (Linux only)
* Dev helper commands (all platforms)

## 7.3 What CI Cannot Test

* Docker Desktop installation (no nested virtualization)
* Full end-to-end bootstrap (requires Docker Desktop)
* cyvl-geoguesser services (requires API keys)

## 7.4 Linting

* ShellCheck on all `.sh` files
* PSScriptAnalyzer on all `.ps1` files
* Hadolint on `Dockerfile`

## 7.5 Manual Test Scenarios

| ID | Scenario |
|----|----------|
| T1 | Fresh install (all tools missing) |
| T2 | Docker installed, daemon stopped |
| T3 | Cursor already installed |
| T4 | Both installed; bootstrap only launches container and services |
| T5 | Network unavailable (graceful failure) |
| T6 | Port in use (test `--force-ports` and interactive prompt) |
| T7 | `--repo demo-site` (skip selection) |
| T8 | `--repo cyvl-geoguesser` (full-stack) |
| T9 | `./dev select` then `./dev start` (switch repos) |

---

# 8. Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | -- | Original SRS |
| 2.0 | -- | OS-specific folders, shared scripts, CI/CD, Flask demo app |
| 3.0 | 2025-02-10 | Multi-repo architecture, port management, cyvl-geoguesser, corrected CLI flags, new acceptance criteria |
| 3.1 | 2025-02-10 | Removed implementation details (moved to SDD). SRS is now requirements-only. |
