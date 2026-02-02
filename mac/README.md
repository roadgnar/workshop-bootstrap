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
3. ✅ Prompt you to select a repository
4. ✅ Check required ports (optionally free blocked ports)
5. ✅ Build and start the dev container
6. ✅ Launch your selected application
7. ✅ Open Cursor to the repo's code folder

## Commands

### Bootstrap Options

```bash
./bootstrap                      # Interactive repo selection
./bootstrap --repo demo-site     # Run demo-site directly
./bootstrap --repo cyvl-geoguesser  # Run CYVL GeoGuesser
./bootstrap --force-ports        # Auto-kill processes using required ports
./bootstrap --no-open            # Don't open Cursor
./bootstrap --reinstall-docker   # Force reinstall Docker
./bootstrap --reinstall-cursor   # Force reinstall Cursor
./bootstrap --timeout 180        # Longer startup timeout (default: 120s)
```

### Development Helper

```bash
./dev up            # Start containers
./dev down          # Stop containers
./dev shell         # Open shell in container
./dev start [repo]  # Start repo services
./dev stop [repo]   # Stop repo services
./dev restart [repo] # Restart repo services
./dev logs [repo]   # View service logs
./dev status        # Show container and service status
./dev install [repo] # Install repo dependencies
./dev select        # Select/change active repository
./dev list          # List available repositories
./dev build         # Rebuild container image
./dev clean         # Remove containers and images
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

Use the `--force-ports` flag to auto-kill blocking processes:

```bash
./bootstrap --force-ports
```

Or check what's using the port:

```bash
lsof -i :8080
# Then kill the process or use a different port
```

### Homebrew Not Found

Install Homebrew first:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Then re-run `./bootstrap`.
