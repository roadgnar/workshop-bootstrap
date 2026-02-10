<#
.SYNOPSIS
    bootstrap.ps1 - Windows bootstrap script

.DESCRIPTION
    Installs Docker Desktop, Cursor IDE, and launches a containerized application.

.PARAMETER Repo
    Repository to run (skips interactive selection)

.PARAMETER ForcePorts
    Auto-kill processes using required ports (no prompt)

.PARAMETER ReinstallDocker
    Force reinstall Docker even if present

.PARAMETER ReinstallCursor
    Force reinstall Cursor even if present

.PARAMETER NoOpen
    Don't open Cursor after setup

.PARAMETER TimeoutSec
    Timeout for Docker startup in seconds (default: 120)

.EXAMPLE
    .\bootstrap.ps1
    Interactive repo selection

.EXAMPLE
    .\bootstrap.ps1 -Repo demo-site
    Run demo-site directly
#>

[CmdletBinding()]
param(
    [string]$Repo,
    [switch]$ForcePorts,
    [switch]$ReinstallDocker,
    [switch]$ReinstallCursor,
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

$SelectedRepoFile = "$ScriptDir\.selected-repo"

function Get-AvailableRepos {
    $repos = @()
    Get-ChildItem -Path "$ScriptDir\repos" -Directory | ForEach-Object {
        $repoJson = Join-Path $_.FullName "repo.json"
        if (Test-Path $repoJson) {
            $repos += $_.Name
        }
    }
    return $repos
}

function Select-RepoInteractive {
    $repos = Get-AvailableRepos
    
    if ($repos.Count -eq 0) {
        Write-ErrorMsg "No repositories found in repos/"
        exit 1
    }
    
    Write-Separator
    Write-Host ""
    Write-Host "Select a repository to run:" -ForegroundColor White -NoNewline
    Write-Host ""
    Write-Host ""
    
    for ($i = 0; $i -lt $repos.Count; $i++) {
        $repoPath = Join-Path "$ScriptDir\repos" $repos[$i]
        $repoJson = Join-Path $repoPath "repo.json"
        $desc = "No description"
        
        try {
            $json = Get-Content $repoJson -Raw | ConvertFrom-Json
            $desc = $json.description
        } catch {}
        
        Write-Host "  $($i + 1)) " -NoNewline -ForegroundColor White
        Write-Host $repos[$i] -ForegroundColor Green
        Write-Host "     $desc" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Separator
    
    while ($true) {
        $selection = Read-Host "Enter selection (1-$($repos.Count))"
        
        if ($selection -match '^\d+$') {
            $num = [int]$selection
            if ($num -ge 1 -and $num -le $repos.Count) {
                $script:Repo = $repos[$num - 1]
                $script:Repo | Out-File -FilePath $SelectedRepoFile -NoNewline
                Write-Host ""
                Write-Success "Selected: $($script:Repo)"
                return
            }
        }
        
        Write-ErrorMsg "Invalid selection. Please enter a number between 1 and $($repos.Count)"
    }
}

function Test-SelectedRepo {
    $repoPath = Join-Path "$ScriptDir\repos" $Repo
    
    if (-not (Test-Path $repoPath)) {
        Write-ErrorMsg "Repository not found: $Repo"
        Write-Host ""
        Write-Host "Available repositories:"
        Get-AvailableRepos | ForEach-Object { Write-Host "  - $_" }
        exit 1
    }
    
    $repoJson = Join-Path $repoPath "repo.json"
    if (-not (Test-Path $repoJson)) {
        Write-ErrorMsg "No repo.json found in: $Repo"
        exit 1
    }
    
    $startScript = Join-Path $repoPath "scripts\start.sh"
    if (-not (Test-Path $startScript)) {
        Write-ErrorMsg "No scripts/start.sh found in: $Repo"
        exit 1
    }
}

function Main {
    Write-Banner
    
    Write-Info "Operating system: Windows"
    Write-Info "Startup timeout: ${TimeoutSec}s"
    
    # Select repo if not specified
    if ([string]::IsNullOrEmpty($Repo)) {
        Select-RepoInteractive
    } else {
        Test-SelectedRepo
        Write-Info "Selected repository: $Repo"
    }
    
    Setup-Docker
    Ensure-DockerRunning
    Setup-Cursor
    Check-RequiredPorts
    Setup-Containers
    Start-RepoServices
    
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
}

function Ensure-DockerRunning {
    Write-Step "Checking Docker daemon..."
    
    if (Test-DockerRunning) {
        Write-Success "Docker daemon is running"
    }
    else {
        Write-Info "Docker daemon not running, starting..."
        $started = Start-DockerWindows -TimeoutSec $TimeoutSec
        
        if (-not $started) {
            Write-ErrorMsg "Failed to start Docker daemon"
            Write-Info ""
            Write-Info "Please start Docker Desktop manually and re-run this script"
            exit 1
        }
    }
    
    # Check Docker Compose (must be after daemon is running)
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

function Check-RequiredPorts {
    Write-Step "Checking required ports..."
    
    # Stop any existing containers first to free Docker-bound ports
    if (Test-DockerRunning) {
        $containers = docker ps -q 2>$null
        if ($containers) {
            Write-Info "Stopping existing containers to free ports..."
            docker compose down 2>$null | Out-Null
            docker stop $containers 2>$null | Out-Null
        }
    }
    
    # Default ports
    $ports = @(8080, 5173, 8000, 3000)
    
    # Try to get ports from repo.json
    if ($Repo) {
        $repoPath = Join-Path "$ScriptDir\repos" $Repo
        $repoJson = Join-Path $repoPath "repo.json"
        
        if (Test-Path $repoJson) {
            try {
                $json = Get-Content $repoJson -Raw | ConvertFrom-Json
                if ($json.ports) {
                    $ports = $json.ports
                }
            } catch {}
        }
    }
    
    Write-Info "Checking ports: $($ports -join ', ')"
    
    $result = Test-AndFreePorts -Ports $ports -Force:$ForcePorts
    
    if (-not $result) {
        Write-Host ""
        $retry = Read-Host "    ? Ports could not be freed. Try to continue anyway? [y/N]"
        
        if ($retry -match '^[Yy]$') {
            Write-Warn "Continuing with ports potentially in use -- services may fail to bind"
        }
        else {
            Write-ErrorMsg "Bootstrap aborted. Free the ports above and try again."
            exit 1
        }
    }
    else {
        Write-Success "All required ports are available"
    }
}

function Setup-Containers {
    Write-Step "Setting up Docker containers..."
    
    $env:BUILD_TIME = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $env:VERSION = "1.0.0"
    $env:SELECTED_REPO = $Repo
    
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

function Start-RepoServices {
    $repoPath = Join-Path "$ScriptDir\repos" $Repo
    $repoJson = Join-Path $repoPath "repo.json"
    
    Write-Step "Starting $Repo services..."
    
    # Install dependencies
    Write-Info "Installing dependencies..."
    docker compose exec dev bash -c "/workspace/scripts/start-repo.sh install $Repo" 2>$null
    
    # Start services
    Write-Info "Starting services..."
    docker compose exec -d dev bash -c "/workspace/scripts/start-repo.sh $Repo start"
    
    # Wait for health check
    try {
        $json = Get-Content $repoJson -Raw | ConvertFrom-Json
        $healthcheck = $json.healthcheck
    } catch {
        $healthcheck = $null
    }
    
    if ($healthcheck) {
        Write-Info "Waiting for services to be ready..."
        $elapsed = 0
        $maxWait = 60
        
        while ($elapsed -lt $maxWait) {
            try {
                $response = Invoke-WebRequest -Uri $healthcheck -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
                if ($response.StatusCode -eq 200) {
                    Write-Host ""
                    Write-Success "Services are running"
                    return
                }
            }
            catch {}
            
            Start-Sleep -Seconds 2
            $elapsed += 2
            Write-Host "." -NoNewline
        }
        
        Write-Host ""
        Write-Warn "Services took longer than expected to start"
        Write-Info "Check logs with: .\dev.ps1 logs"
    } else {
        Start-Sleep -Seconds 3
        Write-Success "Services started"
    }
}

function Open-Editor {
    Write-Step "Opening Cursor..."
    
    # Open Cursor to the selected repo's code folder
    $repoCodePath = Join-Path "$ScriptDir\repos\$Repo" "code"
    
    if (Test-Path $repoCodePath -PathType Container) {
        $opened = Open-CursorWindows -Workspace $repoCodePath
        $targetPath = $repoCodePath
    } else {
        # Fallback to root if code folder doesn't exist
        $opened = Open-CursorWindows -Workspace $ScriptDir
        $targetPath = $ScriptDir
    }
    
    if (-not $opened) {
        Write-Warn "Could not open Cursor automatically"
        Write-Info "Please open Cursor manually and open this folder: $targetPath"
    }
}

function Print-Summary {
    $repoPath = Join-Path "$ScriptDir\repos" $Repo
    $repoJson = Join-Path $repoPath "repo.json"
    
    Write-Separator
    Write-Host ""
    Write-Success "Bootstrap complete!"
    Write-Host ""
    Write-Host "    Repository: " -NoNewline
    Write-Host $Repo -ForegroundColor Cyan
    Write-Host "    Code folder: " -NoNewline
    Write-Host "repos\$Repo\code" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    URLs:" -ForegroundColor White
    
    try {
        $json = Get-Content $repoJson -Raw | ConvertFrom-Json
        $json.urls.PSObject.Properties | ForEach-Object {
            Write-Host "      $($_.Name): " -NoNewline
            Write-Host $_.Value -ForegroundColor Cyan
        }
    } catch {}
    
    Write-Host ""
    Write-Host "    Useful commands (run from windows/ folder):" -ForegroundColor White
    Write-Host "      .\dev.ps1 up       - Start container"
    Write-Host "      .\dev.ps1 down     - Stop containers"
    Write-Host "      .\dev.ps1 shell    - Open shell in container"
    Write-Host "      .\dev.ps1 start    - Start repo services"
    Write-Host "      .\dev.ps1 logs     - View service logs"
    Write-Host "      .\dev.ps1 status   - Show status"
    Write-Host ""
    Write-Separator
}

Main
