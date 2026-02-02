#!/usr/bin/env bash
#
# start.sh - Start CYVL GeoGuesser frontend and backend
#
# Usage: ./start.sh [start|stop|restart|status|logs]

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODE_DIR="${REPO_DIR}/code"
LOG_DIR="/workspace/logs"

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

backend_running() {
    [[ -f "$LOG_DIR/backend.pid" ]] && kill -0 "$(cat "$LOG_DIR/backend.pid")" 2>/dev/null
}

frontend_running() {
    [[ -f "$LOG_DIR/frontend.pid" ]] && kill -0 "$(cat "$LOG_DIR/frontend.pid")" 2>/dev/null
}

start_backend() {
    log_info "Starting GeoGuesser backend API on port 8000..."
    cd "$CODE_DIR/api"
    
    # Use setsid to create new process group (prevents zombie processes)
    setsid uv run uvicorn geolocation_api.app:app --reload --host 0.0.0.0 --port 8000 \
        > "$LOG_DIR/backend.log" 2>&1 &
    
    echo $! > "$LOG_DIR/backend.pid"
    log_success "Backend started (PID: $(cat $LOG_DIR/backend.pid))"
}

start_frontend() {
    log_info "Starting GeoGuesser frontend on port 5173..."
    cd "$CODE_DIR"
    
    # Use setsid to create new process group (prevents zombie processes)
    setsid npm run dev -- --host 0.0.0.0 \
        > "$LOG_DIR/frontend.log" 2>&1 &
    
    echo $! > "$LOG_DIR/frontend.pid"
    log_success "Frontend started (PID: $(cat $LOG_DIR/frontend.pid))"
}

start_services() {
    stop_services 2>/dev/null || true
    start_backend
    start_frontend
}

stop_services() {
    log_info "Stopping GeoGuesser services..."
    
    if [[ -f "$LOG_DIR/backend.pid" ]]; then
        local pid=$(cat "$LOG_DIR/backend.pid")
        # Kill the process group (negative PID)
        kill -TERM -"$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
        rm -f "$LOG_DIR/backend.pid"
    fi
    
    if [[ -f "$LOG_DIR/frontend.pid" ]]; then
        local pid=$(cat "$LOG_DIR/frontend.pid")
        # Kill the process group (negative PID)
        kill -TERM -"$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
        rm -f "$LOG_DIR/frontend.pid"
    fi
    
    # Cleanup any remaining processes
    pkill -f "uvicorn geolocation_api" 2>/dev/null || true
    pkill -f "vite" 2>/dev/null || true
    pkill -f "node.*cyvl-geoguesser" 2>/dev/null || true
    
    log_success "Services stopped"
}

show_status() {
    echo ""
    echo "======================================"
    echo "  CYVL GeoGuesser Status"
    echo "======================================"
    
    if backend_running; then
        echo -e "  Backend:  ${GREEN}Running${NC} (PID: $(cat $LOG_DIR/backend.pid))"
    else
        echo -e "  Backend:  ${RED}Stopped${NC}"
    fi
    
    if frontend_running; then
        echo -e "  Frontend: ${GREEN}Running${NC} (PID: $(cat $LOG_DIR/frontend.pid))"
    else
        echo -e "  Frontend: ${RED}Stopped${NC}"
    fi
    
    echo ""
    echo "  URLs:"
    echo "    Frontend: http://localhost:5173"
    echo "    Backend:  http://localhost:8000"
    echo "    API Docs: http://localhost:8000/docs"
    echo ""
    echo "  Logs:"
    echo "    Frontend: $LOG_DIR/frontend.log"
    echo "    Backend:  $LOG_DIR/backend.log"
    echo "======================================"
}

show_logs() {
    local service="${1:-all}"
    
    case "$service" in
        frontend)
            tail -f "$LOG_DIR/frontend.log"
            ;;
        backend)
            tail -f "$LOG_DIR/backend.log"
            ;;
        all)
            tail -f "$LOG_DIR/frontend.log" "$LOG_DIR/backend.log"
            ;;
        *)
            log_error "Unknown service: $service"
            echo "Usage: $0 logs [frontend|backend|all]"
            exit 1
            ;;
    esac
}

# Main command handler
case "${1:-start}" in
    start)
        start_services
        sleep 2
        show_status
        ;;
    stop)
        stop_services
        ;;
    restart)
        stop_services
        sleep 1
        start_services
        sleep 2
        show_status
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "${2:-all}"
        ;;
    backend)
        start_backend
        ;;
    frontend)
        start_frontend
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|backend|frontend}"
        exit 1
        ;;
esac
