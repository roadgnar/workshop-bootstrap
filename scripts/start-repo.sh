#!/usr/bin/env bash
#
# start-repo.sh - Generic repo starter
# Reads repo.json and calls the repo-specific scripts/start.sh
#
# Usage: ./start-repo.sh <repo-name> [start|stop|restart|status|logs]

set -euo pipefail

WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace}"
REPOS_DIR="${WORKSPACE_DIR}/repos"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# List available repos
list_repos() {
    echo ""
    echo -e "${BOLD}Available repositories:${NC}"
    echo ""
    
    for repo_dir in "$REPOS_DIR"/*/; do
        if [[ -f "${repo_dir}repo.json" ]]; then
            local name=$(jq -r '.name' "${repo_dir}repo.json")
            local desc=$(jq -r '.description' "${repo_dir}repo.json")
            echo -e "  ${GREEN}${name}${NC} - ${desc}"
        fi
    done
    echo ""
}

# Validate repo exists
validate_repo() {
    local repo="$1"
    local repo_path="${REPOS_DIR}/${repo}"
    
    if [[ ! -d "$repo_path" ]]; then
        log_error "Repository not found: $repo"
        list_repos
        exit 1
    fi
    
    if [[ ! -f "${repo_path}/repo.json" ]]; then
        log_error "No repo.json found in: $repo"
        exit 1
    fi
    
    if [[ ! -f "${repo_path}/scripts/start.sh" ]]; then
        log_error "No scripts/start.sh found in: $repo"
        exit 1
    fi
}

# Install dependencies for a repo
install_deps() {
    local repo="$1"
    local repo_path="${REPOS_DIR}/${repo}"
    local code_dir="${repo_path}/code"
    local stack=$(jq -r '.stack // "unknown"' "${repo_path}/repo.json")
    
    log_info "Installing dependencies for $repo (stack: $stack)..."
    
    case "$stack" in
        python)
            if [[ -f "${code_dir}/requirements.txt" ]]; then
                pip install -r "${code_dir}/requirements.txt"
            fi
            ;;
        node)
            if [[ -f "${code_dir}/package.json" ]]; then
                cd "$code_dir" && npm install
            fi
            ;;
        node+python|python+node)
            # Install both
            if [[ -f "${code_dir}/package.json" ]]; then
                cd "$code_dir" && npm install
            fi
            if [[ -f "${code_dir}/api/pyproject.toml" ]]; then
                # Use --all-packages to install all workspace packages including their deps
                cd "${code_dir}/api" && uv sync --all-packages
            elif [[ -f "${code_dir}/requirements.txt" ]]; then
                pip install -r "${code_dir}/requirements.txt"
            fi
            ;;
        *)
            log_warn "Unknown stack: $stack, skipping dependency installation"
            ;;
    esac
    
    log_success "Dependencies installed"
}

# Run repo start script
run_repo_script() {
    local repo="$1"
    local command="${2:-start}"
    shift 2 || true
    local extra_args="$*"
    
    local repo_path="${REPOS_DIR}/${repo}"
    local start_script="${repo_path}/scripts/start.sh"
    
    validate_repo "$repo"
    
    # Run the repo-specific start script
    bash "$start_script" "$command" $extra_args
}

# Show repo info
show_repo_info() {
    local repo="$1"
    local repo_path="${REPOS_DIR}/${repo}"
    
    validate_repo "$repo"
    
    local name=$(jq -r '.name' "${repo_path}/repo.json")
    local desc=$(jq -r '.description' "${repo_path}/repo.json")
    local stack=$(jq -r '.stack // "unknown"' "${repo_path}/repo.json")
    
    echo ""
    echo -e "${BOLD}Repository: ${GREEN}${name}${NC}"
    echo -e "Description: ${desc}"
    echo -e "Stack: ${stack}"
    echo ""
    echo -e "${BOLD}URLs:${NC}"
    jq -r '.urls | to_entries[] | "  \(.key): \(.value)"' "${repo_path}/repo.json"
    echo ""
}

# Main
case "${1:-}" in
    list)
        list_repos
        ;;
    info)
        show_repo_info "${2:-}"
        ;;
    install)
        validate_repo "${2:-}"
        install_deps "${2:-}"
        ;;
    "")
        log_error "No command specified"
        echo ""
        echo "Usage: $0 <repo-name> [start|stop|restart|status|logs]"
        echo "       $0 list"
        echo "       $0 info <repo-name>"
        echo "       $0 install <repo-name>"
        list_repos
        exit 1
        ;;
    *)
        run_repo_script "$@"
        ;;
esac
