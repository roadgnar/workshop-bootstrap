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

```bash
./bootstrap --port 3000
# or
PORT=3000 ./dev up
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

