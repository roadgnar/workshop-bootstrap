<#
.SYNOPSIS
    dev.ps1 - Windows development helper

.DESCRIPTION
    Container management commands: up, down, shell, logs, etc.

.PARAMETER Command
    The command to execute: up, down, shell, logs, restart, demo, build, status, clean

.EXAMPLE
    .\dev.ps1 up
    Start development container
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("up", "down", "shell", "logs", "restart", "demo", "build", "status", "clean", "help")]
    [string]$Command
)

$ErrorActionPreference = "Stop"

# Script directory (go up one level to repo root)
$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $ScriptDir

# Source utilities
. "$ScriptDir\scripts\utils.ps1"

$Port = if ($env:PORT) { $env:PORT } else { 8080 }
$ContainerName = "workshop-dev"

function Show-Usage {
    Write-Host @"
Workshop Bootstrap - Development Helper (Windows)

Usage: .\dev.ps1 <command>

Commands:
  up        Start development container
  down      Stop all containers
  shell     Open interactive shell in container
  logs      View container logs (follow mode)
  restart   Restart containers
  demo      Start/restart the demo web service
  build     Rebuild container image
  status    Show container status
  clean     Remove containers and images
"@
}

function Invoke-Up {
    Write-Step "Starting development container..."
    $env:PORT = $Port
    docker compose up -d dev
    Write-Success "Container started"
    docker compose ps
}

function Invoke-Down {
    Write-Step "Stopping containers..."
    docker compose down
    Write-Success "Containers stopped"
}

function Invoke-Shell {
    Write-Step "Opening shell in container..."
    
    $running = docker compose ps --status running 2>&1 | Select-String $ContainerName
    if (-not $running) {
        Write-Info "Container not running, starting it first..."
        Invoke-Up
    }
    
    docker compose exec dev bash
}

function Invoke-Logs {
    Write-Step "Showing container logs (Ctrl+C to exit)..."
    docker compose logs -f dev
}

function Invoke-Restart {
    Write-Step "Restarting containers..."
    docker compose restart dev
    Write-Success "Containers restarted"
}

function Invoke-Demo {
    Write-Step "Starting demo web service..."
    
    $running = docker compose ps --status running 2>&1 | Select-String $ContainerName
    if (-not $running) {
        Write-Info "Container not running, starting it first..."
        Invoke-Up
    }
    
    docker compose exec dev pkill -f "python app.py" 2>$null
    docker compose exec -d dev bash -c "cd /workspace/demo-site && python app.py"
    
    Write-Info "Waiting for demo service..."
    Start-Sleep -Seconds 2
    
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$Port/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Success "Demo service is running at http://localhost:$Port"
        }
    }
    catch {
        Write-Warn "Demo service may still be starting..."
        Write-Info "Check with: .\dev.ps1 logs"
    }
}

function Invoke-Build {
    Write-Step "Rebuilding container image..."
    $env:PORT = $Port
    $env:BUILD_TIME = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    docker compose build --no-cache dev
    Write-Success "Image rebuilt"
}

function Invoke-Status {
    Write-Step "Container status:"
    docker compose ps
    Write-Host ""
    Write-Info "Docker resources:"
    docker system df 2>$null
}

function Invoke-Clean {
    Write-Step "Cleaning up Docker resources..."
    Write-Info "Stopping containers..."
    docker compose down --volumes --remove-orphans 2>$null
    Write-Info "Removing project images..."
    docker compose down --rmi local 2>$null
    Write-Success "Cleanup complete"
}

switch ($Command) {
    "up" { Invoke-Up }
    "down" { Invoke-Down }
    "shell" { Invoke-Shell }
    "logs" { Invoke-Logs }
    "restart" { Invoke-Restart }
    "demo" { Invoke-Demo }
    "build" { Invoke-Build }
    "status" { Invoke-Status }
    "clean" { Invoke-Clean }
    "help" { Show-Usage }
    default {
        if ([string]::IsNullOrEmpty($Command)) {
            Write-Error "No command specified"
            Write-Host ""
            Show-Usage
            exit 1
        }
    }
}

