# Workshop Bootstrap — Windows

Quick setup for Windows 10/11.

## Quick Start

```powershell
cd windows
.\bootstrap.ps1
```

This will:
1. ✅ Install Docker Desktop (via WinGet)
2. ✅ Install Cursor IDE (via WinGet)
3. ✅ Prompt you to select a repository
4. ✅ Check required ports (optionally free blocked ports)
5. ✅ Build and start the dev container
6. ✅ Launch your selected application
7. ✅ Open Cursor to the repo's code folder

## Commands

### Bootstrap Options

```powershell
.\bootstrap.ps1                      # Interactive repo selection
.\bootstrap.ps1 -Repo demo-site      # Run demo-site directly
.\bootstrap.ps1 -Repo cyvl-geoguesser  # Run CYVL GeoGuesser
.\bootstrap.ps1 -ForcePorts          # Auto-kill processes using required ports
.\bootstrap.ps1 -NoOpen              # Don't open Cursor
.\bootstrap.ps1 -ReinstallDocker     # Force reinstall Docker
.\bootstrap.ps1 -ReinstallCursor     # Force reinstall Cursor
.\bootstrap.ps1 -TimeoutSec 180      # Longer startup timeout (default: 120s)
```

### Development Helper

```powershell
.\dev.ps1 up            # Start containers
.\dev.ps1 down          # Stop containers
.\dev.ps1 shell         # Open shell in container
.\dev.ps1 start [repo]  # Start repo services
.\dev.ps1 stop [repo]   # Stop repo services
.\dev.ps1 restart [repo] # Restart repo services
.\dev.ps1 logs [repo]   # View service logs
.\dev.ps1 status        # Show container and service status
.\dev.ps1 install [repo] # Install repo dependencies
.\dev.ps1 select        # Select/change active repository
.\dev.ps1 list          # List available repositories
.\dev.ps1 build         # Rebuild container image
.\dev.ps1 clean         # Remove containers and images
```

## Requirements

- Windows 10 (build 19041+) or Windows 11
- PowerShell 5.1+ (PowerShell 7 recommended)
- WSL2 enabled (Docker Desktop requirement)
- WinGet (recommended, for automated installs)

## Pre-Setup: Enable WSL2

Docker Desktop requires WSL2. If not already enabled:

```powershell
# Run as Administrator
wsl --install
# Restart your computer
```

## Troubleshooting

### Docker Desktop First-Run

Docker Desktop requires manual first-run setup:

1. Open Docker Desktop from Start Menu
2. Accept the license agreement
3. Complete WSL2 setup if prompted
4. Re-run `.\bootstrap.ps1`

### WinGet Not Found

Install WinGet (App Installer) from the Microsoft Store, or the bootstrap will attempt a direct download fallback.

### Port Already in Use

Use the `-ForcePorts` flag to auto-kill blocking processes:

```powershell
.\bootstrap.ps1 -ForcePorts
```

Or check what's using the port:

```powershell
netstat -ano | findstr :8080
# Note the PID, then:
taskkill /PID <pid> /F
```

### Execution Policy Error

If you see "running scripts is disabled", run:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### WSL2 Issues

```powershell
# Check WSL status
wsl --status

# Update WSL
wsl --update

# Set default version to 2
wsl --set-default-version 2
```

### Docker Won't Start

1. Ensure WSL2 is properly installed
2. Check Docker Desktop settings → Resources → WSL Integration
3. Try restarting Docker Desktop
4. Check Windows Event Viewer for errors
