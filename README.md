# Workshop Bootstrap

A cross-platform "clone-and-run" developer environment that automatically sets up **Docker**, **Cursor IDE**, and a **containerized demo web application**.

```
┌─────────────────────────────────────────────────────────────┐
│  Clone → cd into your OS folder → Run bootstrap → Done!     │
└─────────────────────────────────────────────────────────────┘
```

---

## Quick Start

### 🍎 macOS

```bash
git clone <repo-url> workshop-bootstrap
cd workshop-bootstrap/mac
./bootstrap
```

📖 [Full macOS instructions →](mac/README.md)

---

### 🐧 Linux

```bash
git clone <repo-url> workshop-bootstrap
cd workshop-bootstrap/linux
./bootstrap
```

📖 [Full Linux instructions →](linux/README.md)

---

### 🪟 Windows

```powershell
git clone <repo-url> workshop-bootstrap
cd workshop-bootstrap\windows
.\bootstrap.ps1
```

📖 [Full Windows instructions →](windows/README.md)

---

## What Happens

The bootstrap script will:

1. ✅ **Install Docker** (Desktop on Mac/Windows, Engine on Linux)
2. ✅ **Install Cursor IDE** (via Homebrew/WinGet/AppImage)
3. ✅ **Build and start** the dev container
4. ✅ **Launch demo website** at http://localhost:8080
5. ✅ **Open Cursor** to the project

---

## After Setup

| Resource | URL |
|----------|-----|
| Demo Website | http://localhost:8080 |
| Health Check | http://localhost:8080/health |
| API Info | http://localhost:8080/api/info |

---

## Project Structure

```
workshop-bootstrap/
│
├── mac/                       # ← macOS users start here
│   ├── bootstrap              #    Main setup script
│   ├── dev                    #    Development helper
│   └── README.md              #    macOS-specific docs
│
├── linux/                     # ← Linux users start here
│   ├── bootstrap              #    Main setup script
│   ├── dev                    #    Development helper
│   └── README.md              #    Linux-specific docs
│
├── windows/                   # ← Windows users start here
│   ├── bootstrap.ps1          #    Main setup script
│   ├── dev.ps1                #    Development helper
│   └── README.md              #    Windows-specific docs
│
├── scripts/                   # Shared logic (don't run directly)
│   ├── bootstrap-common.sh    #    Shared bootstrap logic
│   ├── dev-common.sh          #    Shared dev helper logic
│   ├── utils.sh / utils.ps1   #    Utility functions
│   ├── install-docker-*.sh    #    Docker installers
│   └── install-cursor-*.sh    #    Cursor installers
│
├── demo-site/                 # Demo web application
│   ├── app.py                 #    Flask app
│   ├── requirements.txt
│   └── templates/
│       └── index.html
│
├── Dockerfile
├── docker-compose.yml
├── .devcontainer/             # Optional: VS Code/Cursor devcontainer
└── README.md                  # This file
```

---

## Development Commands

Each OS folder has a `dev` script with the same commands:

| Command | Description |
|---------|-------------|
| `up` | Start containers |
| `down` | Stop containers |
| `shell` | Open shell in container |
| `logs` | View container logs |
| `restart` | Restart containers |
| `demo` | Start/restart demo service |
| `build` | Rebuild container image |
| `status` | Show container status |
| `clean` | Remove containers and images |

**Examples:**

```bash
# macOS
cd mac && ./dev up

# Linux
cd linux && ./dev shell

# Windows
cd windows; .\dev.ps1 logs
```

---

## Development Workflows

### Mode A: Host Editing (Default)

Edit files on your host machine with Cursor. Changes sync to the container via bind mount.

```
┌─────────────┐      bind mount      ┌──────────────────┐
│   Cursor    │ ◄──────────────────► │  Dev Container   │
│  (on host)  │      /workspace      │  (runs code)     │
└─────────────┘                      └──────────────────┘
```

### Mode B: Dev Container

Attach Cursor directly to the container:

1. Open Cursor
2. Install "Dev Containers" extension
3. `Cmd/Ctrl + Shift + P` → "Dev Containers: Reopen in Container"

---

## Technical Details

- **Container Base**: Python 3.12-slim
- **Web Framework**: Flask 3.0
- **Production Server**: Gunicorn
- **Default Port**: 8080
- **Workspace Mount**: `/workspace`

---

## License

MIT License - Feel free to use this as a template for your own projects.
