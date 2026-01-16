# Workshop Bootstrap — macOS

Quick setup for macOS (Apple Silicon & Intel).

## Quick Start

```bash
cd mac
./bootstrap
```

This will:
1. ✅ Install Docker Desktop (via Homebrew)
2. ✅ Install Cursor IDE (via Homebrew)
3. ✅ Build and start the dev container
4. ✅ Launch demo website at http://localhost:8080
5. ✅ Open Cursor to the project

## Commands

### Bootstrap Options

```bash
./bootstrap                    # Standard setup
./bootstrap --port 3000        # Use different port
./bootstrap --no-open          # Don't open Cursor
./bootstrap --reinstall-docker # Force reinstall Docker
./bootstrap --reinstall-cursor # Force reinstall Cursor
./bootstrap --timeout 180      # Longer Docker startup timeout
```

### Development Helper

```bash
./dev up        # Start containers
./dev down      # Stop containers
./dev shell     # Open shell in container
./dev logs      # View container logs
./dev restart   # Restart containers
./dev demo      # Start/restart demo service
./dev build     # Rebuild container image
./dev status    # Show container status
./dev clean     # Remove containers and images
```

## Requirements

- macOS 10.15+ (Catalina or newer)
- Apple Silicon (M1/M2/M3) or Intel
- Homebrew (will be suggested if missing)

## Troubleshooting

### Docker Desktop First-Run

Docker Desktop requires manual first-run setup:

1. Open Docker Desktop from `/Applications`
2. Accept the license agreement
3. Complete any permission prompts
4. Re-run `./bootstrap`

### Port Already in Use

```bash
./bootstrap --port 3000
# or
PORT=3000 ./dev up
```

### Homebrew Not Found

Install Homebrew first:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Then re-run `./bootstrap`.

