#!/bin/bash
# Smainer Relayer Deployment & Management Script
# Usage: ./deploy-relayer.sh [deploy|start|stop|restart|logs|status]

set -e

CMD="${1:-status}"
COMPOSE_FILE="docker-compose.prod.yml"
ENV_FILE=".env.prod"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Check prerequisites
check_prereqs() {
    if ! command -v docker &> /dev/null; then
        error "Docker not found. Install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        error "docker-compose not found. Install docker-compose first."
        exit 1
    fi
    
    if [ ! -f "$ENV_FILE" ]; then
        warn "Environment file $ENV_FILE not found. Using template..."
        cp .env.prod.template "$ENV_FILE"
        error "Created $ENV_FILE from template. EDIT IT BEFORE DEPLOYING!"
        exit 1
    fi
}

# Deploy services
deploy() {
    log "Starting Smainer Relayer deployment..."
    check_prereqs
    
    # Build and start services
    log "Building and starting services..."
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d --build
    
    # Wait for services to be healthy
    log "Waiting for services to be healthy..."
    sleep 10
    
    # Verify deployment
    if docker ps | grep -q smainer-relayer && docker ps | grep -q smainer-redis; then
        log "Deployment successful!"
        show_status
    else
        error "Deployment failed. Check logs with: $0 logs"
        exit 1
    fi
}

# Start services
start() {
    log "Starting Smainer Relayer services..."
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" start
    show_status
}

# Stop services
stop() {
    log "Stopping Smainer Relayer services..."
    docker-compose -f "$COMPOSE_FILE" stop
}

# Restart services
restart() {
    log "Restarting Smainer Relayer services..."
    stop
    sleep 5
    start
}

# Show logs
show_logs() {
    docker-compose -f "$COMPOSE_FILE" logs -f --tail=100 "${2:-}"
}

# Show status
show_status() {
    echo -e "\n${YELLOW}=== Service Status ===${NC}"
    docker-compose -f "$COMPOSE_FILE" ps
    
    echo -e "\n${YELLOW}=== Container Health ===${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep smainer
    
    echo -e "\n${YELLOW}=== Resource Usage ===${NC}"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep smainer
}

# Emergency recovery
emergency_recovery() {
    error "Starting emergency recovery..."
    
    # Force stop everything
    docker-compose -f "$COMPOSE_FILE" down --remove-orphans
    
    # Clean up
    docker system prune -f
    
    # Restart
    deploy
}

# Update deployment
update() {
    log "Updating Smainer Relayer..."
    
    # Pull latest code
    git pull
    
    # Rebuild and redeploy
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d --build --force-recreate
    
    show_status
}

# Main command handler
case "$CMD" in
    deploy)
        deploy
        ;;
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    logs)
        show_logs "$@"
        ;;
    status)
        show_status
        ;;
    recovery)
        emergency_recovery
        ;;
    update)
        update
        ;;
    *)
        echo "Usage: $0 {deploy|start|stop|restart|logs|status|recovery|update}"
        echo ""
        echo "Commands:"
        echo "  deploy   - Deploy services for the first time"
        echo "  start    - Start existing services"
        echo "  stop     - Stop services"
        echo "  restart  - Restart services"
        echo "  logs     - Show service logs (use 'logs relayer' or 'logs redis')"
        echo "  status   - Show service status and health"
        echo "  recovery - Emergency recovery (force restart)"
        echo "  update   - Pull latest code and redeploy"
        exit 1
        ;;
esac