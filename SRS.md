## Software Requirements Specification (SRS)

**Project:** Cross-platform “clone-and-run” repo bootstrap for Docker + Cursor + demo web app
**Target OS:** macOS, Windows, Linux
**Primary outcome:** A user can clone the repo and run a single command that (1) installs/starts Docker, (2) installs Cursor, (3) launches a dev container with dependencies, and (4) runs a demo website accessible from the host.

---

# 1. Introduction

## 1.1 Purpose

Define functional and non-functional requirements for a repository that provides an automated developer environment setup using Docker and Cursor across macOS, Windows, and Linux, including a containerized demo web application reachable from outside the container.

## 1.2 Scope

The repo will include:

* Cross-platform bootstrap scripts (macOS/Linux shell, Windows PowerShell).
* Detection and conditional installation of Docker and Cursor.
* Automated container launch with dependencies preconfigured.
* A demo web project served from within the container and accessible at `http://localhost:<port>` on the host.
* Optional configuration for editor-to-container development workflows (e.g., devcontainer-compatible configuration).

Out of scope:

* Full elimination of interactive OS security prompts for Docker Desktop on macOS/Windows.
* Enterprise device management (MDM), corporate proxy configuration, and locked-down environments beyond documented guidance.

## 1.3 Definitions

* **Docker daemon:** Background service that runs containers.
* **Docker Desktop:** Docker daemon + UI + VM backend for macOS/Windows.
* **Compose:** Multi-container orchestration (`docker compose`).
* **Dev container:** Editor-attached development environment (optional).
* **Idempotent:** Safe to run repeatedly; script should converge on the desired state.

---

# 2. Overall Description

## 2.1 Product Perspective

This is a self-contained repository template that:

* Provides a “one command” developer setup path.
* Uses Docker Compose and bind mounts to allow editing code on the host (via Cursor) while running it inside the container.
* Optionally supports a devcontainer-style workflow for attaching the editor to the container.

## 2.2 User Classes

* **New user (fresh laptop):** No Docker and/or Cursor installed.
* **Existing user:** Has Docker and/or Cursor installed; may have Docker not running.
* **Linux user:** May prefer Docker Engine over Docker Desktop.

## 2.3 Operating Environment

* macOS: Apple Silicon and Intel supported.
* Windows: Windows 10/11 with PowerShell; Docker Desktop likely WSL2-backed.
* Linux: Debian/Ubuntu baseline (others best-effort), systemd assumed for service management if present.

## 2.4 Constraints

* Installation steps may require admin privileges (sudo / UAC).
* Docker Desktop on macOS/Windows may require first-run interactive confirmation (permissions, license).
* Network access required to fetch installers/images unless offline mode is implemented.

## 2.5 Assumptions and Dependencies

* Git is available (or user can download repo as zip).
* A supported package manager exists or can be installed:

  * macOS: Homebrew preferred
  * Windows: WinGet preferred
  * Linux: apt preferred (baseline)
* Docker Hub or configured registry reachable for pulling images.

---

# 3. Functional Requirements

## 3.1 Bootstrap Command

**FR-001** The repo MUST provide a single entry command per platform:

* macOS/Linux: `./bootstrap`
* Windows: `.\bootstrap.ps1`

**FR-002** Bootstrap MUST:

1. Detect Docker installation state
2. Install Docker if missing
3. Ensure Docker daemon is running
4. Detect Cursor installation state
5. Install Cursor if missing
6. Build + start dev container(s)
7. Start the demo web service
8. Open Cursor to the repo (best-effort)

**FR-003** Bootstrap MUST be idempotent and safe to rerun.

## 3.2 Detection and Decision Logic

**FR-010** The system MUST detect:

* Docker CLI presence and version
* Docker daemon availability (`docker info` success)
* Docker Compose availability (`docker compose version`)
* Cursor CLI presence (`cursor --version`) OR Cursor application installed (OS-specific detection)

**FR-011** If Docker is installed but daemon is not running, bootstrap MUST attempt to start it (Desktop on macOS/Windows; service on Linux) and wait up to a configurable timeout for readiness.

**FR-012** If Docker and/or Cursor are already installed, bootstrap MUST NOT reinstall by default; it MAY offer an explicit `--reinstall` option.

## 3.3 Docker Installation

**FR-020 (macOS)** If Docker is missing, bootstrap MUST install Docker Desktop via a package manager (Homebrew preferred) or provide a fallback with clear instructions.

**FR-021 (Windows)** If Docker is missing, bootstrap MUST install Docker Desktop via WinGet preferred; fallback instructions if WinGet unavailable.

**FR-022 (Linux)** If Docker is missing, bootstrap MUST install Docker Engine via a supported method (apt repo or convenience installer), and start/enable the daemon where applicable.

**FR-023** Bootstrap MUST validate post-install that `docker` works and surface actionable errors if not.

## 3.4 Cursor Installation

**FR-030 (macOS)** If Cursor is missing, bootstrap MUST install Cursor via Homebrew cask preferred, with fallback instructions.

**FR-031 (Windows)** If Cursor is missing, bootstrap MUST install Cursor via WinGet preferred, with fallback instructions.

**FR-032 (Linux)** If Cursor is missing, bootstrap MUST support one of:

* Installing via an official apt repository; OR
* Downloading and installing a `.deb` package; OR
* Providing an interactive prompt and instructions if automation is not feasible.

**FR-033** After install, bootstrap MUST verify Cursor is launchable (best-effort). If not, it MUST continue container setup and provide next steps.

## 3.5 Containerized Dev Environment

**FR-040** The repo MUST include:

* `Dockerfile` defining dependencies
* `docker-compose.yml` defining a dev service
* Bind mount of repository into the container at `/workspace`
* A default command that keeps the container alive for development (e.g., `sleep infinity`), plus a separate command for running the demo service.

**FR-041** The repo MUST provide helper commands:

* `./dev up|down|shell|logs` (macOS/Linux)
* `.\dev.ps1 up|down|shell|logs` (Windows)

**FR-042** The container MUST expose required ports to the host.

## 3.6 Demo Web Project

**FR-050** The repo MUST include a demo web project inside the container that:

* Serves HTTP on a configurable port (default e.g., 8080)
* Is reachable from the host at `http://localhost:<port>`
* Returns a visible confirmation page (e.g., “It works” + build info)

**FR-051** The demo MUST start automatically after bootstrap completes (or as part of `dev up`), and bootstrap MUST print the URL.

**FR-052** The demo SHOULD support hot reload or rapid iteration (optional), but MUST at least serve reliably.

## 3.7 Cursor-to-Container Editing Workflow

Two supported modes:

**Mode A (baseline, required):** Cursor edits host files; container runs code via bind mount.
**FR-060** The system MUST support this mode without requiring any Cursor extension or container attachment.

**Mode B (optional):** Devcontainer-style attachment.
**FR-061** The repo SHOULD include `.devcontainer/devcontainer.json` for compatibility with devcontainer-capable editors.
**FR-062** Bootstrap MAY detect devcontainer capability and offer instructions, but MUST NOT block baseline mode.

## 3.8 UX, Logging, and Errors

**FR-070** Bootstrap MUST emit:

* A step-by-step progress log
* Clear error messages with remediation steps
* Exit codes: `0` success, non-zero failure with category codes (optional)

**FR-071** If Docker Desktop needs a first-run manual action, bootstrap MUST:

* Launch Docker Desktop (best-effort)
* Explain exactly what the user must do
* Exit cleanly with a retriable message (“re-run bootstrap after Docker is running”)

**FR-072** Bootstrap MUST avoid destructive actions by default (no deleting images/volumes).

---

# 4. External Interface Requirements

## 4.1 CLI Interface

* `./bootstrap [--reinstall-docker] [--reinstall-cursor] [--port 8080] [--no-open] [--timeout 300]`
* `.\bootstrap.ps1 [-ReinstallDocker] [-ReinstallCursor] [-Port 8080] [-NoOpen] [-TimeoutSec 300]`

## 4.2 File/Repo Structure

Required files:

* `bootstrap`, `bootstrap.ps1`
* `dev`, `dev.ps1`
* `Dockerfile`, `docker-compose.yml`
* `README.md` with platform-specific quickstart
* `scripts/` installers for each OS
* Demo app directory (e.g., `demo-site/`)

---

# 5. Non-Functional Requirements

## 5.1 Portability

**NFR-001** Scripts MUST run on:

* macOS: bash/zsh
* Linux: bash
* Windows: PowerShell 5+ (prefer PS7 compatibility)

## 5.2 Reliability

**NFR-010** Bootstrap MUST be idempotent and converge to a working setup.
**NFR-011** Timeouts MUST be configurable; readiness checks MUST be deterministic (`docker info`, HTTP health check).

## 5.3 Security

**NFR-020** Downloads MUST use HTTPS.
**NFR-021** Scripts MUST not exfiltrate data; no telemetry beyond package managers’ defaults.
**NFR-022** Privileged operations MUST be minimal and clearly indicated.

## 5.4 Maintainability

**NFR-030** Install methods MUST be encapsulated per OS in `scripts/`.
**NFR-031** Versions and dependencies SHOULD be pinned where practical (base image tags, lockfiles).

## 5.5 Performance

**NFR-040** First successful setup SHOULD complete with minimal manual steps beyond OS prompts; subsequent runs SHOULD be fast (no rebuild unless needed).

---

# 6. Acceptance Criteria

**AC-001** Fresh machine (no Docker, no Cursor): running bootstrap results in either:

* Fully working environment with container up, demo site reachable, Cursor installed/opened; OR
* A single documented manual step required (e.g., Docker Desktop first-run), after which rerunning bootstrap succeeds.

**AC-002** Machine with Docker installed but not running: bootstrap starts Docker and proceeds.

**AC-003** Machine with Cursor installed: bootstrap does not reinstall Cursor and proceeds.

**AC-004** Demo website is reachable from host browser at printed URL.

**AC-005** `dev shell` provides an interactive shell in the dev container.

---

# 7. Test Plan (Minimum)

## 7.1 OS Matrix

* macOS (Intel + Apple Silicon)
* Windows 11 (WSL2 enabled) + Windows 10 (where supported)
* Ubuntu LTS

## 7.2 Scenario Tests

* T1: Fresh install path
* T2: Docker already installed, daemon stopped
* T3: Cursor already installed
* T4: Both installed, bootstrap is no-op except container launch
* T5: Network unavailable (verify graceful failure messaging)
* T6: Port already in use (verify fallback or clear error)

## 7.3 Automated CI (optional)

* Lint scripts (shellcheck, PSScriptAnalyzer)
* Build container image
* Run container + curl health check to `localhost:<port>` (in CI environment that supports Docker)

---

# 8. Proposed Demo Implementation (for clarity)

* Container runs a minimal web server on `0.0.0.0:<port>` (e.g., Node/Express or Python/Flask).
* `docker-compose.yml` maps `<port>:<port>` to host.
* A `/health` endpoint returns 200, and `/` serves a static HTML page with repo/version info.

---

If you want, I can also provide the corresponding repository skeleton (file tree + initial contents) that directly implements this SRS, including the demo web app and the bootstrap scripts with the detection/install/start logic.
