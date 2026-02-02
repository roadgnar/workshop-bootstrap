# Workshop Bootstrap

A cross-platform "clone-and-run" developer environment that automatically sets up **Docker**, **Cursor IDE**, and runs your selected application in a container.

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
3. ✅ **Prompt you to select a repository** to run
4. ✅ **Check required ports** (optionally kill blocking processes)
5. ✅ **Build and start** the development container
6. ✅ **Install dependencies** and launch your application
7. ✅ **Open Cursor** directly to the repo's code folder

---

## Available Repositories

| Repository | Description |
|------------|-------------|
| `demo-site` | Demo Flask web application |
| `cyvl-geoguesser` | CYVL GeoGuesser - 360° imagery guessing game |

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
├── repos/                     # Application repositories
│   ├── demo-site/             #    Demo Flask application
│   │   ├── code/              #    Application source code
│   │   ├── scripts/           #    Repo-specific scripts
│   │   │   └── start.sh       #    Service startup script
│   │   └── repo.json          #    Repository metadata
│   │
│   └── cyvl-geoguesser/       #    CYVL GeoGuesser
│       ├── code/              #    Frontend + Backend code
│       ├── scripts/           #    Repo-specific scripts
│       │   └── start.sh       #    Service startup script
│       └── repo.json          #    Repository metadata
│
├── scripts/                   # Shared logic (don't run directly)
│   ├── bootstrap-common.sh    #    Shared bootstrap logic
│   ├── dev-common.sh          #    Shared dev helper logic
│   ├── start-repo.sh          #    Generic repo service manager
│   ├── utils.sh / utils.ps1   #    Utility functions
│   ├── install-docker-*.sh    #    Docker installers
│   └── install-cursor-*.sh    #    Cursor installers
│
├── Dockerfile                 #    Repo-agnostic container
├── docker-compose.yml         #    Container orchestration
├── .devcontainer/             #    VS Code/Cursor devcontainer
└── README.md                  #    This file
```

---

## Development Commands

Each OS folder has a `dev` script with the same commands:

| Command | Description |
|---------|-------------|
| `up` | Start development container |
| `down` | Stop all containers |
| `shell` | Open shell in container |
| `start [repo]` | Start repo services |
| `stop [repo]` | Stop repo services |
| `restart [repo]` | Restart repo services |
| `logs [repo]` | View service logs |
| `status` | Show container and service status |
| `install [repo]` | Install repo dependencies |
| `select` | Select/change active repository |
| `list` | List available repositories |
| `build` | Rebuild container image |
| `clean` | Remove containers and images |

**Examples:**

```bash
# macOS
cd mac && ./dev up
./dev start demo-site
./dev logs

# Linux
cd linux && ./dev select    # Choose a repo interactively
./dev start                 # Start selected repo

# Check status
./dev status
```

---

## Bootstrap Options

```bash
./bootstrap                          # Interactive repo selection
./bootstrap --repo demo-site         # Run demo-site directly
./bootstrap --repo cyvl-geoguesser   # Run CYVL GeoGuesser directly
./bootstrap --force-ports            # Auto-kill processes using required ports
./bootstrap --no-open                # Skip opening Cursor
./bootstrap --reinstall-docker       # Force reinstall Docker
./bootstrap --reinstall-cursor       # Force reinstall Cursor
./bootstrap --timeout 180            # Set startup timeout (default: 120s)
```

**Windows equivalent flags:** `-Repo`, `-ForcePorts`, `-NoOpen`, `-ReinstallDocker`, `-ReinstallCursor`, `-TimeoutSec`

---

## Adding a New Repository

To add a new repository:

1. Create a folder under `repos/` with your repo name
2. Add the following structure:
   ```
   repos/your-repo/
   ├── code/           # Your application source code
   ├── scripts/
   │   └── start.sh    # Service startup script
   └── repo.json       # Repository metadata
   ```

3. Create `repo.json`:
   ```json
   {
     "name": "your-repo",
     "description": "Your application description",
     "stack": "python",
     "ports": [8080],
     "healthcheck": "http://localhost:8080/health",
     "urls": {
       "Website": "http://localhost:8080"
     }
   }
   ```

4. Create `scripts/start.sh` to manage your services (see existing repos for examples)

---

## Technical Details

- **Container Base**: Python 3.12-slim + Node.js 22 + npm 11
- **Python Package Manager**: uv (for workspaces) / pip (for requirements.txt)
- **Workspace Mount**: `/workspace`
- **Repos Location**: `/workspace/repos/`
- **Hot Reload**: Enabled for both Flask (debug mode) and Vite (HMR)

---

## License

MIT License - Feel free to use this as a template for your own projects.
