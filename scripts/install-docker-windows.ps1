# install-docker-windows.ps1 - Install Docker Desktop on Windows
# Part of workshop-bootstrap

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

. "$PSScriptRoot\utils.ps1"

function Install-DockerWindows {
    Write-Step "Installing Docker Desktop on Windows..."

    # Check if WinGet is available
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Info "Using WinGet to install Docker Desktop"
        
        try {
            winget install -e --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements
            Write-Success "Docker Desktop installed via WinGet"
            return $true
        }
        catch {
            Write-Warn "WinGet install failed: $_"
        }
    }

    # Fallback: Direct download
    Write-Warn "WinGet not available or failed. Attempting direct download..."
    
    $installerUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
    $installerPath = "$env:TEMP\DockerDesktopInstaller.exe"
    
    Write-Info "Downloading Docker Desktop installer..."
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
    
    Write-Info "Running installer (this may take a few minutes)..."
    Start-Process -FilePath $installerPath -ArgumentList "install", "--quiet", "--accept-license" -Wait -NoNewWindow
    
    Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
    
    Write-Success "Docker Desktop installed"
    return $true
}

function Start-DockerWindows {
    param(
        [int]$TimeoutSec = 120
    )
    
    Write-Step "Starting Docker Desktop..."
    
    # Find Docker Desktop executable
    $dockerDesktopPaths = @(
        "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
        "$env:LOCALAPPDATA\Programs\Docker\Docker\Docker Desktop.exe"
    )
    
    $dockerDesktop = $null
    foreach ($path in $dockerDesktopPaths) {
        if (Test-Path $path) {
            $dockerDesktop = $path
            break
        }
    }
    
    if (-not $dockerDesktop) {
        Write-ErrorMsg "Docker Desktop executable not found"
        return $false
    }
    
    # Start Docker Desktop (if it's already running, this is harmless)
    Start-Process -FilePath $dockerDesktop
    
    # Wait for daemon to be ready
    # NOTE: We must set $ErrorActionPreference to "Continue" here because the
    # caller sets "Stop". With "Stop", `docker info 2>&1` can throw a terminating
    # error (stderr → ErrorRecord), preventing $LASTEXITCODE from being checked.
    Write-Info "Waiting for Docker daemon (timeout: ${TimeoutSec}s)..."
    $savedEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $elapsed = 0
    
    while ($elapsed -lt $TimeoutSec) {
        $null = docker info 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            $ErrorActionPreference = $savedEAP
            Write-Success "Docker daemon is ready"
            return $true
        }
        
        Start-Sleep -Seconds 3
        $elapsed += 3
        Write-Host "." -NoNewline
        
        # Show elapsed time every 15 seconds so the user knows it's working
        if ($elapsed % 15 -eq 0) {
            Write-Host " (${elapsed}s)" -NoNewline
        }
    }
    
    $ErrorActionPreference = $savedEAP
    Write-Host ""
    Write-ErrorMsg "Docker daemon did not start within $TimeoutSec seconds"
    Write-Info ""
    Write-Info "Docker Desktop may require first-run setup:"
    Write-Info "  1. Open Docker Desktop from the Start Menu"
    Write-Info "  2. Accept the license agreement"
    Write-Info "  3. Complete WSL2 setup if prompted"
    Write-Info "  4. Wait for Docker Desktop to show 'Engine running'"
    Write-Info "  5. Re-run this bootstrap script"
    Write-Info ""
    Write-Info "If Docker Desktop is already open, check its status icon"
    Write-Info "in the system tray -- it should show a green 'running' state."
    return $false
}

# Run if executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Install-DockerWindows
}

