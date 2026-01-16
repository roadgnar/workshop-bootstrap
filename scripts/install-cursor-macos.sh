#!/usr/bin/env bash
# install-cursor-macos.sh - Install Cursor IDE on macOS
# Part of workshop-bootstrap

set -euo pipefail

_INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_INSTALLER_DIR}/utils.sh"

detect_cursor_macos() {
    # Check CLI
    if command -v cursor &>/dev/null; then
        return 0
    fi
    
    # Check application
    if [[ -d "/Applications/Cursor.app" ]]; then
        return 0
    fi
    
    # Check user applications
    if [[ -d "$HOME/Applications/Cursor.app" ]]; then
        return 0
    fi
    
    return 1
}

install_cursor_macos() {
    log_step "Installing Cursor IDE on macOS..."

    # Check if Homebrew is available
    if command -v brew &>/dev/null; then
        log_info "Using Homebrew to install Cursor"
        
        if brew list --cask cursor &>/dev/null; then
            log_info "Cursor cask already installed"
        else
            brew install --cask cursor
        fi
        
        log_success "Cursor installed via Homebrew"
        return 0
    fi

    # Fallback: Direct download
    log_warn "Homebrew not found. Attempting direct download..."
    
    # Detect architecture
    ARCH=$(uname -m)
    if [[ "$ARCH" == "arm64" ]]; then
        DMG_URL="https://downloader.cursor.sh/arm64/darwin/stable/latest"
    else
        DMG_URL="https://downloader.cursor.sh/darwin/stable/latest"
    fi

    TEMP_DMG="/tmp/Cursor.dmg"
    
    log_info "Downloading Cursor for ${ARCH}..."
    curl -fSL -o "$TEMP_DMG" "$DMG_URL"
    
    log_info "Mounting DMG..."
    hdiutil attach "$TEMP_DMG" -nobrowse -quiet
    
    # Find the mounted volume (name may vary)
    MOUNT_POINT=$(ls -d /Volumes/Cursor* 2>/dev/null | head -1)
    if [[ -z "$MOUNT_POINT" ]]; then
        log_error "Could not find mounted Cursor volume"
        return 1
    fi
    
    log_info "Installing Cursor.app..."
    cp -R "${MOUNT_POINT}/Cursor.app" /Applications/
    
    log_info "Unmounting DMG..."
    hdiutil detach "$MOUNT_POINT" -quiet
    rm -f "$TEMP_DMG"
    
    log_success "Cursor installed to /Applications"
    return 0
}

setup_cursor_cli_macos() {
    log_step "Setting up Cursor CLI..."
    
    # The CLI is usually available after first launch
    # Try to find it in common locations
    local cli_paths=(
        "/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
        "$HOME/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
    )
    
    for cli_path in "${cli_paths[@]}"; do
        if [[ -x "$cli_path" ]]; then
            # Create symlink in /usr/local/bin if not exists
            if [[ ! -L "/usr/local/bin/cursor" ]] && [[ ! -f "/usr/local/bin/cursor" ]]; then
                sudo mkdir -p /usr/local/bin
                sudo ln -sf "$cli_path" /usr/local/bin/cursor
                log_success "Cursor CLI linked to /usr/local/bin/cursor"
            fi
            return 0
        fi
    done
    
    log_info "Cursor CLI will be available after first launch"
    log_info "You can install it from Cursor: Cmd+Shift+P > 'Install cursor command'"
    return 0
}

open_cursor_macos() {
    local workspace="${1:-.}"
    
    log_step "Opening Cursor..."
    
    if command -v cursor &>/dev/null; then
        cursor "$workspace"
    elif [[ -d "/Applications/Cursor.app" ]]; then
        open -a Cursor "$workspace"
    elif [[ -d "$HOME/Applications/Cursor.app" ]]; then
        open -a "$HOME/Applications/Cursor.app" "$workspace"
    else
        log_warn "Could not open Cursor automatically"
        return 1
    fi
    
    log_success "Cursor opened"
    return 0
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_cursor_macos
    setup_cursor_cli_macos
fi

