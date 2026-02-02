#!/usr/bin/env bash
#
# start.sh - Start demo-site Flask application
#
# Usage: ./start.sh [start|stop|restart|status|logs]

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODE_DIR="${REPO_DIR}/code"
LOG_DIR="/workspace/logs"
PID_FILE="${LOG_DIR}/demo-site.pid"
LOG_FILE="${LOG_DIR}/demo-site.log"

# Create log directory
mkdir -p "$LOG_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

is_running() {
    # Check if PID file exists and process is alive
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    
    # Also check if port 8080 is responding (backup check)
    if curl -sf --max-time 1 http://localhost:8080/health > /dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

start_service() {
    if is_running; then
        log_info "Demo site is already running (PID: $(cat $PID_FILE))"
        return 0
    fi
    
    log_info "Starting demo site on port 8080..."
    cd "$CODE_DIR"
    
    # Enable debug mode for hot-reloading during development
    # Flask's reloader creates a subprocess, so we track the process group
    export FLASK_ENV=development
    
    # Start in a new process group so we can kill all child processes
    setsid python app.py > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    
    sleep 2
    if is_running; then
        log_success "Demo site started (PID: $(cat $PID_FILE))"
        log_info "Hot-reload enabled: code changes will auto-refresh"
    else
        log_error "Failed to start demo site"
        return 1
    fi
}

stop_service() {
    if ! is_running; then
        log_info "Demo site is not running"
        return 0
    fi
    
    log_info "Stopping demo site..."
    
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        # Kill the entire process group (negative PID kills the group)
        kill -TERM -"$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
    
    # Also kill any remaining python processes for this app
    pkill -f "python app.py" 2>/dev/null || true
    
    log_success "Demo site stopped"
}

show_status() {
    echo ""
    echo "======================================"
    echo "  Demo Site Status"
    echo "======================================"
    
    if is_running; then
        echo -e "  Service: ${GREEN}Running${NC} (PID: $(cat $PID_FILE))"
    else
        echo -e "  Service: ${RED}Stopped${NC}"
    fi
    
    echo ""
    echo "  URLs:"
    echo "    Website:      http://localhost:8080"
    echo "    Health Check: http://localhost:8080/health"
    echo "    API Info:     http://localhost:8080/api/info"
    echo ""
    echo "  Log: $LOG_FILE"
    echo "======================================"
}

show_logs() {
    if [[ -f "$LOG_FILE" ]]; then
        tail -f "$LOG_FILE"
    else
        log_error "No log file found"
    fi
}

# Main command handler
case "${1:-start}" in
    start)
        start_service
        show_status
        ;;
    stop)
        stop_service
        ;;
    restart)
        stop_service
        sleep 1
        start_service
        show_status
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs}"
        exit 1
        ;;
esac
