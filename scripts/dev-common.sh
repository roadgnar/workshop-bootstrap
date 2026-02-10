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
CONTAINER_NAME="workshop-dev"
SELECTED_REPO_FILE="${SCRIPT_DIR}/.selected-repo"

# Get/set selected repo
get_selected_repo() {
    if [[ -f "$SELECTED_REPO_FILE" ]]; then
        cat "$SELECTED_REPO_FILE"
    else
        echo ""
    fi
}

set_selected_repo() {
    echo "$1" > "$SELECTED_REPO_FILE"
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
    
    echo ""
    echo -e "${BOLD}Select a repository:${NC}"
    echo ""
    
    local i=1
    for repo in "${repos[@]}"; do
        local repo_path="${SCRIPT_DIR}/repos/${repo}"
        local desc=$(jq -r '.description // "No description"' "${repo_path}/repo.json" 2>/dev/null || echo "No description")
        echo -e "  ${BOLD}${i})${NC} ${GREEN}${repo}${NC} - ${desc}"
        ((i++))
    done
    echo ""
    
    local selection
    while true; do
        echo -n -e "${BOLD}Enter selection (1-${num_repos}): ${NC}"
        read -r selection
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le "$num_repos" ]]; then
            local selected="${repos[$((selection-1))]}"
            set_selected_repo "$selected"
            echo "$selected"
            return 0
        else
            log_error "Invalid selection. Please enter a number between 1 and ${num_repos}"
        fi
    done
}

show_dev_usage() {
    cat << EOF
Workshop Bootstrap - Development Helper

Usage: ./dev <command> [repo-name]

Commands:
  up          Start development container
  down        Stop all containers
  shell       Open interactive shell in container
  start       Start repo services (prompts for repo if not specified)
  stop        Stop repo services
  restart     Restart repo services
  logs        View service logs
  status      Show container and service status
  install     Install repo dependencies
  select      Select/change active repository
  build       Rebuild container image
  clean       Remove containers and images
  list        List available repositories

Examples:
  ./dev up                    # Start container
  ./dev start demo-site       # Start demo-site services
  ./dev start                 # Start services (prompts for repo)
  ./dev shell                 # Open bash in container
  ./dev logs                  # View logs for current repo
  ./dev select                # Change active repository
EOF
}

container_running() {
    docker compose ps --status running 2>/dev/null | grep -q "$CONTAINER_NAME"
}

ensure_container_running() {
    if ! container_running; then
        log_info "Container not running, starting it first..."
        cmd_up
        sleep 2
    fi
}

cmd_up() {
    log_step "Starting development container..."
    export BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    docker compose up -d dev
    log_success "Container started"
    docker compose ps
}

cmd_down() {
    log_step "Stopping containers..."
    docker compose down
    log_success "Containers stopped"
}

cmd_shell() {
    log_step "Opening shell in container..."
    ensure_container_running
    docker compose exec dev bash
}

cmd_start() {
    local repo="${1:-$(get_selected_repo)}"
    
    if [[ -z "$repo" ]]; then
        repo=$(select_repo_interactive)
    fi
    
    set_selected_repo "$repo"
    ensure_container_running
    
    log_step "Starting ${repo} services..."
    docker compose exec dev bash -c "/workspace/scripts/start-repo.sh ${repo} start"
}

cmd_stop() {
    local repo="${1:-$(get_selected_repo)}"
    
    if [[ -z "$repo" ]]; then
        log_error "No repository selected. Use: ./dev stop <repo-name>"
        exit 1
    fi
    
    ensure_container_running
    
    log_step "Stopping ${repo} services..."
    docker compose exec dev bash -c "/workspace/scripts/start-repo.sh ${repo} stop"
}

cmd_restart() {
    local repo="${1:-$(get_selected_repo)}"
    
    if [[ -z "$repo" ]]; then
        repo=$(select_repo_interactive)
    fi
    
    set_selected_repo "$repo"
    ensure_container_running
    
    log_step "Restarting ${repo} services..."
    docker compose exec dev bash -c "/workspace/scripts/start-repo.sh ${repo} restart"
}

cmd_logs() {
    local repo="${1:-$(get_selected_repo)}"
    
    if [[ -z "$repo" ]]; then
        log_error "No repository selected. Use: ./dev logs <repo-name>"
        exit 1
    fi
    
    ensure_container_running
    
    log_step "Showing logs for ${repo}..."
    docker compose exec dev bash -c "/workspace/scripts/start-repo.sh ${repo} logs" || \
        docker compose logs -f dev
}

cmd_status() {
    log_step "Container status:"
    docker compose ps
    
    local repo="$(get_selected_repo)"
    if [[ -n "$repo" ]] && container_running; then
        echo ""
        echo -e "${BOLD}Active repository:${NC} ${repo}"
        docker compose exec dev bash -c "/workspace/scripts/start-repo.sh ${repo} status" 2>/dev/null || true
    fi
}

cmd_install() {
    local repo="${1:-$(get_selected_repo)}"
    
    if [[ -z "$repo" ]]; then
        repo=$(select_repo_interactive)
    fi
    
    set_selected_repo "$repo"
    ensure_container_running
    
    log_step "Installing dependencies for ${repo}..."
    docker compose exec dev bash -c "/workspace/scripts/start-repo.sh install ${repo}"
}

cmd_select() {
    local repo=$(select_repo_interactive)
    log_success "Selected repository: ${repo}"
    log_info "Use './dev start' to start services"
}

cmd_build() {
    log_step "Rebuilding container image..."
    export BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    docker compose build --no-cache dev
    log_success "Image rebuilt"
}

cmd_clean() {
    log_step "Cleaning up Docker resources..."
    
    log_info "Stopping containers..."
    docker compose down --volumes --remove-orphans 2>/dev/null || true
    
    log_info "Removing project images..."
    docker compose down --rmi local 2>/dev/null || true
    
    # Remove selected repo file
    rm -f "$SELECTED_REPO_FILE"
    
    log_success "Cleanup complete"
}

cmd_list() {
    echo ""
    echo -e "${BOLD}Available repositories:${NC}"
    echo ""
    
    for repo_dir in "${SCRIPT_DIR}/repos"/*/; do
        if [[ -f "${repo_dir}repo.json" ]]; then
            local name=$(basename "$repo_dir")
            local desc=$(jq -r '.description // "No description"' "${repo_dir}repo.json" 2>/dev/null || echo "No description")
            local current=""
            if [[ "$name" == "$(get_selected_repo)" ]]; then
                current=" ${GREEN}(active)${NC}"
            fi
            echo -e "  ${GREEN}${name}${NC}${current}"
            echo -e "    ${desc}"
            echo ""
        fi
    done
}

# Run dev command
run_dev_command() {
    local cmd="${1:-}"
    shift 2>/dev/null || true
    
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
        start)
            cmd_start "$@"
            ;;
        stop)
            cmd_stop "$@"
            ;;
        restart)
            cmd_restart "$@"
            ;;
        logs)
            cmd_logs "$@"
            ;;
        status)
            cmd_status
            ;;
        install)
            cmd_install "$@"
            ;;
        select)
            cmd_select
            ;;
        build)
            cmd_build
            ;;
        clean)
            cmd_clean
            ;;
        list)
            cmd_list
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
