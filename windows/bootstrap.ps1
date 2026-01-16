<#
.SYNOPSIS
    bootstrap.ps1 - Windows bootstrap script

.DESCRIPTION
    Installs Docker Desktop, Cursor IDE, and launches a containerized demo web application.

.PARAMETER ReinstallDocker
    Force reinstall Docker even if present

.PARAMETER ReinstallCursor
    Force reinstall Cursor even if present

.PARAMETER Port
    Port for demo website (default: 8080)

.PARAMETER NoOpen
    Don't open Cursor after setup

.PARAMETER TimeoutSec
    Timeout for Docker startup in seconds (default: 120)

.EXAMPLE
    .\bootstrap.ps1
    Standard setup with defaults

.EXAMPLE
    .\bootstrap.ps1 -Port 3000
    Use port 3000 for demo website
#>

[CmdletBinding()]
param(
    [switch]$ReinstallDocker,
    [switch]$ReinstallCursor,
    [int]$Port = 8080,
    [switch]$NoOpen,
    [int]$TimeoutSec = 120
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Script directory (go up one level to repo root)
$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $ScriptDir

# Source utilities
. "$ScriptDir\scripts\utils.ps1"
. "$ScriptDir\scripts\install-docker-windows.ps1"
. "$ScriptDir\scripts\install-cursor-windows.ps1"

function Main {
    Write-Banner
    
    Write-Info "Operating system: Windows"
    Write-Info "Demo port: $Port"
    Write-Info "Startup timeout: ${TimeoutSec}s"
    
    Setup-Docker
    Ensure-DockerRunning
    Setup-Cursor
    Setup-Containers
    Start-Demo
    
    if (-not $NoOpen) {
        Open-Editor
    }
    
    Print-Summary
}

function Setup-Docker {
    Write-Step "Checking Docker installation..."
    
    if ((Test-DockerInstalled) -and (-not $ReinstallDocker)) {
        Write-Success "Docker is installed"
        $version = docker --version 2>&1
        Write-Info $version
    }
    else {
        if ($ReinstallDocker) {
            Write-Info "Reinstalling Docker as requested..."
        }
        else {
            Write-Info "Docker not found, installing..."
        }
        
        Install-DockerWindows
    }
    
    if (Test-ComposeAvailable) {
        Write-Success "Docker Compose is available"
        $composeVersion = docker compose version 2>&1
        Write-Info $composeVersion
    }
    else {
        Write-ErrorMsg "Docker Compose not available"
        Write-Info "Please ensure Docker Desktop is properly installed"
        exit 1
    }
}

function Ensure-DockerRunning {
    Write-Step "Checking Docker daemon..."
    
    if (Test-DockerRunning) {
        Write-Success "Docker daemon is running"
        return
    }
    
    Write-Info "Docker daemon not running, starting..."
    $started = Start-DockerWindows -TimeoutSec $TimeoutSec
    
    if (-not $started) {
        Write-ErrorMsg "Failed to start Docker daemon"
        Write-Info ""
        Write-Info "Please start Docker Desktop manually and re-run this script"
        exit 1
    }
}

function Setup-Cursor {
    Write-Step "Checking Cursor installation..."
    
    if ((Test-CursorInstalled) -and (-not $ReinstallCursor)) {
        Write-Success "Cursor is installed"
        try {
            $version = cursor --version 2>&1
            Write-Info $version
        }
        catch {}
    }
    else {
        if ($ReinstallCursor) {
            Write-Info "Reinstalling Cursor as requested..."
        }
        else {
            Write-Info "Cursor not found, installing..."
        }
        
        Install-CursorWindows
    }
}

function Setup-Containers {
    Write-Step "Setting up Docker containers..."
    
    $env:PORT = $Port
    $env:BUILD_TIME = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $env:VERSION = "1.0.0"
    
    Write-Info "Building development container..."
    docker compose build dev
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Failed to build container"
        exit 1
    }
    
    Write-Info "Starting development container..."
    docker compose up -d dev
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Failed to start container"
        exit 1
    }
    
    Write-Success "Container is running"
}

function Start-Demo {
    Write-Step "Starting demo web service..."
    
    docker compose exec -d dev bash -c "cd /workspace/demo-site && python app.py"
    
    Write-Info "Waiting for demo service to be ready..."
    $elapsed = 0
    $maxWait = 30
    
    while ($elapsed -lt $maxWait) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$Port/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                Write-Host ""
                Write-Success "Demo service is running"
                return
            }
        }
        catch {}
        
        Start-Sleep -Seconds 1
        $elapsed++
        Write-Host "." -NoNewline
    }
    
    Write-Host ""
    Write-Warn "Demo service took longer than expected to start"
}

function Open-Editor {
    Write-Step "Opening Cursor..."
    
    $opened = Open-CursorWindows -Workspace $ScriptDir
    
    if (-not $opened) {
        Write-Warn "Could not open Cursor automatically"
        Write-Info "Please open Cursor manually and open this folder: $ScriptDir"
    }
}

function Print-Summary {
    Write-Separator
    Write-Host ""
    Write-Success "Bootstrap complete!"
    Write-Host ""
    Write-Host "    Demo website:  " -NoNewline
    Write-Host "http://localhost:$Port" -ForegroundColor Cyan
    Write-Host "    Health check:  " -NoNewline
    Write-Host "http://localhost:$Port/health" -ForegroundColor Cyan
    Write-Host "    API info:      " -NoNewline
    Write-Host "http://localhost:$Port/api/info" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    Useful commands (run from windows/ folder):" -ForegroundColor White
    Write-Host "      .\dev.ps1 up       - Start containers"
    Write-Host "      .\dev.ps1 down     - Stop containers"
    Write-Host "      .\dev.ps1 shell    - Open shell in container"
    Write-Host "      .\dev.ps1 logs     - View container logs"
    Write-Host ""
    Write-Separator
}

Main

