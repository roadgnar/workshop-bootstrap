# Workshop Bootstrap — Linux

Quick setup for Linux (Debian/Ubuntu primary, others best-effort).

## Quick Start

```bash
cd linux
./bootstrap
```

This will:
1. ✅ Install Docker Engine (via apt/dnf/pacman)
2. ✅ Install Cursor IDE (via AppImage)
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

## Supported Distributions

| Distro | Support Level | Package Manager |
|--------|---------------|-----------------|
| Ubuntu/Debian | ✅ Primary | apt |
| Linux Mint | ✅ Primary | apt |
| Pop!_OS | ✅ Primary | apt |
| Fedora | ⚡ Good | dnf |
| CentOS/RHEL | ⚡ Good | yum |
| Arch/Manjaro | ⚡ Good | pacman |
| Others | 🔧 Best-effort | convenience script |

## Troubleshooting

### Permission Denied (Docker)

Add yourself to the docker group:

```bash
sudo usermod -aG docker $USER
newgrp docker

# Then re-run
./bootstrap
```

Or log out and back in for the group change to take effect.

### Port Already in Use

Use the `--force-ports` flag to auto-kill blocking processes:

```bash
./bootstrap --force-ports
```

Or manually check what's using the port:

```bash
lsof -i :8080
# Then kill the process or use a different port
```

### Cursor Won't Launch

Cursor is installed as an AppImage at `~/.local/bin/cursor.AppImage`.

If it won't run:
```bash
# Make sure FUSE is installed (for AppImage support)
sudo apt install fuse libfuse2   # Debian/Ubuntu

# Or run directly
~/.local/bin/cursor.AppImage
```

### Docker Service Won't Start

```bash
# Check status
sudo systemctl status docker

# Start manually
sudo systemctl start docker
sudo systemctl enable docker

# Then re-run
./bootstrap
```
