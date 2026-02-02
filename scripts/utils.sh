#!/usr/bin/env bash
# utils.sh - Shared utility functions for bootstrap scripts
# Part of workshop-bootstrap

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Logging functions
log_step() {
    echo -e "\n${BOLD}${BLUE}==>${NC} ${BOLD}$1${NC}"
}

log_info() {
    echo -e "    ${CYAN}ℹ${NC} $1"
}

log_success() {
    echo -e "    ${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "    ${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "    ${RED}✗${NC} $1" >&2
}

# Print a horizontal line
print_separator() {
    echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"
}

# Print banner
print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║           Workshop Bootstrap Environment              ║"
    echo "║       Docker + Cursor + Demo Web Application          ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Darwin*)
            echo "macos"
            ;;
        Linux*)
            echo "linux"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Check if command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Check if Docker is installed
docker_installed() {
    command_exists docker
}

# Check if Docker daemon is running
docker_running() {
    docker info &>/dev/null 2>&1
}

# Check if Docker Compose is available
# Checks both plugin style (docker compose) and standalone (docker-compose)
compose_available() {
    docker compose version &>/dev/null 2>&1 || docker-compose --version &>/dev/null 2>&1
}

# Check if Cursor is installed (basic check)
cursor_installed() {
    if command_exists cursor; then
        return 0
    fi
    
    # OS-specific checks
    local os=$(detect_os)
    case "$os" in
        macos)
            [[ -d "/Applications/Cursor.app" ]] || [[ -d "$HOME/Applications/Cursor.app" ]]
            ;;
        linux)
            [[ -x "$HOME/.local/bin/cursor" ]] || [[ -x "/opt/cursor/cursor" ]]
            ;;
        *)
            return 1
            ;;
    esac
}

# Wait for a condition with timeout
# shellcheck disable=SC2091
wait_for() {
    local condition="$1"
    local timeout="${2:-60}"
    local interval="${3:-2}"
    local elapsed=0
    
    while ! eval "$condition"; do
        if [[ $elapsed -ge $timeout ]]; then
            return 1
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
        printf "."
    done
    echo ""
    return 0
}

# Check URL is reachable
check_url() {
    local url="$1"
    local timeout="${2:-5}"
    
    if command_exists curl; then
        curl -sf --max-time "$timeout" "$url" &>/dev/null
    elif command_exists wget; then
        wget -q --timeout="$timeout" -O /dev/null "$url" &>/dev/null
    else
        return 1
    fi
}

# Get local IP address
get_local_ip() {
    if command_exists ip; then
        ip route get 1 2>/dev/null | awk '{print $7; exit}'
    elif command_exists ifconfig; then
        ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1 | awk '{print $2}'
    else
        echo "localhost"
    fi
}

# Ensure script is not run as root (unless necessary)
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warn "Running as root is not recommended"
        log_info "Some operations will use sudo when needed"
    fi
}

# Parse command line arguments (generic)
parse_args() {
    # Override in main script
    :
}

# =============================================================================
# Port Management Functions
# =============================================================================

# Get process using a specific port
get_port_process() {
    local port="$1"
    
    if command_exists lsof; then
        lsof -i ":$port" -sTCP:LISTEN -t 2>/dev/null
    elif command_exists ss; then
        ss -tlnp "sport = :$port" 2>/dev/null | grep -oP 'pid=\K[0-9]+' | head -1
    elif command_exists netstat; then
        netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f1 | head -1
    else
        return 1
    fi
}

# Get process name for a PID
get_process_name() {
    local pid="$1"
    
    if [[ -z "$pid" ]]; then
        return 1
    fi
    
    if command_exists ps; then
        ps -p "$pid" -o comm= 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

# Check if a port is in use
port_in_use() {
    local port="$1"
    local pid
    pid=$(get_port_process "$port")
    [[ -n "$pid" ]]
}

# Kill process using a port
kill_port_process() {
    local port="$1"
    local pid
    pid=$(get_port_process "$port")
    
    if [[ -n "$pid" ]]; then
        kill "$pid" 2>/dev/null || sudo kill "$pid" 2>/dev/null || {
            log_warn "Could not kill process $pid, trying SIGKILL..."
            kill -9 "$pid" 2>/dev/null || sudo kill -9 "$pid" 2>/dev/null
        }
        sleep 1
        return 0
    fi
    return 1
}

# Check ports and optionally free them
# Usage: check_and_free_ports "8080 5173 8000" [--force]
check_and_free_ports() {
    local ports="$1"
    local force="${2:-false}"
    local blocked_ports=()
    local port_info=()
    
    # Check which ports are in use
    for port in $ports; do
        if port_in_use "$port"; then
            local pid=$(get_port_process "$port")
            local name=$(get_process_name "$pid")
            blocked_ports+=("$port")
            port_info+=("$port (PID: $pid, Process: $name)")
        fi
    done
    
    # If no ports blocked, we're good
    if [[ ${#blocked_ports[@]} -eq 0 ]]; then
        return 0
    fi
    
    log_warn "The following ports are already in use:"
    for info in "${port_info[@]}"; do
        log_info "  - Port $info"
    done
    echo ""
    
    # If force flag is set, kill without asking
    if [[ "$force" == "true" ]] || [[ "$force" == "--force" ]]; then
        log_info "Stopping processes on blocked ports (--force-ports specified)..."
        for port in "${blocked_ports[@]}"; do
            if kill_port_process "$port"; then
                log_success "Freed port $port"
            else
                log_error "Failed to free port $port"
                return 1
            fi
        done
        return 0
    fi
    
    # Ask user for confirmation
    echo -n -e "    ${YELLOW}?${NC} Stop these processes to continue? [y/N]: "
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        for port in "${blocked_ports[@]}"; do
            if kill_port_process "$port"; then
                log_success "Freed port $port"
            else
                log_error "Failed to free port $port"
                return 1
            fi
        done
        return 0
    else
        log_error "Cannot continue with ports in use"
        log_info "Use --force-ports to automatically stop conflicting processes"
        return 1
    fi
}

