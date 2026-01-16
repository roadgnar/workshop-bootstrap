# utils.ps1 - Shared utility functions for bootstrap scripts (PowerShell)
# Part of workshop-bootstrap

# Logging functions with colors
function Write-Step {
    param([string]$Message)
    Write-Host "`n==> " -ForegroundColor Blue -NoNewline
    Write-Host $Message -ForegroundColor White
}

function Write-Info {
    param([string]$Message)
    Write-Host "    i " -ForegroundColor Cyan -NoNewline
    Write-Host $Message
}

function Write-Success {
    param([string]$Message)
    Write-Host "    √ " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Warn {
    param([string]$Message)
    Write-Host "    ! " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-Error {
    param([string]$Message)
    Write-Host "    X " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function Write-Separator {
    Write-Host ("─" * 56) -ForegroundColor Blue
}

function Write-Banner {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           Workshop Bootstrap Environment              ║" -ForegroundColor Cyan
    Write-Host "║       Docker + Cursor + Demo Web Application          ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

# Check if command exists
function Test-CommandExists {
    param([string]$Command)
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

# Check if Docker is installed
function Test-DockerInstalled {
    return Test-CommandExists "docker"
}

# Check if Docker daemon is running
function Test-DockerRunning {
    try {
        $null = docker info 2>&1
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

# Check if Docker Compose is available
function Test-ComposeAvailable {
    try {
        $null = docker compose version 2>&1
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

# Check if Cursor is installed
function Test-CursorInstalled {
    if (Test-CommandExists "cursor") {
        return $true
    }
    
    # Check common install locations
    $paths = @(
        "$env:LOCALAPPDATA\Programs\cursor\Cursor.exe",
        "$env:ProgramFiles\Cursor\Cursor.exe"
    )
    
    foreach ($path in $paths) {
        if (Test-Path $path) {
            return $true
        }
    }
    
    return $false
}

# Wait for a condition with timeout
function Wait-ForCondition {
    param(
        [scriptblock]$Condition,
        [int]$TimeoutSec = 60,
        [int]$IntervalSec = 2
    )
    
    $elapsed = 0
    while (-not (& $Condition)) {
        if ($elapsed -ge $TimeoutSec) {
            return $false
        }
        Start-Sleep -Seconds $IntervalSec
        $elapsed += $IntervalSec
        Write-Host "." -NoNewline
    }
    Write-Host ""
    return $true
}

# Check URL is reachable
function Test-UrlReachable {
    param(
        [string]$Url,
        [int]$TimeoutSec = 5
    )
    
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
        return $response.StatusCode -eq 200
    }
    catch {
        return $false
    }
}

# Get local IP address
function Get-LocalIP {
    try {
        $ip = (Get-NetIPAddress -AddressFamily IPv4 | 
               Where-Object { $_.InterfaceAlias -notmatch 'Loopback' -and $_.IPAddress -notlike '169.*' } | 
               Select-Object -First 1).IPAddress
        return $ip
    }
    catch {
        return "localhost"
    }
}

# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Run command as administrator
function Invoke-AsAdmin {
    param([string]$Command)
    
    Start-Process powershell -Verb RunAs -ArgumentList "-Command", $Command -Wait
}

