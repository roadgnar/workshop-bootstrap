#!/usr/bin/env bash
#
# bootstrap-common.sh - Shared bootstrap logic for macOS and Linux
# Called by bootstrap-mac and bootstrap-linux entry points
#
# This script expects $OS to be set by the caller (macos or linux)

set -euo pipefail

# Ensure OS is set
if [[ -z "${OS:-}" ]]; then
    echo "Error: OS variable must be set before sourcing this script"
    exit 1
fi

# Script directory (caller should set this)
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$SCRIPT_DIR"

# Source utilities
source "${SCRIPT_DIR}/scripts/utils.sh"

# Source OS-specific installers
case "$OS" in
    macos)
        source "${SCRIPT_DIR}/scripts/install-docker-macos.sh"
        source "${SCRIPT_DIR}/scripts/install-cursor-macos.sh"
        START_DOCKER="start_docker_macos"
        OPEN_CURSOR="open_cursor_macos"
        DETECT_CURSOR="detect_cursor_macos"
        ;;
    linux)
        source "${SCRIPT_DIR}/scripts/install-docker-linux.sh"
        source "${SCRIPT_DIR}/scripts/install-cursor-linux.sh"
        START_DOCKER="start_docker_linux"
        OPEN_CURSOR="open_cursor_linux"
        DETECT_CURSOR="detect_cursor_linux"
        ;;
    *)
        log_error "Unsupported OS: $OS"
        exit 1
        ;;
esac

# Default configuration
PORT="${PORT:-8080}"
TIMEOUT="${TIMEOUT:-120}"
REINSTALL_DOCKER=false
REINSTALL_CURSOR=false
NO_OPEN=false

# Parse command line arguments
parse_bootstrap_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --reinstall-docker)
                REINSTALL_DOCKER=true
                shift
                ;;
            --reinstall-cursor)
                REINSTALL_CURSOR=true
                shift
                ;;
            --port)
                PORT="$2"
                shift 2
                ;;
            --no-open)
                NO_OPEN=true
                shift
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --help|-h)
                show_bootstrap_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_bootstrap_help
                exit 1
                ;;
        esac
    done
}

show_bootstrap_help() {
    cat << EOF
Workshop Bootstrap - Developer Environment Setup

Usage: ./bootstrap [OPTIONS]

Options:
  --reinstall-docker   Force reinstall Docker even if present
  --reinstall-cursor   Force reinstall Cursor even if present
  --port PORT          Port for demo website (default: 8080)
  --no-open            Don't open Cursor after setup
  --timeout SECONDS    Timeout for Docker startup (default: 120)
  --help               Show this help message

Examples:
  ./bootstrap                    # Standard setup
  ./bootstrap --port 3000        # Use port 3000 for demo
  ./bootstrap --no-open          # Skip opening Cursor
EOF
}

# Step 1: Check and install Docker
setup_docker() {
    log_step "Checking Docker installation..."
    
    if docker_installed && ! $REINSTALL_DOCKER; then
        log_success "Docker is installed"
        docker --version | head -1 | sed 's/^/    /'
    else
        if $REINSTALL_DOCKER; then
            log_info "Reinstalling Docker as requested..."
        else
            log_info "Docker not found, installing..."
        fi
        
        case "$OS" in
            macos) install_docker_macos ;;
            linux) install_docker_linux ;;
        esac
    fi
    
    # Check Docker Compose
    if compose_available; then
        log_success "Docker Compose is available"
        docker compose version | head -1 | sed 's/^/    /'
    else
        log_error "Docker Compose not available"
        log_info "Please ensure Docker Compose plugin is installed"
        exit 1
    fi
}

# Step 2: Ensure Docker daemon is running
ensure_docker_running() {
    log_step "Checking Docker daemon..."
    
    if docker_running; then
        log_success "Docker daemon is running"
        return 0
    fi
    
    log_info "Docker daemon not running, starting..."
    $START_DOCKER "$TIMEOUT" || {
        log_error "Failed to start Docker daemon"
        log_info ""
        log_info "Please start Docker manually and re-run this script"
        exit 1
    }
}

# Step 3: Check and install Cursor
setup_cursor() {
    log_step "Checking Cursor installation..."
    
    if $DETECT_CURSOR && ! $REINSTALL_CURSOR; then
        log_success "Cursor is installed"
        if command_exists cursor; then
            cursor --version 2>/dev/null | head -1 | sed 's/^/    /' || true
        fi
    else
        if $REINSTALL_CURSOR; then
            log_info "Reinstalling Cursor as requested..."
        else
            log_info "Cursor not found, installing..."
        fi
        
        case "$OS" in
            macos)
                install_cursor_macos
                setup_cursor_cli_macos
                ;;
            linux)
                install_cursor_linux
                ;;
        esac
    fi
}

# Step 4: Build and start containers
setup_containers() {
    log_step "Setting up Docker containers..."
    
    # Export port for docker-compose
    export PORT
    export BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    export VERSION="1.0.0"
    
    # Build container
    log_info "Building development container..."
    docker compose build dev
    
    # Start container
    log_info "Starting development container..."
    docker compose up -d dev
    
    log_success "Container is running"
}

# Step 5: Start demo web service
start_demo() {
    log_step "Starting demo web service..."
    
    # Run demo in the dev container
    docker compose exec -d dev bash -c "cd /workspace/demo-site && python app.py"
    
    # Wait for service to be ready
    log_info "Waiting for demo service to be ready..."
    local elapsed=0
    local max_wait=30
    
    while ! check_url "http://localhost:${PORT}/health"; do
        if [[ $elapsed -ge $max_wait ]]; then
            log_warn "Demo service took longer than expected to start"
            log_info "It may still be starting up..."
            break
        fi
        sleep 1
        elapsed=$((elapsed + 1))
        printf "."
    done
    echo ""
    
    if check_url "http://localhost:${PORT}/health"; then
        log_success "Demo service is running"
    fi
}

# Step 6: Open Cursor
open_editor() {
    if $NO_OPEN; then
        log_info "Skipping Cursor launch (--no-open specified)"
        return 0
    fi
    
    log_step "Opening Cursor..."
    
    $OPEN_CURSOR "$SCRIPT_DIR" || {
        log_warn "Could not open Cursor automatically"
        log_info "Please open Cursor manually and open this folder: $SCRIPT_DIR"
    }
}

# Print final summary
print_summary() {
    print_separator
    echo ""
    log_success "Bootstrap complete!"
    echo ""
    echo -e "    ${BOLD}Demo website:${NC}  http://localhost:${PORT}"
    echo -e "    ${BOLD}Health check:${NC}  http://localhost:${PORT}/health"
    echo -e "    ${BOLD}API info:${NC}      http://localhost:${PORT}/api/info"
    echo ""
    echo -e "    ${BOLD}Useful commands:${NC}"
    echo "      ./dev up       - Start containers"
    echo "      ./dev down     - Stop containers"
    echo "      ./dev shell    - Open shell in container"
    echo "      ./dev logs     - View container logs"
    echo ""
    print_separator
}

# Main bootstrap execution
run_bootstrap() {
    print_banner
    parse_bootstrap_args "$@"
    
    log_info "Operating system: $OS"
    log_info "Demo port: $PORT"
    log_info "Startup timeout: ${TIMEOUT}s"
    
    setup_docker
    ensure_docker_running
    setup_cursor
    setup_containers
    start_demo
    open_editor
    print_summary
}

