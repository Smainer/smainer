#!/bin/bash
# Smainer Stack Master Controller
# One-shot script for complete Smainer stack operations

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
SCRIPTS_DIR="$PROJECT_ROOT/scripts"

# Initialize script permissions
initialize_scripts() {
    log_info "Making all Smainer stack scripts executable..."
    
    local scripts=(
        "launch-smainer-stack.sh"
        "verify-smainer-stack.sh" 
        "stop-smainer-stack.sh"
        "setup-smainer-env.sh"
        "smainer-stack-master.sh"
    )
    
    for script in "${scripts[@]}"; do
        local script_path="$SCRIPTS_DIR/$script"
        if [ -f "$script_path" ]; then
            chmod +x "$script_path"
            log_success "Script executable: $script"
        else
            log_warning "Script not found: $script"
        fi
    done
}

# Quick status check
status_check() {
    log_info "🔍 Smainer Stack Status Check"
    echo "========================================="
    
    # Check PID files
    local pid_files=(
        "/tmp/smainer-redis.pid:Redis"
        "/tmp/smainer-relayer.pid:Relayer"
        "/tmp/smainer-provider.pid:Provider"
    )
    
    local running_services=0
    local total_services=${#pid_files[@]}
    
    for pid_entry in "${pid_files[@]}"; do
        IFS=':' read -r pid_file service_name <<< "$pid_entry"
        
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file" 2>/dev/null || echo "")
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                log_success "$service_name running (PID: $pid)"
                running_services=$((running_services + 1))
            else
                log_error "$service_name stopped (stale PID file)"
            fi
        else
            log_error "$service_name stopped (no PID file)"
        fi
    done
    
    echo ""
    if [ $running_services -eq $total_services ]; then
        log_success "🎉 All services running ($running_services/$total_services)"
        
        # Quick connectivity tests
        if curl -s "http://localhost:8000/api/v1/health" >/dev/null 2>&1; then
            log_success "Relayer health endpoint responding"
        else
            log_warning "Relayer health endpoint not responding"
        fi
        
        if [ -n "${REDIS_PASSWORD:-}" ] && redis-cli -a "$REDIS_PASSWORD" ping >/dev/null 2>&1; then
            log_success "Redis responding with auth"
        elif redis-cli ping >/dev/null 2>&1; then
            log_success "Redis responding (no auth)"
        else
            log_warning "Redis not responding"
        fi
    else
        log_warning "⚠️  Partial service status ($running_services/$total_services running)"
    fi
}

# Quick launch wrapper
quick_launch() {
    log_info "🚀 Quick Launch - Smainer Stack"
    echo "========================================="
    
    # Check if environment is configured
    if [ ! -f "$PROJECT_ROOT/.env.smainer-stack" ]; then
        log_warning "Environment not configured. Running setup..."
        "$SCRIPTS_DIR/setup-smainer-env.sh" setup
        echo ""
    fi
    
    # Load environment
    log_info "Loading environment configuration..."
    set -a
    source "$PROJECT_ROOT/.env.smainer-stack"
    set +a
    
    # Validate environment
    if ! "$SCRIPTS_DIR/setup-smainer-env.sh" validate; then
        log_error "Environment validation failed. Fix configuration and retry."
        exit 1
    fi
    
    # Launch stack
    log_info "Launching Smainer stack..."
    exec "$SCRIPTS_DIR/launch-smainer-stack.sh"
}

# Full deployment workflow
full_deploy() {
    log_info "📦 Full Deployment Workflow"
    echo "========================================="
    
    # Step 1: Setup environment
    echo ""
    log_info "Step 1: Environment Setup"
    if [ ! -f "$PROJECT_ROOT/.env.smainer-stack" ]; then
        "$SCRIPTS_DIR/setup-smainer-env.sh" setup
    else
        log_info "Environment file exists, validating..."
        if ! "$SCRIPTS_DIR/setup-smainer-env.sh" validate; then
            log_error "Environment validation failed. Please fix and retry."
            exit 1
        fi
    fi
    
    # Step 2: Load environment
    echo ""
    log_info "Step 2: Loading Environment"
    set -a
    source "$PROJECT_ROOT/.env.smainer-stack"
    set +a
    log_success "Environment loaded"
    
    # Step 3: Launch stack
    echo ""
    log_info "Step 3: Launching Stack"
    "$SCRIPTS_DIR/launch-smainer-stack.sh"
    
    # Step 4: Verify deployment
    echo ""
    log_info "Step 4: Verifying Deployment"
    sleep 5  # Give services time to fully start
    if "$SCRIPTS_DIR/verify-smainer-stack.sh"; then
        log_success "🎉 Full deployment successful!"
    else
        log_error "❌ Deployment verification failed"
        log_info "Check logs and try: $0 stop && $0 deploy"
        exit 1
    fi
}

# Development mode (with debug logging)
dev_mode() {
    log_info "🧪 Development Mode Launch"
    echo "========================================="
    
    # Override some settings for development
    export LOG_LEVEL="DEBUG"
    export ENABLE_BATCH_SUBMISSION="false"
    export MAX_CONCURRENT_TASKS="1"
    
    # Use dev environment if available
    local dev_env="$PROJECT_ROOT/.env.dev"
    if [ -f "$dev_env" ]; then
        log_info "Loading development environment from $dev_env"
        set -a
        source "$dev_env"
        set +a
    else
        log_info "Creating development environment..."
        "$SCRIPTS_DIR/setup-smainer-env.sh" generate "$dev_env"
        log_warning "Edit $dev_env with development settings and retry"
        exit 0
    fi
    
    log_info "Starting in development mode..."
    exec "$SCRIPTS_DIR/launch-smainer-stack.sh"
}

# Show comprehensive help
show_help() {
    echo ""
    echo "🎛️  Smainer Stack Master Controller"
    echo "========================================="
    echo ""
    echo "USAGE:"
    echo "  $0 <command> [options]"
    echo ""
    echo "COMMANDS:"
    echo ""
    echo "Basic Operations:"
    echo "  start, launch          Quick launch with existing config"
    echo "  stop, shutdown         Stop all services gracefully"
    echo "  restart                Stop then start services"
    echo "  status                 Check service status quickly"
    echo "  verify                 Run comprehensive health checks"
    echo ""
    echo "Management:"
    echo "  deploy                 Full deployment workflow (setup + launch + verify)"
    echo "  setup                  Interactive environment configuration"
    echo "  config                 Validate/edit environment settings"
    echo ""
    echo "Development:"
    echo "  dev                    Launch in development mode"
    echo "  logs                   Show recent logs from all services"
    echo "  monitor                Real-time log monitoring"
    echo ""
    echo "Troubleshooting:"
    echo "  doctor                 Run diagnostics and health checks"
    echo "  cleanup                Stop services and clean temporary files"
    echo "  reset                  Complete reset (stop + cleanup + remove config)"
    echo ""
    echo "EXAMPLES:"
    echo "  $0 deploy              # First-time setup and launch"
    echo "  $0 start               # Quick start with existing config"
    echo "  $0 status              # Check if services are running"
    echo "  $0 verify              # Comprehensive service verification"
    echo "  $0 stop --force        # Force stop all services"
    echo "  $0 dev                 # Development mode with debug logging"
    echo ""
    echo "FILES:"
    echo "  Config:      $PROJECT_ROOT/.env.smainer-stack"
    echo "  Logs:        $PROJECT_ROOT/logs/"
    echo "  Scripts:     $SCRIPTS_DIR/"
    echo ""
    echo "ENVIRONMENT:"
    echo "  Required secrets: REDIS_PASSWORD, API_KEY, RELAYER_PRIVATE_KEY, STARKNET_PRIVATE_KEY"
    echo "  Hardware: Auto-detects and uses 50% of available CPU/RAM"
    echo "  Ports: 6379 (Redis), 8000 (Relayer)"
    echo ""
}

# Main command dispatcher
main() {
    # Initialize on first run
    if [ ! -x "$SCRIPTS_DIR/launch-smainer-stack.sh" ]; then
        initialize_scripts
        echo ""
    fi
    
    local command="${1:-help}"
    
    case "$command" in
        "start"|"launch"|"run")
            quick_launch
            ;;
            
        "stop"|"shutdown")
            shift # Remove command from args
            "$SCRIPTS_DIR/stop-smainer-stack.sh" "$@"
            ;;
            
        "restart"|"reload")
            log_info "Restarting Smainer stack..."
            "$SCRIPTS_DIR/stop-smainer-stack.sh" --no-archive
            sleep 2
            quick_launch
            ;;
            
        "status"|"st")
            status_check
            ;;
            
        "verify"|"check")
            "$SCRIPTS_DIR/verify-smainer-stack.sh" "${2:-}"
            ;;
            
        "deploy"|"init")
            full_deploy
            ;;
            
        "setup"|"configure")
            "$SCRIPTS_DIR/setup-smainer-env.sh" setup
            ;;
            
        "config"|"env")
            shift
            "$SCRIPTS_DIR/setup-smainer-env.sh" "$@"
            ;;
            
        "dev"|"development")
            dev_mode
            ;;
            
        "logs")
            local logs_dir="$PROJECT_ROOT/logs"
            if [ -d "$logs_dir" ] && compgen -G "$logs_dir/*.log" > /dev/null; then
                log_info "Recent logs from all services:"
                echo ""
                for log_file in "$logs_dir"/*.log; do
                    echo "=== $(basename "$log_file") ==="
                    tail -20 "$log_file" 2>/dev/null || echo "No recent entries"
                    echo ""
                done
            else
                log_warning "No log files found in $logs_dir"
            fi
            ;;
            
        "monitor"|"tail")
            local logs_dir="$PROJECT_ROOT/logs"
            if [ -d "$logs_dir" ] && compgen -G "$logs_dir/*.log" > /dev/null; then
                log_info "Real-time log monitoring (Ctrl+C to stop):"
                tail -f "$logs_dir"/*.log
            else
                log_error "No log files found to monitor"
                exit 1
            fi
            ;;
            
        "doctor"|"diagnose")
            log_info "🏥 Running Smainer Stack Diagnostics"
            echo "========================================="
            
            # Run all checks
            status_check
            echo ""
            "$SCRIPTS_DIR/setup-smainer-env.sh" security
            echo ""
            "$SCRIPTS_DIR/verify-smainer-stack.sh" --quiet || true
            ;;
            
        "cleanup")
            log_info "🧹 Cleaning up Smainer stack..."
            "$SCRIPTS_DIR/stop-smainer-stack.sh" "$@"
            ;;
            
        "reset")
            log_warning "⚠️  This will completely reset Smainer stack configuration"
            read -p "Are you sure? Type 'yes' to continue: " confirmation
            if [ "$confirmation" = "yes" ]; then
                log_info "Stopping services..."
                "$SCRIPTS_DIR/stop-smainer-stack.sh" --force 2>/dev/null || true
                
                log_info "Removing configuration files..."
                rm -f "$PROJECT_ROOT/.env.smainer-stack"
                rm -f "$PROJECT_ROOT/.env.dev"
                
                log_info "Cleaning logs..."
                rm -rf "$PROJECT_ROOT/logs"
                
                log_success "Reset complete. Run '$0 setup' to reconfigure."
            else
                log_info "Reset cancelled."
            fi
            ;;
            
        "help"|"--help"|"-h"|"")
            show_help
            ;;
            
        *)
            log_error "Unknown command: $command"
            echo ""
            echo "Use '$0 help' for usage information."
            exit 1
            ;;
    esac
}

# Signal handling for clean shutdown
cleanup_on_interrupt() {
    echo ""
    log_warning "Interrupted. Stopping services..."
    "$SCRIPTS_DIR/stop-smainer-stack.sh" --force 2>/dev/null || true
    exit 1
}

trap cleanup_on_interrupt INT TERM

# Execute main function
main "$@"