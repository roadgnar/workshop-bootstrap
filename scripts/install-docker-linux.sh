#!/usr/bin/env bash
# install-docker-linux.sh - Install Docker Engine on Linux
# Part of workshop-bootstrap

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

install_docker_linux() {
    log_step "Installing Docker Engine on Linux..."

    # Detect distribution
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO="$ID"
    else
        log_error "Cannot detect Linux distribution"
        return 1
    fi

    case "$DISTRO" in
        ubuntu|debian|linuxmint|pop)
            install_docker_apt
            ;;
        fedora)
            install_docker_dnf
            ;;
        centos|rhel|rocky|almalinux)
            install_docker_yum
            ;;
        arch|manjaro)
            install_docker_pacman
            ;;
        *)
            log_warn "Unsupported distribution: $DISTRO"
            log_info "Attempting convenience script install..."
            install_docker_convenience_script
            ;;
    esac
}

install_docker_apt() {
    log_info "Installing Docker via apt (Debian/Ubuntu)..."
    
    # Remove old versions if present
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Install prerequisites
    sudo apt-get update
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # Add Docker's official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$ID/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Set up repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$ID \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    log_success "Docker Engine installed via apt"
}

install_docker_dnf() {
    log_info "Installing Docker via dnf (Fedora)..."
    
    sudo dnf -y install dnf-plugins-core
    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    log_success "Docker Engine installed via dnf"
}

install_docker_yum() {
    log_info "Installing Docker via yum (CentOS/RHEL)..."
    
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    log_success "Docker Engine installed via yum"
}

install_docker_pacman() {
    log_info "Installing Docker via pacman (Arch)..."
    
    sudo pacman -Sy --noconfirm docker docker-compose
    
    log_success "Docker Engine installed via pacman"
}

install_docker_convenience_script() {
    log_info "Installing Docker via convenience script..."
    
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh
    rm -f /tmp/get-docker.sh
    
    log_success "Docker Engine installed via convenience script"
}

configure_docker_user() {
    log_step "Configuring Docker for non-root usage..."
    
    # Add current user to docker group
    if ! groups "$USER" | grep -q docker; then
        sudo usermod -aG docker "$USER"
        log_info "Added $USER to docker group"
        log_warn "You may need to log out and back in for group changes to take effect"
        log_warn "Alternatively, run: newgrp docker"
    else
        log_info "User $USER already in docker group"
    fi
}

start_docker_linux() {
    local timeout="${1:-60}"
    
    log_step "Starting Docker service..."
    
    # Start and enable Docker service
    if command -v systemctl &>/dev/null; then
        sudo systemctl start docker
        sudo systemctl enable docker
    elif command -v service &>/dev/null; then
        sudo service docker start
    else
        log_error "Cannot determine service manager"
        return 1
    fi
    
    # Wait for daemon to be ready
    log_info "Waiting for Docker daemon (timeout: ${timeout}s)..."
    local elapsed=0
    while ! docker info &>/dev/null 2>&1; do
        if [[ $elapsed -ge $timeout ]]; then
            # Try with sudo as fallback
            if sudo docker info &>/dev/null 2>&1; then
                log_warn "Docker requires sudo. Adding user to docker group..."
                configure_docker_user
                log_success "Docker daemon is ready (requires sudo or re-login)"
                return 0
            fi
            log_error "Docker daemon did not start within ${timeout} seconds"
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
    install_docker_linux
    configure_docker_user
    start_docker_linux
fi

