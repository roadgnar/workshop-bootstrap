# install-cursor-windows.ps1 - Install Cursor IDE on Windows
# Part of workshop-bootstrap

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

. "$PSScriptRoot\utils.ps1"

function Test-CursorInstalled {
    # Check CLI in PATH
    if (Get-Command cursor -ErrorAction SilentlyContinue) {
        return $true
    }
    
    # Check common install locations
    $cursorPaths = @(
        "$env:LOCALAPPDATA\Programs\cursor\Cursor.exe",
        "$env:ProgramFiles\Cursor\Cursor.exe",
        "$env:USERPROFILE\AppData\Local\Programs\cursor\Cursor.exe"
    )
    
    foreach ($path in $cursorPaths) {
        if (Test-Path $path) {
            return $true
        }
    }
    
    return $false
}

function Install-CursorWindows {
    Write-Step "Installing Cursor IDE on Windows..."

    # Check if WinGet is available
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Info "Using WinGet to install Cursor"
        
        try {
            winget install -e --id Cursor.Cursor --accept-source-agreements --accept-package-agreements
            Write-Success "Cursor installed via WinGet"
            return $true
        }
        catch {
            Write-Warn "WinGet install failed: $_"
        }
    }

    # Fallback: Direct download
    Write-Warn "WinGet not available or failed. Attempting direct download..."
    
    $installerUrl = "https://downloader.cursor.sh/windows/stable/latest"
    $installerPath = "$env:TEMP\CursorSetup.exe"
    
    Write-Info "Downloading Cursor installer..."
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
    
    Write-Info "Running installer..."
    Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait -NoNewWindow
    
    Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
    
    Write-Success "Cursor installed"
    return $true
}

function Get-CursorPath {
    # Check common install locations
    $cursorPaths = @(
        "$env:LOCALAPPDATA\Programs\cursor\Cursor.exe",
        "$env:ProgramFiles\Cursor\Cursor.exe",
        "$env:USERPROFILE\AppData\Local\Programs\cursor\Cursor.exe"
    )
    
    foreach ($path in $cursorPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    # Try to find via where
    try {
        $cursor = (Get-Command cursor -ErrorAction SilentlyContinue).Source
        if ($cursor) { return $cursor }
    }
    catch {}
    
    return $null
}

function Open-CursorWindows {
    param(
        [string]$Workspace = "."
    )
    
    Write-Step "Opening Cursor..."
    
    # Try CLI first
    if (Get-Command cursor -ErrorAction SilentlyContinue) {
        Start-Process cursor -ArgumentList $Workspace
        Write-Success "Cursor opened"
        return $true
    }
    
    # Try direct path
    $cursorPath = Get-CursorPath
    if ($cursorPath) {
        Start-Process $cursorPath -ArgumentList $Workspace
        Write-Success "Cursor opened"
        return $true
    }
    
    Write-Warn "Could not open Cursor automatically"
    Write-Info "Please open Cursor manually and open the workspace: $Workspace"
    return $false
}

# Run if executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Install-CursorWindows
}

