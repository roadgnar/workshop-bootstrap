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
TIMEOUT="${TIMEOUT:-120}"
REINSTALL_DOCKER=false
REINSTALL_CURSOR=false
NO_OPEN=false
FORCE_PORTS=false
SELECTED_REPO=""

# Default ports to check
DEFAULT_PORTS="8080 5173 8000 3000"

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
            --repo)
                SELECTED_REPO="$2"
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
            --force-ports)
                FORCE_PORTS=true
                shift
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
  --repo NAME          Select repository to run (skip interactive selection)
  --force-ports        Auto-kill processes using required ports (no prompt)
  --reinstall-docker   Force reinstall Docker even if present
  --reinstall-cursor   Force reinstall Cursor even if present
  --no-open            Don't open Cursor after setup
  --timeout SECONDS    Timeout for Docker startup (default: 120)
  --help               Show this help message

Examples:
  ./bootstrap                       # Interactive repo selection
  ./bootstrap --repo demo-site      # Run demo-site directly
  ./bootstrap --force-ports         # Auto-free blocked ports
  ./bootstrap --no-open             # Skip opening Cursor
EOF
}

# Get list of available repos
get_available_repos() {
    local repos=()
    for repo_dir in "${SCRIPT_DIR}/repos"/*/; do
        if [[ -f "${repo_dir}repo.json" ]]; then
            repos+=("$(basename "$repo_dir")")
        fi
    done
    printf '%s\n' "${repos[@]}"
}

# Interactive repo selection
select_repo_interactive() {
    local repos=()
    local IFS=$'\n'
    repos=( $(get_available_repos) )
    unset IFS
    local num_repos=${#repos[@]}
    
    if [[ $num_repos -eq 0 ]]; then
        log_error "No repositories found in repos/"
        exit 1
    fi
    
    print_separator
    echo ""
    echo -e "${BOLD}Select a repository to run:${NC}"
    echo ""
    
    local i=1
    for repo in "${repos[@]}"; do
        local repo_path="${SCRIPT_DIR}/repos/${repo}"
        local desc=$(jq -r '.description // "No description"' "${repo_path}/repo.json" 2>/dev/null || echo "No description")
        echo -e "  ${BOLD}${i})${NC} ${GREEN}${repo}${NC}"
        echo -e "     ${desc}"
        echo ""
        ((i++))
    done
    
    print_separator
    
    local selection
    while true; do
        echo -n -e "${BOLD}Enter selection (1-${num_repos}): ${NC}"
        read -r selection
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le "$num_repos" ]]; then
            SELECTED_REPO="${repos[$((selection-1))]}"
            break
        else
            log_error "Invalid selection. Please enter a number between 1 and ${num_repos}"
        fi
    done
    
    echo ""
    log_success "Selected: $SELECTED_REPO"
}

# Validate selected repo
validate_selected_repo() {
    local repo_path="${SCRIPT_DIR}/repos/${SELECTED_REPO}"
    
    if [[ ! -d "$repo_path" ]]; then
        log_error "Repository not found: $SELECTED_REPO"
        echo ""
        echo "Available repositories:"
        while IFS= read -r repo; do
            echo "  - $repo"
        done < <(get_available_repos)
        exit 1
    fi
    
    if [[ ! -f "${repo_path}/repo.json" ]]; then
        log_error "No repo.json found in: $SELECTED_REPO"
        exit 1
    fi
    
    if [[ ! -f "${repo_path}/scripts/start.sh" ]]; then
        log_error "No scripts/start.sh found in: $SELECTED_REPO"
        exit 1
    fi
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
}

# Step 2: Ensure Docker daemon is running
ensure_docker_running() {
    log_step "Checking Docker daemon..."
    
    if docker_running; then
        log_success "Docker daemon is running"
    else
        log_info "Docker daemon not running, starting..."
        $START_DOCKER "$TIMEOUT" || {
            log_error "Failed to start Docker daemon"
            log_info ""
            log_info "Please start Docker manually and re-run this script"
            exit 1
        }
    fi
    
    # Check Docker Compose (must be after daemon is running)
    if compose_available; then
        log_success "Docker Compose is available"
        docker compose version | head -1 | sed 's/^/    /'
    else
        log_error "Docker Compose not available"
        log_info "Please ensure Docker Compose plugin is installed"
        exit 1
    fi
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

# Step 4: Check required ports
check_required_ports() {
    log_step "Checking required ports..."
    
    # Get ports from repo.json if available, otherwise use defaults
    local ports="$DEFAULT_PORTS"
    
    if [[ -n "$SELECTED_REPO" ]]; then
        local repo_json="${SCRIPT_DIR}/repos/${SELECTED_REPO}/repo.json"
        if [[ -f "$repo_json" ]]; then
            local repo_ports=$(jq -r '.ports // [] | .[]' "$repo_json" 2>/dev/null | tr '\n' ' ')
            if [[ -n "$repo_ports" ]]; then
                ports="$repo_ports"
            fi
        fi
    fi
    
    log_info "Checking ports: $ports"
    
    local force_flag=""
    if $FORCE_PORTS; then
        force_flag="--force"
    fi
    
    if ! check_and_free_ports "$ports" "$force_flag"; then
        exit 1
    fi
    
    log_success "All required ports are available"
}

# Step 5: Build and start containers
setup_containers() {
    log_step "Setting up Docker containers..."
    
    export BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    export VERSION="1.0.0"
    export SELECTED_REPO
    
    # Build container
    log_info "Building development container..."
    docker compose build dev
    
    # Start container
    log_info "Starting development container..."
    docker compose up -d dev
    
    log_success "Container is running"
}

# Step 5: Install dependencies and start services
start_repo_services() {
    local repo_path="${SCRIPT_DIR}/repos/${SELECTED_REPO}"
    local repo_json="${repo_path}/repo.json"
    local healthcheck=$(jq -r '.healthcheck // ""' "$repo_json")
    
    log_step "Starting ${SELECTED_REPO} services..."
    
    # Install dependencies inside container
    log_info "Installing dependencies..."
    docker compose exec dev bash -c "/workspace/scripts/start-repo.sh install ${SELECTED_REPO}" || {
        log_warn "Dependency installation had issues, continuing..."
    }
    
    # Start services
    log_info "Starting services..."
    docker compose exec -d dev bash -c "/workspace/scripts/start-repo.sh ${SELECTED_REPO} start"
    
    # Wait for health check
    if [[ -n "$healthcheck" ]]; then
        log_info "Waiting for services to be ready..."
        local elapsed=0
        local max_wait=60
        
        while ! check_url "$healthcheck"; do
            if [[ $elapsed -ge $max_wait ]]; then
                log_warn "Services took longer than expected to start"
                log_info "They may still be starting up..."
                log_info "Check logs with: ./dev logs"
                break
            fi
            sleep 2
            elapsed=$((elapsed + 2))
            printf "."
        done
        echo ""
        
        if check_url "$healthcheck"; then
            log_success "Services are running"
        fi
    else
        sleep 3
        log_success "Services started"
    fi
}

# Step 6: Open Cursor
open_editor() {
    if $NO_OPEN; then
        log_info "Skipping Cursor launch (--no-open specified)"
        return 0
    fi
    
    log_step "Opening Cursor..."
    
    # Open Cursor to the selected repo's code folder
    local repo_code_path="${SCRIPT_DIR}/repos/${SELECTED_REPO}/code"
    
    if [[ -d "$repo_code_path" ]]; then
        $OPEN_CURSOR "$repo_code_path" || {
            log_warn "Could not open Cursor automatically"
            log_info "Please open Cursor manually and open this folder: $repo_code_path"
        }
    else
        # Fallback to root if code folder doesn't exist
        $OPEN_CURSOR "$SCRIPT_DIR" || {
            log_warn "Could not open Cursor automatically"
            log_info "Please open Cursor manually and open this folder: $SCRIPT_DIR"
        }
    fi
}

# Print final summary
print_summary() {
    local repo_path="${SCRIPT_DIR}/repos/${SELECTED_REPO}"
    local repo_code_path="${repo_path}/code"
    local repo_json="${repo_path}/repo.json"
    
    print_separator
    echo ""
    log_success "Bootstrap complete!"
    echo ""
    echo -e "    ${BOLD}Repository:${NC} ${SELECTED_REPO}"
    echo -e "    ${BOLD}Code folder:${NC} repos/${SELECTED_REPO}/code"
    echo ""
    echo -e "    ${BOLD}URLs:${NC}"
    jq -r '.urls | to_entries[] | "      \(.key): \(.value)"' "$repo_json" 2>/dev/null || true
    echo ""
    echo -e "    ${BOLD}Useful commands:${NC}"
    echo "      ./dev up       - Start container"
    echo "      ./dev down     - Stop containers"
    echo "      ./dev shell    - Open shell in container"
    echo "      ./dev start    - Start repo services"
    echo "      ./dev stop     - Stop repo services"
    echo "      ./dev logs     - View service logs"
    echo "      ./dev status   - Show service status"
    echo ""
    print_separator
}

# Main bootstrap execution
run_bootstrap() {
    print_banner
    parse_bootstrap_args "$@"
    
    log_info "Operating system: $OS"
    log_info "Startup timeout: ${TIMEOUT}s"
    
    # Select repo if not specified
    if [[ -z "$SELECTED_REPO" ]]; then
        select_repo_interactive
    else
        validate_selected_repo
        log_info "Selected repository: $SELECTED_REPO"
    fi
    
    setup_docker
    ensure_docker_running
    setup_cursor
    check_required_ports
    setup_containers
    start_repo_services
    open_editor
    print_summary
}
