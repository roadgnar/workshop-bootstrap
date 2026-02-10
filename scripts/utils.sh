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

# Check if a port is held by a Docker container
# Docker's docker-proxy runs as root and won't show in regular lsof
is_docker_port() {
    local port="$1"
    
    if ! docker_running; then
        return 1
    fi
    
    # Check if any Docker container has this port mapped
    docker ps --format '{{.Ports}}' 2>/dev/null | grep -q "0.0.0.0:${port}->" && return 0
    docker ps --format '{{.Ports}}' 2>/dev/null | grep -q ":::${port}->" && return 0
    return 1
}

# Get process using a specific port (runs with sudo fallback for root-owned processes)
get_port_process() {
    local port="$1"
    local pid=""
    
    if command_exists lsof; then
        # Try without sudo first
        pid=$(lsof -nP -iTCP:"$port" 2>/dev/null | grep -i listen | awk '{print $2}' | head -1)
        
        # Fallback: try any connection on the port
        if [[ -z "$pid" ]]; then
            pid=$(lsof -nP -i :"$port" -t 2>/dev/null | head -1)
        fi
        
        # Fallback: try with sudo (catches root-owned processes like docker-proxy)
        if [[ -z "$pid" ]]; then
            pid=$(sudo lsof -nP -iTCP:"$port" 2>/dev/null | grep -i listen | awk '{print $2}' | head -1)
        fi
    elif command_exists ss; then
        pid=$(ss -tlnp "sport = :$port" 2>/dev/null | grep -oP 'pid=\K[0-9]+' | head -1)
    elif command_exists netstat; then
        pid=$(netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f1 | head -1)
    fi
    
    echo "$pid"
}

# Get process name for a PID
get_process_name() {
    local pid="$1"
    
    if [[ -z "$pid" ]]; then
        echo "unknown"
        return 1
    fi
    
    if command_exists ps; then
        ps -p "$pid" -o comm= 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

# Check if a port is in use (checks both regular processes and Docker)
port_in_use() {
    local port="$1"
    
    # Quick check: can we bind to the port?
    if command_exists python3; then
        python3 -c "
import socket, sys
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
try:
    s.bind(('0.0.0.0', $port))
    s.close()
    sys.exit(1)
except OSError:
    sys.exit(0)
" 2>/dev/null && return 0
    fi
    
    # Fallback: check via process lookup
    local pid
    pid=$(get_port_process "$port")
    [[ -n "$pid" ]]
}

# Kill process using a port
kill_port_process() {
    local port="$1"
    
    # If Docker is holding the port, stop the container instead
    if is_docker_port "$port"; then
        log_info "Port $port is held by a Docker container, stopping containers..."
        docker compose down 2>/dev/null || docker stop $(docker ps -q) 2>/dev/null || true
        sleep 2
        # Re-check if port is now free
        if ! port_in_use "$port"; then
            return 0
        fi
        return 1
    fi
    
    local pid
    pid=$(get_port_process "$port")
    
    if [[ -n "$pid" ]]; then
        kill "$pid" 2>/dev/null || sudo kill "$pid" 2>/dev/null || {
            log_warn "Could not kill process $pid, trying SIGKILL..."
            kill -9 "$pid" 2>/dev/null || sudo kill -9 "$pid" 2>/dev/null
        }
        sleep 1
        # Verify port is actually free now
        if ! port_in_use "$port"; then
            return 0
        fi
        return 1
    fi
    
    # No PID found but port is in use (TIME_WAIT, etc.) -- try fuser as last resort
    if command_exists fuser; then
        sudo fuser -k "$port/tcp" 2>/dev/null || true
        sleep 1
        if ! port_in_use "$port"; then
            return 0
        fi
    fi
    
    return 1
}

# Print manual port-freeing commands for the current OS
# Only shows the specific blocked ports
# $OS is set by the caller (bootstrap entry point): "macos" or "linux"
print_port_help() {
    local ports="$1"
    local current_os="${OS:-$(detect_os)}"
    local has_docker_ports=false
    
    # Check if any blocked ports are from Docker
    for port in $ports; do
        if is_docker_port "$port"; then
            has_docker_ports=true
            break
        fi
    done
    
    echo ""
    log_info "${BOLD}Free the blocked ports and re-run bootstrap:${NC}"
    echo ""
    
    if $has_docker_ports; then
        echo -e "      ${CYAN}# Stop Docker containers holding these ports${NC}"
        echo -e "      docker compose down"
        echo -e "      ${CYAN}# Or stop all Docker containers${NC}"
        echo -e "      docker stop \$(docker ps -q)"
        echo ""
    fi
    
    # Show kill commands for non-Docker ports
    if [[ "$current_os" == "macos" ]]; then
        for port in $ports; do
            if ! is_docker_port "$port"; then
                echo -e "      sudo kill -9 \$(lsof -t -i :$port)"
            fi
        done
    else
        # Linux
        if command_exists lsof; then
            for port in $ports; do
                if ! is_docker_port "$port"; then
                    echo -e "      sudo kill -9 \$(lsof -t -i :$port)"
                fi
            done
        else
            for port in $ports; do
                if ! is_docker_port "$port"; then
                    echo -e "      sudo fuser -k $port/tcp"
                fi
            done
        fi
    fi
    echo ""
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
            if is_docker_port "$port"; then
                blocked_ports+=("$port")
                port_info+=("$port (Docker container)")
            else
                local pid=$(get_port_process "$port")
                local name=$(get_process_name "$pid")
                blocked_ports+=("$port")
                if [[ -n "$pid" ]]; then
                    port_info+=("$port (PID: $pid, Process: $name)")
                else
                    port_info+=("$port (unknown process -- may need sudo to detect)")
                fi
            fi
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
        log_info "Stopping processes on blocked ports..."
        local failed=false
        for port in "${blocked_ports[@]}"; do
            if kill_port_process "$port"; then
                log_success "Freed port $port"
            else
                log_error "Failed to free port $port"
                failed=true
            fi
        done
        
        if $failed; then
            local port_list="${blocked_ports[*]}"
            print_port_help "$port_list"
            return 1
        fi
        return 0
    fi
    
    # Ask user for confirmation
    echo -n -e "    ${YELLOW}?${NC} Stop these processes to continue? [y/N]: "
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        local failed=false
        for port in "${blocked_ports[@]}"; do
            if kill_port_process "$port"; then
                log_success "Freed port $port"
            else
                log_error "Failed to free port $port"
                failed=true
            fi
        done
        
        if $failed; then
            local port_list="${blocked_ports[*]}"
            print_port_help "$port_list"
            return 1
        fi
        return 0
    else
        log_warn "Cannot continue with ports in use"
        local port_list="${blocked_ports[*]}"
        print_port_help "$port_list"
        return 1
    fi
}

