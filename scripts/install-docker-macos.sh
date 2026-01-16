#!/usr/bin/env bash
# install-docker-macos.sh - Install Docker Desktop on macOS
# Part of workshop-bootstrap

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

install_docker_macos() {
    log_step "Installing Docker Desktop on macOS..."

    # Check if Homebrew is available
    if command -v brew &>/dev/null; then
        log_info "Using Homebrew to install Docker Desktop"
        
        # Install Docker Desktop via cask
        if brew list --cask docker &>/dev/null; then
            log_info "Docker Desktop cask already installed"
        else
            brew install --cask docker
        fi
        
        log_success "Docker Desktop installed via Homebrew"
        return 0
    fi

    # Fallback: Direct download
    log_warn "Homebrew not found. Attempting direct download..."
    
    # Detect architecture
    ARCH=$(uname -m)
    if [[ "$ARCH" == "arm64" ]]; then
        DMG_URL="https://desktop.docker.com/mac/main/arm64/Docker.dmg"
    else
        DMG_URL="https://desktop.docker.com/mac/main/amd64/Docker.dmg"
    fi

    TEMP_DMG="/tmp/Docker.dmg"
    
    log_info "Downloading Docker Desktop for ${ARCH}..."
    curl -fSL -o "$TEMP_DMG" "$DMG_URL"
    
    log_info "Mounting DMG..."
    hdiutil attach "$TEMP_DMG" -nobrowse -quiet
    
    log_info "Installing Docker.app..."
    cp -R "/Volumes/Docker/Docker.app" /Applications/
    
    log_info "Unmounting DMG..."
    hdiutil detach "/Volumes/Docker" -quiet
    rm -f "$TEMP_DMG"
    
    log_success "Docker Desktop installed to /Applications"
    return 0
}

start_docker_macos() {
    local timeout="${1:-120}"
    
    log_step "Starting Docker Desktop..."
    
    # Launch Docker Desktop
    if [[ -d "/Applications/Docker.app" ]]; then
        open -a Docker
    else
        log_error "Docker.app not found in /Applications"
        return 1
    fi
    
    # Wait for daemon to be ready
    log_info "Waiting for Docker daemon (timeout: ${timeout}s)..."
    local elapsed=0
    while ! docker info &>/dev/null; do
        if [[ $elapsed -ge $timeout ]]; then
            log_error "Docker daemon did not start within ${timeout} seconds"
            log_info ""
            log_info "Docker Desktop may require first-run setup:"
            log_info "  1. Open Docker Desktop from Applications"
            log_info "  2. Accept the license agreement"
            log_info "  3. Complete any required permissions prompts"
            log_info "  4. Re-run this bootstrap script"
            return 1
        fi
        sleep 2
        elapsed=$((elapsed + 2))
        printf "."
    done
    echo ""
    
    log_success "Docker daemon is ready"
    return 0
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_docker_macos
fi

