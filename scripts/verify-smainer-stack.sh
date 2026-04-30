#!/bin/bash
# Smainer Stack Verification Script
# Comprehensive health checks for Redis + Relayer + Provider

set -euo pipefail

# Color output functions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}ℹ  $1${NC}"; }
log_success() { echo -e "${GREEN} $1${NC}"; }
log_warning() { echo -e "${YELLOW}  $1${NC}"; }
log_error() { echo -e "${RED} $1${NC}"; }

# Project paths
PROJECT_ROOT="/home/smainer/Smainer"
LOGS_DIR="$PROJECT_ROOT/logs"

# PID files
REDIS_PID_FILE="/tmp/smainer-redis.pid"
RELAYER_PID_FILE="/tmp/smainer-relayer.pid"
PROVIDER_PID_FILE="/tmp/smainer-provider.pid"

# Verification counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

check_result() {
    local test_name="$1"
    local result="$2"
    local details="${3:-}"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ "$result" = "PASS" ]; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        log_success "$test_name"
        if [ -n "$details" ]; then
            echo "   $details"
        fi
    elif [ "$result" = "WARN" ]; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))  # Count warnings as passed but note them
        log_warning "$test_name"
        if [ -n "$details" ]; then
            echo "   $details"
        fi
    else
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        log_error "$test_name"
        if [ -n "$details" ]; then
            echo "   $details"
        fi
    fi
}

# Check Redis health
verify_redis() {
    echo ""
    log_info " Verifying Redis..."
    
    # Check PID file exists
    if [ ! -f "$REDIS_PID_FILE" ]; then
        check_result "Redis PID file exists" "FAIL" "PID file not found at $REDIS_PID_FILE"
        return
    fi
    
    local redis_pid=$(cat "$REDIS_PID_FILE")
    
    # Check process is running (fallback to ping for system-owned Redis)
    if ! kill -0 "$redis_pid" 2>/dev/null; then
        if redis-cli ping >/dev/null 2>&1 || { [ -n "${REDIS_PASSWORD:-}" ] && redis-cli -a "$REDIS_PASSWORD" ping >/dev/null 2>&1; }; then
            check_result "Redis process running" "WARN" "PID $redis_pid not signal-accessible, but Redis responds to ping"
        else
            check_result "Redis process running" "FAIL" "Process PID $redis_pid not found and Redis ping failed"
            return
        fi
    else
        check_result "Redis process running" "PASS" "PID $redis_pid active"
    fi
    
    # Check Redis responds to ping (with auth if configured)
    if [ -n "${REDIS_PASSWORD:-}" ]; then
        if redis-cli -a "$REDIS_PASSWORD" ping >/dev/null 2>&1; then
            check_result "Redis ping with auth" "PASS" "Authentication successful"
        else
            check_result "Redis ping with auth" "FAIL" "Authentication failed or Redis not responding"
            return
        fi
    else
        if redis-cli ping >/dev/null 2>&1; then
            check_result "Redis ping" "PASS" "No authentication configured"
        else
            check_result "Redis ping" "FAIL" "Redis not responding"
            return
        fi
    fi
    
    # Check Redis memory usage
    local memory_info
    if [ -n "${REDIS_PASSWORD:-}" ]; then
        memory_info=$(redis-cli -a "$REDIS_PASSWORD" info memory 2>/dev/null | grep "used_memory_human" | cut -d: -f2 | tr -d '\r' || echo "N/A")
    else
        memory_info=$(redis-cli info memory 2>/dev/null | grep "used_memory_human" | cut -d: -f2 | tr -d '\r' || echo "N/A")
    fi
    
    if [ "$memory_info" != "N/A" ]; then
        check_result "Redis memory usage" "PASS" "Memory used: $memory_info"
    else
        check_result "Redis memory usage" "WARN" "Could not retrieve memory info"
    fi
}

# Check Relayer health
verify_relayer() {
    echo ""
    log_info " Verifying Relayer..."
    
    # Check PID file exists
    if [ ! -f "$RELAYER_PID_FILE" ]; then
        check_result "Relayer PID file exists" "FAIL" "PID file not found at $RELAYER_PID_FILE"
        return
    fi
    
    local relayer_pid=$(cat "$RELAYER_PID_FILE")
    
    # Check process is running
    if ! kill -0 "$relayer_pid" 2>/dev/null; then
        check_result "Relayer process running" "FAIL" "Process PID $relayer_pid not found"
        return
    fi
    check_result "Relayer process running" "PASS" "PID $relayer_pid active"
    
    # Port check can be noisy across netstat/ss formats; treat as advisory.
    if netstat -tuln 2>/dev/null | grep -q ":8000" || ss -ltn 2>/dev/null | grep -q ":8000"; then
        check_result "Relayer port 8000 listening" "PASS" "Port 8000 present in local listener table"
    else
        check_result "Relayer port 8000 listening" "WARN" "Could not confirm listener from socket table; validating via health endpoint"
    fi
    
    # Check health endpoint
    local health_response
    health_response=$(curl -s -w "%{http_code}" "http://localhost:8000/api/v1/health" || echo "connection_failed")
    
    if [[ "$health_response" =~ 200$ ]]; then
        local health_body=$(curl -s "http://localhost:8000/api/v1/health" 2>/dev/null || echo "{}")
        check_result "Relayer health endpoint" "PASS" "HTTP 200 - $health_body"
    else
        check_result "Relayer health endpoint" "FAIL" "Response: $health_response"
    fi
    
    # Check WebSocket endpoint (basic connectivity)
    if command -v wscat >/dev/null 2>&1; then
        if timeout 5 wscat -c "ws://localhost:8000/ws" --execute "ping" >/dev/null 2>&1; then
            check_result "Relayer WebSocket endpoint" "PASS" "WebSocket connection successful"
        else
            check_result "Relayer WebSocket endpoint" "WARN" "WebSocket connection failed or timeout"
        fi
    else
        check_result "Relayer WebSocket endpoint" "WARN" "wscat not available for WebSocket testing"
    fi
    
    # Check Redis connectivity from Relayer logs
    if [ -f "$LOGS_DIR/relayer.log" ]; then
        if tail -50 "$LOGS_DIR/relayer.log" | grep -i "redis" | grep -i "connected\|ready\|established" >/dev/null 2>&1; then
            check_result "Relayer Redis connectivity" "PASS" "Redis connection confirmed in logs"
        elif tail -50 "$LOGS_DIR/relayer.log" | grep -i "redis.*error\|redis.*failed\|redis.*timeout" >/dev/null 2>&1; then
            check_result "Relayer Redis connectivity" "FAIL" "Redis connection errors in logs"
        else
            check_result "Relayer Redis connectivity" "WARN" "No clear Redis connection status in logs"
        fi
    else
        check_result "Relayer Redis connectivity" "WARN" "Relayer log file not found"
    fi
}

# Check Provider health
verify_provider() {
    echo ""
    log_info " Verifying Provider..."
    
    # Check PID file exists
    if [ ! -f "$PROVIDER_PID_FILE" ]; then
        check_result "Provider PID file exists" "FAIL" "PID file not found at $PROVIDER_PID_FILE"
        return
    fi
    
    local provider_pid=$(cat "$PROVIDER_PID_FILE")
    
    # Check process is running
    if ! kill -0 "$provider_pid" 2>/dev/null; then
        check_result "Provider process running" "FAIL" "Process PID $provider_pid not found"
        return
    fi
    check_result "Provider process running" "PASS" "PID $provider_pid active"
    
    # Check Provider logs for successful startup
    if [ -f "$LOGS_DIR/provider.log" ]; then
        if tail -50 "$LOGS_DIR/provider.log" | grep -i "started\|ready\|connected\|listening" >/dev/null 2>&1; then
            check_result "Provider startup logs" "PASS" "Successful startup messages found"
        elif tail -50 "$LOGS_DIR/provider.log" | grep -i "error\|failed\|exception\|traceback" >/dev/null 2>&1; then
            check_result "Provider startup logs" "FAIL" "Error messages found in logs"
        else
            check_result "Provider startup logs" "WARN" "No clear startup status in logs"
        fi
    else
        check_result "Provider startup logs" "WARN" "Provider log file not found"
    fi
    
    # Check WebSocket connection to Relayer from Provider logs
    if [ -f "$LOGS_DIR/provider.log" ]; then
        if tail -50 "$LOGS_DIR/provider.log" | grep -i "websocket.*connected\|relayer.*connected" >/dev/null 2>&1; then
            check_result "Provider-Relayer connection" "PASS" "WebSocket connection confirmed in logs"
        elif tail -50 "$LOGS_DIR/provider.log" | grep -i "websocket.*error\|relayer.*failed\|connection.*failed" >/dev/null 2>&1; then
            check_result "Provider-Relayer connection" "FAIL" "Connection errors found in logs"
        else
            check_result "Provider-Relayer connection" "WARN" "No clear connection status in logs"
        fi
    fi
    
    # Check sandbox directory
    local sandbox_dir="${SANDBOX_TEMP_DIR:-/tmp/provider_sandbox_$(whoami)}"
    if [ -d "$sandbox_dir" ]; then
        if [ -w "$sandbox_dir" ]; then
            check_result "Provider sandbox directory" "PASS" "Writable directory at $sandbox_dir"
        else
            check_result "Provider sandbox directory" "FAIL" "Directory exists but not writable: $sandbox_dir"
        fi
    else
        check_result "Provider sandbox directory" "FAIL" "Sandbox directory not found: $sandbox_dir"
    fi
}

# Check system resources
verify_system_resources() {
    echo ""
    log_info " Verifying System Resources..."
    
    # Check CPU usage of our processes
    local cpu_data=""
    for pid_file in "$REDIS_PID_FILE" "$RELAYER_PID_FILE" "$PROVIDER_PID_FILE"; do
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            local cpu_usage=$(ps -p "$pid" -o %cpu --no-headers 2>/dev/null | tr -d ' ' || echo "N/A")
            local process_name=$(basename "$pid_file" .pid | sed 's/smainer-//')
            if [ "$cpu_usage" != "N/A" ]; then
                cpu_data="$cpu_data $process_name:${cpu_usage}%"
            fi
        fi
    done
    
    if [ -n "$cpu_data" ]; then
        check_result "Process CPU usage" "PASS" "Current usage:$cpu_data"
    else
        check_result "Process CPU usage" "WARN" "Could not retrieve CPU usage data"
    fi
    
    # Check memory usage
    local total_memory_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local available_memory_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local used_memory_kb=$((total_memory_kb - available_memory_kb))
    local memory_usage_percent=$((used_memory_kb * 100 / total_memory_kb))
    
    if [ "$memory_usage_percent" -lt 80 ]; then
        check_result "System memory usage" "PASS" "${memory_usage_percent}% used ($(echo "$used_memory_kb / 1024" | bc)MB / $(echo "$total_memory_kb / 1024" | bc)MB)"
    elif [ "$memory_usage_percent" -lt 90 ]; then
        check_result "System memory usage" "WARN" "${memory_usage_percent}% used ($(echo "$used_memory_kb / 1024" | bc)MB / $(echo "$total_memory_kb / 1024" | bc)MB)"
    else
        check_result "System memory usage" "FAIL" "${memory_usage_percent}% used ($(echo "$used_memory_kb / 1024" | bc)MB / $(echo "$total_memory_kb / 1024" | bc)MB) - critically high"
    fi
    
    # Check disk space for logs
    local disk_usage=$(df "$LOGS_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -lt 80 ]; then
        check_result "Log directory disk space" "PASS" "${disk_usage}% used on $(df "$LOGS_DIR" | awk 'NR==2 {print $1}')"
    elif [ "$disk_usage" -lt 90 ]; then
        check_result "Log directory disk space" "WARN" "${disk_usage}% used on $(df "$LOGS_DIR" | awk 'NR==2 {print $1}')"
    else
        check_result "Log directory disk space" "FAIL" "${disk_usage}% used on $(df "$LOGS_DIR" | awk 'NR==2 {print $1}') - critically high"
    fi
}

# Check log files and recent activity
verify_logs() {
    echo ""
    log_info " Verifying Logs..."
    
    local log_files=("redis.log" "relayer.log" "provider.log")
    
    for log_file in "${log_files[@]}"; do
        local full_path="$LOGS_DIR/$log_file"
        local service_name=$(echo "$log_file" | sed 's/.log//')
        
        if [ -f "$full_path" ]; then
            local file_size=$(stat -c%s "$full_path")
            local file_age_minutes=$(( ($(date +%s) - $(stat -c%Y "$full_path")) / 60 ))
            
            if [ "$file_size" -gt 0 ]; then
                if [ "$file_age_minutes" -le 5 ]; then
                    check_result "$service_name log activity" "PASS" "Recent activity ($(echo "scale=1; $file_size/1024" | bc)KB, updated ${file_age_minutes}m ago)"
                else
                    check_result "$service_name log activity" "WARN" "No recent activity ($(echo "scale=1; $file_size/1024" | bc)KB, updated ${file_age_minutes}m ago)"
                fi
            else
                check_result "$service_name log activity" "WARN" "Log file empty"
            fi
        else
            check_result "$service_name log file exists" "FAIL" "Log file not found: $full_path"
        fi
    done
}

# Generate summary report
generate_summary() {
    echo ""
    echo "========================================="
    log_info " Verification Summary"
    echo "========================================="
    
    echo ""
    echo "Results: $PASSED_CHECKS/$TOTAL_CHECKS checks passed"
    
    local success_rate=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    
    if [ "$FAILED_CHECKS" -eq 0 ]; then
        if [ "$success_rate" -eq 100 ]; then
            log_success " All systems operational! Stack is healthy."
        else
            log_warning "  All critical systems operational, but some warnings detected."
        fi
    else
        log_error " $FAILED_CHECKS critical issues detected. Stack may not be fully operational."
        echo ""
        echo "Recommended actions:"
        echo "1. Check individual service logs in $LOGS_DIR/"
        echo "2. Ensure all required environment variables are set"
        echo "3. Verify Redis authentication and connectivity" 
        echo "4. Check system resources and available memory"
        echo "5. Try restarting failed services with: scripts/stop-smainer-stack.sh && scripts/launch-smainer-stack.sh"
    fi
    
    echo ""
    echo " Log files location: $LOGS_DIR"
    echo " Quick log commands:"
    echo "   tail -f $LOGS_DIR/*.log              (monitor all logs)"
    echo "   grep -i error $LOGS_DIR/*.log        (check for errors)"
    echo "   grep -i warn $LOGS_DIR/*.log         (check for warnings)"
    
    echo ""
}

# Main verification
main() {
    echo ""
    log_info " Smainer Stack Verification"
    echo "========================================="
    
    # Run all verification modules
    verify_redis
    verify_relayer  
    verify_provider
    verify_system_resources
    verify_logs
    
    # Generate summary
    generate_summary
    
    # Exit with appropriate code
    if [ "$FAILED_CHECKS" -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Support for non-interactive mode
if [ "${1:-}" = "--quiet" ] || [ "${1:-}" = "-q" ]; then
    # Suppress colors and reduce output for automated checking
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
    
    log_info() { echo "INFO: $1"; }
    log_success() { echo "PASS: $1"; }
    log_warning() { echo "WARN: $1"; }
    log_error() { echo "FAIL: $1"; }
fi

# Execute main function
main "$@"