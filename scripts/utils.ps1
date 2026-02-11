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
    Write-Host "    v " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Warn {
    param([string]$Message)
    Write-Host "    ! " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "    X " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function Write-Separator {
    Write-Host ("-" * 56) -ForegroundColor Blue
}

function Write-Banner {
    Write-Host ""
    Write-Host ("=" * 56) -ForegroundColor Cyan
    Write-Host "       Workshop Bootstrap Environment" -ForegroundColor Cyan
    Write-Host "   Docker + Cursor + Demo Web Application" -ForegroundColor Cyan
    Write-Host ("=" * 56) -ForegroundColor Cyan
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

# =============================================================================
# Port Management Functions
# =============================================================================

# Check if a port is held by a Docker container
function Test-DockerPort {
    param([int]$Port)
    
    if (-not (Test-DockerRunning)) { return $false }
    
    try {
        $output = docker ps --format '{{.Ports}}' 2>&1
        return $output -match "0\.0\.0\.0:$Port->"
    }
    catch { return $false }
}

# Get process using a specific port
function Get-PortProcess {
    param([int]$Port)
    
    try {
        $connection = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
        if ($connection) {
            return Get-Process -Id $connection.OwningProcess -ErrorAction SilentlyContinue
        }
    }
    catch {}
    
    return $null
}

# Check if a port is in use
function Test-PortInUse {
    param([int]$Port)
    
    # Check Docker first
    if (Test-DockerPort -Port $Port) { return $true }
    
    return $null -ne (Get-PortProcess -Port $Port)
}

# Kill process using a port
function Stop-PortProcess {
    param([int]$Port)
    
    # If Docker is holding the port, stop containers
    if (Test-DockerPort -Port $Port) {
        Write-Info "Port $Port is held by a Docker container, stopping containers..."
        docker compose down 2>$null
        Start-Sleep -Seconds 2
        return -not (Test-PortInUse -Port $Port)
    }
    
    $process = Get-PortProcess -Port $Port
    if ($process) {
        try {
            Stop-Process -Id $process.Id -Force -ErrorAction Stop
            Start-Sleep -Seconds 1
            return $true
        }
        catch {
            Write-Warn "Could not stop process $($process.Id): $_"
            return $false
        }
    }
    return $false
}

# Print manual port-freeing commands for Windows
# Only shows the specific blocked ports
function Write-PortHelp {
    param([int[]]$Ports)
    
    $hasDockerPorts = $false
    foreach ($port in $Ports) {
        if (Test-DockerPort -Port $port) { $hasDockerPorts = $true; break }
    }
    
    Write-Host ""
    Write-Info "Free the blocked ports and re-run bootstrap:"
    Write-Host ""
    
    if ($hasDockerPorts) {
        Write-Host "      # Stop Docker containers holding these ports" -ForegroundColor DarkCyan
        Write-Host "      docker compose down"
        Write-Host ""
    }
    
    foreach ($port in $Ports) {
        if (-not (Test-DockerPort -Port $port)) {
            Write-Host "      Stop-Process -Id (Get-NetTCPConnection -LocalPort $port -State Listen).OwningProcess -Force"
        }
    }
    Write-Host ""
}

# Check ports and optionally free them
function Test-AndFreePorts {
    param(
        [int[]]$Ports,
        [switch]$Force
    )
    
    $blockedPorts = @()
    $portInfo = @()
    
    # Check which ports are in use
    foreach ($port in $Ports) {
        if (Test-PortInUse -Port $port) {
            $blockedPorts += $port
            
            if (Test-DockerPort -Port $port) {
                $portInfo += @{ Port = $port; PID = ""; Name = "Docker container" }
            }
            else {
                $process = Get-PortProcess -Port $port
                if ($process) {
                    $portInfo += @{ Port = $port; PID = $process.Id; Name = $process.ProcessName }
                }
                else {
                    $portInfo += @{ Port = $port; PID = ""; Name = "unknown process" }
                }
            }
        }
    }
    
    # If no ports blocked, we're good
    if ($blockedPorts.Count -eq 0) {
        return $true
    }
    
    Write-Warn "The following ports are already in use:"
    foreach ($info in $portInfo) {
        if ($info.PID) {
            Write-Info "  - Port $($info.Port) (PID: $($info.PID), Process: $($info.Name))"
        }
        else {
            Write-Info "  - Port $($info.Port) ($($info.Name))"
        }
    }
    Write-Host ""
    
    # If force flag is set, kill without asking
    if ($Force) {
        Write-Info "Stopping processes on blocked ports..."
        $failed = $false
        foreach ($port in $blockedPorts) {
            if (Stop-PortProcess -Port $port) {
                Write-Success "Freed port $port"
            }
            else {
                Write-ErrorMsg "Failed to free port $port"
                $failed = $true
            }
        }
        
        if ($failed) {
            Write-PortHelp -Ports $blockedPorts
            return $false
        }
        return $true
    }
    
    # Ask user for confirmation
    $response = Read-Host "    ? Stop these processes to continue? [y/N]"
    
    if ($response -match '^[Yy]$') {
        $failed = $false
        foreach ($port in $blockedPorts) {
            if (Stop-PortProcess -Port $port) {
                Write-Success "Freed port $port"
            }
            else {
                Write-ErrorMsg "Failed to free port $port"
                $failed = $true
            }
        }
        
        if ($failed) {
            Write-PortHelp -Ports $blockedPorts
            return $false
        }
        return $true
    }
    else {
        Write-Warn "Cannot continue with ports in use"
        Write-PortHelp -Ports $blockedPorts
        return $false
    }
}

