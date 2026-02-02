<#
.SYNOPSIS
    dev.ps1 - Windows development helper

.DESCRIPTION
    Container management commands: up, down, shell, logs, etc.

.PARAMETER Command
    The command to execute

.PARAMETER RepoName
    Optional repository name for repo-specific commands

.EXAMPLE
    .\dev.ps1 up
    Start development container

.EXAMPLE
    .\dev.ps1 start demo-site
    Start demo-site services
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("up", "down", "shell", "start", "stop", "restart", "logs", "status", "install", "select", "list", "build", "clean", "help")]
    [string]$Command,
    
    [Parameter(Position = 1)]
    [string]$RepoName
)

$ErrorActionPreference = "Stop"

# Script directory (go up one level to repo root)
$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $ScriptDir

# Source utilities
. "$ScriptDir\scripts\utils.ps1"

$ContainerName = "workshop-dev"
$SelectedRepoFile = "$ScriptDir\.selected-repo"

function Get-SelectedRepo {
    if (Test-Path $SelectedRepoFile) {
        return Get-Content $SelectedRepoFile -Raw
    }
    return $null
}

function Set-SelectedRepo {
    param([string]$Repo)
    $Repo | Out-File -FilePath $SelectedRepoFile -NoNewline
}

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
    
    Write-Host ""
    Write-Host "Select a repository:" -ForegroundColor White
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
        Write-Host "$($repos[$i])" -NoNewline -ForegroundColor Green
        Write-Host " - $desc" -ForegroundColor Gray
    }
    Write-Host ""
    
    while ($true) {
        $selection = Read-Host "Enter selection (1-$($repos.Count))"
        
        if ($selection -match '^\d+$') {
            $num = [int]$selection
            if ($num -ge 1 -and $num -le $repos.Count) {
                $selected = $repos[$num - 1]
                Set-SelectedRepo $selected
                return $selected
            }
        }
        
        Write-ErrorMsg "Invalid selection"
    }
}

function Show-Usage {
    Write-Host @"
Workshop Bootstrap - Development Helper (Windows)

Usage: .\dev.ps1 <command> [repo-name]

Commands:
  up          Start development container
  down        Stop all containers
  shell       Open interactive shell in container
  start       Start repo services
  stop        Stop repo services
  restart     Restart repo services
  logs        View service logs
  status      Show container and service status
  install     Install repo dependencies
  select      Select/change active repository
  list        List available repositories
  build       Rebuild container image
  clean       Remove containers and images

Examples:
  .\dev.ps1 up                    # Start container
  .\dev.ps1 start demo-site       # Start demo-site services
  .\dev.ps1 start                 # Start services (prompts for repo)
  .\dev.ps1 logs                  # View logs for current repo
"@
}

function Test-ContainerRunning {
    $running = docker compose ps --status running 2>&1 | Select-String $ContainerName
    return $null -ne $running
}

function Ensure-ContainerRunning {
    if (-not (Test-ContainerRunning)) {
        Write-Info "Container not running, starting it first..."
        Invoke-Up
        Start-Sleep -Seconds 2
    }
}

function Invoke-Up {
    Write-Step "Starting development container..."
    $env:BUILD_TIME = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
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
    Ensure-ContainerRunning
    docker compose exec dev bash
}

function Invoke-Start {
    $repo = if ($RepoName) { $RepoName } else { Get-SelectedRepo }
    
    if (-not $repo) {
        $repo = Select-RepoInteractive
    }
    
    Set-SelectedRepo $repo
    Ensure-ContainerRunning
    
    Write-Step "Starting $repo services..."
    docker compose exec dev bash -c "/workspace/scripts/start-repo.sh $repo start"
}

function Invoke-Stop {
    $repo = if ($RepoName) { $RepoName } else { Get-SelectedRepo }
    
    if (-not $repo) {
        Write-ErrorMsg "No repository selected. Use: .\dev.ps1 stop <repo-name>"
        exit 1
    }
    
    Ensure-ContainerRunning
    
    Write-Step "Stopping $repo services..."
    docker compose exec dev bash -c "/workspace/scripts/start-repo.sh $repo stop"
}

function Invoke-Restart {
    $repo = if ($RepoName) { $RepoName } else { Get-SelectedRepo }
    
    if (-not $repo) {
        $repo = Select-RepoInteractive
    }
    
    Set-SelectedRepo $repo
    Ensure-ContainerRunning
    
    Write-Step "Restarting $repo services..."
    docker compose exec dev bash -c "/workspace/scripts/start-repo.sh $repo restart"
}

function Invoke-Logs {
    $repo = if ($RepoName) { $RepoName } else { Get-SelectedRepo }
    
    if (-not $repo) {
        Write-ErrorMsg "No repository selected. Use: .\dev.ps1 logs <repo-name>"
        exit 1
    }
    
    Ensure-ContainerRunning
    
    Write-Step "Showing logs for $repo..."
    docker compose exec dev bash -c "/workspace/scripts/start-repo.sh $repo logs"
}

function Invoke-Status {
    Write-Step "Container status:"
    docker compose ps
    
    $repo = Get-SelectedRepo
    if ($repo -and (Test-ContainerRunning)) {
        Write-Host ""
        Write-Host "Active repository: " -NoNewline
        Write-Host $repo -ForegroundColor Green
        docker compose exec dev bash -c "/workspace/scripts/start-repo.sh $repo status" 2>$null
    }
}

function Invoke-Install {
    $repo = if ($RepoName) { $RepoName } else { Get-SelectedRepo }
    
    if (-not $repo) {
        $repo = Select-RepoInteractive
    }
    
    Set-SelectedRepo $repo
    Ensure-ContainerRunning
    
    Write-Step "Installing dependencies for $repo..."
    docker compose exec dev bash -c "/workspace/scripts/start-repo.sh install $repo"
}

function Invoke-Select {
    $repo = Select-RepoInteractive
    Write-Success "Selected repository: $repo"
    Write-Info "Use '.\dev.ps1 start' to start services"
}

function Invoke-List {
    Write-Host ""
    Write-Host "Available repositories:" -ForegroundColor White
    Write-Host ""
    
    $currentRepo = Get-SelectedRepo
    
    Get-ChildItem -Path "$ScriptDir\repos" -Directory | ForEach-Object {
        $repoJson = Join-Path $_.FullName "repo.json"
        if (Test-Path $repoJson) {
            $name = $_.Name
            $desc = "No description"
            
            try {
                $json = Get-Content $repoJson -Raw | ConvertFrom-Json
                $desc = $json.description
            } catch {}
            
            $active = ""
            if ($name -eq $currentRepo) {
                $active = " (active)"
            }
            
            Write-Host "  $name" -NoNewline -ForegroundColor Green
            Write-Host $active -ForegroundColor Yellow
            Write-Host "    $desc" -ForegroundColor Gray
            Write-Host ""
        }
    }
}

function Invoke-Build {
    Write-Step "Rebuilding container image..."
    $env:BUILD_TIME = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    docker compose build --no-cache dev
    Write-Success "Image rebuilt"
}

function Invoke-Clean {
    Write-Step "Cleaning up Docker resources..."
    Write-Info "Stopping containers..."
    docker compose down --volumes --remove-orphans 2>$null
    Write-Info "Removing project images..."
    docker compose down --rmi local 2>$null
    
    # Remove selected repo file
    if (Test-Path $SelectedRepoFile) {
        Remove-Item $SelectedRepoFile
    }
    
    Write-Success "Cleanup complete"
}

switch ($Command) {
    "up" { Invoke-Up }
    "down" { Invoke-Down }
    "shell" { Invoke-Shell }
    "start" { Invoke-Start }
    "stop" { Invoke-Stop }
    "restart" { Invoke-Restart }
    "logs" { Invoke-Logs }
    "status" { Invoke-Status }
    "install" { Invoke-Install }
    "select" { Invoke-Select }
    "list" { Invoke-List }
    "build" { Invoke-Build }
    "clean" { Invoke-Clean }
    "help" { Show-Usage }
    default {
        if ([string]::IsNullOrEmpty($Command)) {
            Write-ErrorMsg "No command specified"
            Write-Host ""
            Show-Usage
            exit 1
        }
    }
}
