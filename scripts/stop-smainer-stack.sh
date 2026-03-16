#!/bin/bash
# Smainer Stack Rollback/Stop Script
# Gracefully stops Redis + Relayer + Provider with cleanup

set -euo pipefail

# Color output functions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Project paths
PROJECT_ROOT="/home/smainer/Smainer"
LOGS_DIR="$PROJECT_ROOT/logs"

# PID files
REDIS_PID_FILE="/tmp/smainer-redis.pid"
RELAYER_PID_FILE="/tmp/smainer-relayer.pid"
PROVIDER_PID_FILE="/tmp/smainer-provider.pid"

# Stop order (reverse of startup)
declare -a SERVICES=("provider" "relayer" "redis")
declare -A SERVICE_NAMES=(
    ["provider"]="Provider Daemon"
    ["relayer"]="Relayer API"
    ["redis"]="Redis Server"
)
declare -A PID_FILES=(
    ["provider"]="$PROVIDER_PID_FILE"
    ["relayer"]="$RELAYER_PID_FILE"
    ["redis"]="$REDIS_PID_FILE"
)

# Graceful stop with timeout
stop_service() {
    local service="$1"
    local service_name="${SERVICE_NAMES[$service]}"
    local pid_file="${PID_FILES[$service]}"
    
    log_info "Stopping $service_name..."
    
    # Check if PID file exists
    if [ ! -f "$pid_file" ]; then
        log_warning "$service_name PID file not found - service may not be running"
        return 0
    fi
    
    local pid=$(cat "$pid_file" 2>/dev/null || echo "")
    
    # Check if PID is valid
    if [ -z "$pid" ] || ! [[ "$pid" =~ ^[0-9]+$ ]]; then
        log_warning "$service_name PID file contains invalid PID"
        rm -f "$pid_file"
        return 0
    fi
    
    # Check if process is actually running
    if ! kill -0 "$pid" 2>/dev/null; then
        log_warning "$service_name process (PID: $pid) not running - cleaning up PID file"
        rm -f "$pid_file"
        return 0
    fi
    
    # Send SIGTERM for graceful shutdown
    log_info "Sending SIGTERM to $service_name (PID: $pid)..."
    if kill -TERM "$pid" 2>/dev/null; then
        # Wait for graceful shutdown (up to 10 seconds)
        local timeout=10
        while [ $timeout -gt 0 ] && kill -0 "$pid" 2>/dev/null; do
            sleep 1
            timeout=$((timeout - 1))
        done
        
        # Check if process stopped
        if kill -0 "$pid" 2>/dev/null; then
            log_warning "$service_name didn't stop gracefully, sending SIGKILL..."
            if kill -KILL "$pid" 2>/dev/null; then
                sleep 2
                if kill -0 "$pid" 2>/dev/null; then
                    log_error "Failed to kill $service_name process (PID: $pid)"
                    return 1
                else
                    log_success "$service_name forcefully stopped"
                fi
            else
                log_error "Failed to send SIGKILL to $service_name (PID: $pid)"
                return 1
            fi
        else
            log_success "$service_name stopped gracefully"
        fi
    else
        log_error "Failed to send SIGTERM to $service_name (PID: $pid)"
        return 1
    fi
    
    # Clean up PID file
    rm -f "$pid_file"
    return 0
}

# Special handling for Redis (requires shutdown command)
stop_redis_properly() {
    log_info "Attempting Redis graceful shutdown..."
    
    # Try Redis SHUTDOWN command first (if auth is configured)
    local redis_stopped=false
    
    if [ -n "${REDIS_PASSWORD:-}" ]; then
        if redis-cli -a "$REDIS_PASSWORD" ping >/dev/null 2>&1; then
            if redis-cli -a "$REDIS_PASSWORD" shutdown >/dev/null 2>&1; then
                redis_stopped=true
                log_success "Redis shutdown via SHUTDOWN command"
            fi
        fi
    else
        if redis-cli ping >/dev/null 2>&1; then
            if redis-cli shutdown >/dev/null 2>&1; then
                redis_stopped=true
                log_success "Redis shutdown via SHUTDOWN command"
            fi
        fi
    fi
    
    # If Redis SHUTDOWN didn't work, fall back to process termination
    if [ "$redis_stopped" = false ]; then
        log_info "Redis SHUTDOWN command failed, using process termination..."
        stop_service "redis"
    else
        # Clean up PID file after successful Redis shutdown
        sleep 2
        rm -f "$REDIS_PID_FILE"
    fi
}

# Check for running processes without PID files (cleanup strays)
cleanup_stray_processes() {
    log_info "Checking for stray Smainer processes..."
    
    # Look for stray Python processes (relayer/provider)
    local stray_pids=$(pgrep -f "provider.main\|relayer.*uvicorn\|smainer.*python" 2>/dev/null || true)
    
    if [ -n "$stray_pids" ]; then
        log_warning "Found stray Smainer Python processes: $stray_pids"
        for pid in $stray_pids; do
            if kill -0 "$pid" 2>/dev/null; then
                local cmdline=$(ps -p "$pid" -o cmd --no-headers 2>/dev/null | cut -c1-60)
                log_warning "Terminating stray process: PID $pid - $cmdline"
                kill -TERM "$pid" 2>/dev/null || true
            fi
        done
        sleep 3
        
        # Force kill any remaining
        for pid in $stray_pids; do
            if kill -0 "$pid" 2>/dev/null; then
                log_warning "Force killing stubborn process: PID $pid"
                kill -KILL "$pid" 2>/dev/null || true
            fi
        done
    fi
    
    # Look for stray Redis processes
    local stray_redis=$(pgrep -f "redis-server.*6379" 2>/dev/null || true)
    if [ -n "$stray_redis" ]; then
        log_warning "Found stray Redis processes: $stray_redis"
        for pid in $stray_redis; do
            if kill -0 "$pid" 2>/dev/null; then
                log_warning "Terminating stray Redis: PID $pid"
                kill -TERM "$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
            fi
        done
    fi
}

# Archive logs before cleanup
archive_logs() {
    if [ ! -d "$LOGS_DIR" ]; then
        log_info "No logs directory found - skipping log archival"
        return
    fi
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local archive_dir="$LOGS_DIR/archived_$timestamp"
    
    # Check if there are log files to archive
    if compgen -G "$LOGS_DIR/*.log" > /dev/null; then
        log_info "Archiving log files..."
        mkdir -p "$archive_dir"
        
        # Move current logs to archive
        mv "$LOGS_DIR"/*.log "$archive_dir"/ 2>/dev/null || true
        
        # Create summary file
        cat > "$archive_dir/stop_summary.txt" <<EOF
Smainer Stack Stop Summary
=========================
Timestamp: $(date)
Archived by: stop-smainer-stack.sh

Log files archived:
$(ls -la "$archive_dir"/*.log 2>/dev/null || echo "No log files")

Archive location: $archive_dir
EOF
        
        log_success "Logs archived to: $archive_dir"
        
        # Keep only last 5 archives to prevent disk bloat
        local archive_count=$(find "$LOGS_DIR" -maxdepth 1 -name "archived_*" -type d | wc -l)
        if [ "$archive_count" -gt 5 ]; then
            log_info "Cleaning up old archives (keeping 5 most recent)..."
            find "$LOGS_DIR" -maxdepth 1 -name "archived_*" -type d -printf '%T@ %p\n' | \
                sort -r | tail -n +6 | cut -d' ' -f2- | xargs rm -rf
        fi
    else
        log_info "No log files found to archive"
    fi
}

# Cleanup temporary files and directories
cleanup_temp_files() {
    log_info "Cleaning up temporary files..."
    
    # Clean up sandbox directories
    local sandbox_patterns=(
        "/tmp/provider_sandbox_*"
        "/tmp/smainer_*"
        "/var/lib/smainer-provider/sandbox/*"
    )
    
    for pattern in "${sandbox_patterns[@]}"; do
        for dir in $pattern; do
            if [ -d "$dir" ] && [[ "$dir" =~ (provider_sandbox|smainer) ]]; then
                log_info "Removing sandbox directory: $dir"
                rm -rf "$dir" 2>/dev/null || log_warning "Could not remove $dir"
            fi
        done
    done
    
    # Clean up any leftover Unix sockets
    find /tmp -name "smainer*.sock" -user "$(whoami)" -delete 2>/dev/null || true
    
    log_success "Temporary files cleaned up"
}

# Port cleanup (kill processes using our ports)
cleanup_ports() {
    log_info "Checking for processes using Smainer ports..."
    
    local ports=("6379" "8000")
    
    for port in "${ports[@]}"; do
        local port_pids=$(lsof -ti :$port 2>/dev/null || true)
        if [ -n "$port_pids" ]; then
            log_warning "Found processes using port $port: $port_pids"
            for pid in $port_pids; do
                if kill -0 "$pid" 2>/dev/null; then
                    local process_name=$(ps -p "$pid" -o comm --no-headers 2>/dev/null || echo "unknown")
                    log_warning "Terminating process on port $port: PID $pid ($process_name)"
                    kill -TERM "$pid" 2>/dev/null || true
                fi
            done
            
            # Check again after 3 seconds
            sleep 3
            port_pids=$(lsof -ti :$port 2>/dev/null || true)
            if [ -n "$port_pids" ]; then
                for pid in $port_pids; do
                    if kill -0 "$pid" 2>/dev/null; then
                        log_warning "Force killing stubborn process on port $port: PID $pid"
                        kill -KILL "$pid" 2>/dev/null || true
                    fi
                done
            fi
        fi
    done
}

# Network cleanup (if docker-compose was used)
cleanup_docker() {
    if command -v docker >/dev/null 2>&1 && command -v docker-compose >/dev/null 2>&1; then
        if [ -f "$PROJECT_ROOT/docker-compose.prod.yml" ]; then
            log_info "Checking for Docker containers..."
            
            cd "$PROJECT_ROOT"
            local running_containers=$(docker-compose -f docker-compose.prod.yml ps -q 2>/dev/null || true)
            
            if [ -n "$running_containers" ]; then
                log_warning "Found running Docker containers, stopping them..."
                docker-compose -f docker-compose.prod.yml down --timeout 10 2>/dev/null || true
                log_success "Docker containers stopped"
            fi
        fi
    fi
}

# Main execution
main() {
    local force_mode=false
    local archive_logs_flag=true
    local cleanup_temp_flag=true
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force|-f)
                force_mode=true
                shift
                ;;
            --no-archive)
                archive_logs_flag=false
                shift
                ;;
            --no-cleanup)
                cleanup_temp_flag=false
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --force, -f        Force stop (skip graceful shutdown timeouts)"
                echo "  --no-archive       Don't archive log files"
                echo "  --no-cleanup       Don't cleanup temporary files"
                echo "  --help, -h         Show this help message"
                echo ""
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                log_error "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    echo ""
    log_info "🛑 Smainer Stack Rollback/Stop"
    echo "========================================="
    
    if [ "$force_mode" = true ]; then
        log_warning "Force mode enabled - using aggressive termination"
    fi
    
    # Stop services in reverse order
    local stop_errors=0
    
    for service in "${SERVICES[@]}"; do
        if [ "$service" = "redis" ]; then
            # Special handling for Redis
            if ! stop_redis_properly; then
                stop_errors=$((stop_errors + 1))
            fi
        else
            if ! stop_service "$service"; then
                stop_errors=$((stop_errors + 1))
            fi
        fi
    done
    
    # Additional cleanup steps
    cleanup_stray_processes
    cleanup_ports
    cleanup_docker
    
    if [ "$archive_logs_flag" = true ]; then
        archive_logs
    fi
    
    if [ "$cleanup_temp_flag" = true ]; then
        cleanup_temp_files
    fi
    
    # Final verification  
    echo ""
    log_info "Verifying all services stopped..."
    
    local still_running=0
    for pid_file in "$PROVIDER_PID_FILE" "$RELAYER_PID_FILE" "$REDIS_PID_FILE"; do
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file" 2>/dev/null || echo "")
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                still_running=$((still_running + 1))
                log_error "Process still running: PID $pid ($(basename "$pid_file" .pid))"
            fi
        fi
    done
    
    # Summary
    echo ""
    echo "========================================="
    if [ "$still_running" -eq 0 ] && [ "$stop_errors" -eq 0 ]; then
        log_success "🎉 Smainer stack stopped successfully!"
        echo ""
        echo "All services terminated cleanly:"
        echo "  ✅ Provider daemon stopped"
        echo "  ✅ Relayer API stopped"
        echo "  ✅ Redis server stopped"
        echo ""
        if [ "$archive_logs_flag" = true ]; then
            echo "📁 Log files archived in: $LOGS_DIR/archived_*"
        fi
        if [ "$cleanup_temp_flag" = true ]; then
            echo "🧹 Temporary files cleaned up"
        fi
        echo ""
        echo "Ready for fresh start with: scripts/launch-smainer-stack.sh"
    else
        log_error "❌ Shutdown completed with issues"
        echo ""
        if [ "$stop_errors" -gt 0 ]; then
            echo "  ⚠️  $stop_errors service(s) had stop errors"
        fi
        if [ "$still_running" -gt 0 ]; then
            echo "  ⚠️  $still_running process(es) still running"
        fi
        echo ""
        echo "🔧 Manual cleanup may be required:"
        echo "   ps aux | grep -E 'redis|relayer|provider'"
        echo "   kill -9 <PID>   # for stubborn processes"
        echo "   lsof -i :6379   # check Redis port"
        echo "   lsof -i :8000   # check Relayer port"
        exit 1
    fi
}

# Cleanup function for script interrupts
script_cleanup() {
    echo ""
    log_warning "Script interrupted - attempting emergency stop..."
    
    # Kill known PIDs immediately
    for pid_file in "$PROVIDER_PID_FILE" "$RELAYER_PID_FILE" "$REDIS_PID_FILE"; do
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file" 2>/dev/null || echo "")
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                log_warning "Emergency kill: PID $pid"
                kill -KILL "$pid" 2>/dev/null || true
            fi
            rm -f "$pid_file"
        fi
    done
    
    exit 1
}

trap script_cleanup INT TERM

# Execute main function
main "$@"