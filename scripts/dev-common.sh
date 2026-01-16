#!/usr/bin/env bash
#
# dev-common.sh - Shared dev helper logic for macOS and Linux
# Called by dev-mac and dev-linux entry points
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

# Default configuration
PORT="${PORT:-8080}"
CONTAINER_NAME="workshop-dev"

show_dev_usage() {
    cat << EOF
Workshop Bootstrap - Development Helper

Usage: ./dev <command>

Commands:
  up        Start development container
  down      Stop all containers
  shell     Open interactive shell in container
  logs      View container logs (follow mode)
  restart   Restart containers
  demo      Start/restart the demo web service
  build     Rebuild container image
  status    Show container status
  clean     Remove containers and images

Examples:
  ./dev up              # Start container
  ./dev shell           # Open bash in container
  ./dev logs            # Follow container logs
  ./dev demo            # Restart demo service
EOF
}

cmd_up() {
    log_step "Starting development container..."
    export PORT
    docker compose up -d dev
    log_success "Container started"
    
    # Show status
    docker compose ps
}

cmd_down() {
    log_step "Stopping containers..."
    docker compose down
    log_success "Containers stopped"
}

cmd_shell() {
    log_step "Opening shell in container..."
    
    if ! docker compose ps --status running | grep -q "$CONTAINER_NAME"; then
        log_info "Container not running, starting it first..."
        cmd_up
    fi
    
    docker compose exec dev bash
}

cmd_logs() {
    log_step "Showing container logs (Ctrl+C to exit)..."
    docker compose logs -f dev
}

cmd_restart() {
    log_step "Restarting containers..."
    docker compose restart dev
    log_success "Containers restarted"
}

cmd_demo() {
    log_step "Starting demo web service..."
    
    if ! docker compose ps --status running | grep -q "$CONTAINER_NAME"; then
        log_info "Container not running, starting it first..."
        cmd_up
    fi
    
    # Kill any existing demo process
    docker compose exec dev pkill -f "python app.py" 2>/dev/null || true
    
    # Start demo
    docker compose exec -d dev bash -c "cd /workspace/demo-site && python app.py"
    
    # Wait for service
    log_info "Waiting for demo service..."
    sleep 2
    
    if check_url "http://localhost:${PORT}/health"; then
        log_success "Demo service is running at http://localhost:${PORT}"
    else
        log_warn "Demo service may still be starting..."
        log_info "Check with: ./dev logs"
    fi
}

cmd_build() {
    log_step "Rebuilding container image..."
    export PORT
    export BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    docker compose build --no-cache dev
    log_success "Image rebuilt"
}

cmd_status() {
    log_step "Container status:"
    docker compose ps
    
    echo ""
    log_info "Docker resources:"
    docker system df 2>/dev/null || true
}

cmd_clean() {
    log_step "Cleaning up Docker resources..."
    
    log_info "Stopping containers..."
    docker compose down --volumes --remove-orphans 2>/dev/null || true
    
    log_info "Removing project images..."
    docker compose down --rmi local 2>/dev/null || true
    
    log_success "Cleanup complete"
}

# Run dev command
run_dev_command() {
    local cmd="${1:-}"
    
    case "$cmd" in
        up)
            cmd_up
            ;;
        down)
            cmd_down
            ;;
        shell)
            cmd_shell
            ;;
        logs)
            cmd_logs
            ;;
        restart)
            cmd_restart
            ;;
        demo)
            cmd_demo
            ;;
        build)
            cmd_build
            ;;
        status)
            cmd_status
            ;;
        clean)
            cmd_clean
            ;;
        help|--help|-h)
            show_dev_usage
            ;;
        "")
            log_error "No command specified"
            echo ""
            show_dev_usage
            exit 1
            ;;
        *)
            log_error "Unknown command: $cmd"
            echo ""
            show_dev_usage
            exit 1
            ;;
    esac
}

