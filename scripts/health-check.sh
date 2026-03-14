#!/bin/bash
# Smainer Infrastructure Health Monitoring Script
# Usage: ./health_check.sh [environment] [component]
# Example: ./health_check.sh staging relayer

set -euo pipefail

ENVIRONMENT="${1:-dev}"
COMPONENT="${2:-all}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration per environment
case "$ENVIRONMENT" in
  "dev")
    RELAYER_URL="http://localhost:8000"
    REDIS_HOST="localhost:6379"
    DB_HOST="localhost:5432"
    ;;
  "staging")
    RELAYER_URL="https://relayer-staging.smainer.com:8000"
    REDIS_HOST="redis-staging.smainer.com:6379"
    DB_HOST="postgres-staging.smainer.com:5432"
    ;;
  "prod")
    RELAYER_URL="https://relayer.smainer.com:8000"
    REDIS_HOST="redis.smainer.com:6379"
    DB_HOST="postgres.smainer.com:5432"
    ;;
  *)
    echo -e "${RED}❌ Unknown environment: $ENVIRONMENT${NC}"
    echo "Available: dev, staging, prod"
    exit 1
    ;;
esac

log_status() {
  local status=$1
  local component=$2
  local message=$3
  local color=$4
  
  echo -e "${color}${status} ${component}: ${message}${NC}"
  
  # Log to file for historical tracking
  echo "$TIMESTAMP,$ENVIRONMENT,$component,$status,$message" >> "/tmp/smainer_health_${ENVIRONMENT}.csv"
}

check_relayer_health() {
  echo -e "${BLUE}🔍 Checking Relayer Health...${NC}"
  
  # Basic health endpoint
  if curl -s -o /dev/null -w "%{http_code}" "$RELAYER_URL/health" | grep -q "200"; then
    log_status "✅" "RELAYER" "Health endpoint responding" "$GREEN"
  else
    log_status "❌" "RELAYER" "Health endpoint failed" "$RED"
    return 1
  fi
  
  # WebSocket endpoint test
  if timeout 5 python3 -c "
import asyncio
import websockets
import sys

async def test_ws():
    try:
        uri = '$RELAYER_URL'.replace('http', 'ws') + '/ws/test'
        async with websockets.connect(uri, timeout=3) as websocket:
            await websocket.ping()
        print('WebSocket OK')
    except Exception as e:
        print(f'WebSocket FAILED: {e}')
        sys.exit(1)

asyncio.run(test_ws())
" 2>/dev/null; then
    log_status "✅" "WEBSOCKET" "Connection test passed" "$GREEN"
  else
    log_status "❌" "WEBSOCKET" "Connection test failed" "$RED"
    return 1
  fi
  
  # API response time test
  RESPONSE_TIME=$(curl -o /dev/null -s -w "%{time_total}" "$RELAYER_URL/health")
  if (( $(echo "$RESPONSE_TIME < 0.1" | bc -l) )); then
    log_status "✅" "LATENCY" "Response time: ${RESPONSE_TIME}s (<100ms)" "$GREEN"
  elif (( $(echo "$RESPONSE_TIME < 0.5" | bc -l) )); then
    log_status "⚠️" "LATENCY" "Response time: ${RESPONSE_TIME}s (warning)" "$YELLOW"
  else
    log_status "❌" "LATENCY" "Response time: ${RESPONSE_TIME}s (>500ms)" "$RED"
  fi
}

check_redis_health() {
  echo -e "${BLUE}🔍 Checking Redis Health...${NC}"
  
  # Basic connectivity
  if redis-cli -h "$(echo $REDIS_HOST | cut -d: -f1)" -p "$(echo $REDIS_HOST | cut -d: -f2)" ping | grep -q "PONG"; then
    log_status "✅" "REDIS" "Connectivity OK" "$GREEN"
  else
    log_status "❌" "REDIS" "Connection failed" "$RED"
    return 1
  fi
  
  # Memory usage check
  MEMORY_USED=$(redis-cli -h "$(echo $REDIS_HOST | cut -d: -f1)" -p "$(echo $REDIS_HOST | cut -d: -f2)" info memory | grep used_memory_human | cut -d: -f2 | tr -d '\r')
  MEMORY_PEAK=$(redis-cli -h "$(echo $REDIS_HOST | cut -d: -f1)" -p "$(echo $REDIS_HOST | cut -d: -f2)" info memory | grep used_memory_peak_human | cut -d: -f2 | tr -d '\r')
  log_status "ℹ️" "REDIS_MEMORY" "Used: $MEMORY_USED, Peak: $MEMORY_PEAK" "$BLUE"
  
  # Check cluster state if applicable
  if [[ "$ENVIRONMENT" != "dev" ]]; then
    CLUSTER_STATE=$(redis-cli -h "$(echo $REDIS_HOST | cut -d: -f1)" -p "$(echo $REDIS_HOST | cut -d: -f2)" cluster info | grep cluster_state | cut -d: -f2)
    if [[ "$CLUSTER_STATE" == "ok" ]]; then
      log_status "✅" "REDIS_CLUSTER" "Cluster state OK" "$GREEN"
    else
      log_status "❌" "REDIS_CLUSTER" "Cluster state: $CLUSTER_STATE" "$RED"
      return 1
    fi
  fi
}

check_database_health() {
  echo -e "${BLUE}🔍 Checking Database Health...${NC}"
  
  # Basic connectivity (requires PGPASSWORD env var or .pgpass file)
  if pg_isready -h "$(echo $DB_HOST | cut -d: -f1)" -p "$(echo $DB_HOST | cut -d: -f2)" >/dev/null 2>&1; then
    log_status "✅" "DATABASE" "Connectivity OK" "$GREEN"
  else
    log_status "❌" "DATABASE" "Connection failed" "$RED"
    return 1
  fi
  
  # Check disk usage
  if command -v psql >/dev/null 2>&1; then
    DB_SIZE=$(psql -h "$(echo $DB_HOST | cut -d: -f1)" -p "$(echo $DB_HOST | cut -d: -f2)" -d smainer -t -c "SELECT pg_size_pretty(pg_database_size('smainer'));" 2>/dev/null | xargs || echo "Unknown")
    log_status "ℹ️" "DATABASE_SIZE" "Size: $DB_SIZE" "$BLUE"
  fi
}

check_provider_network() {
  echo -e "${BLUE}🔍 Checking Provider Network Health...${NC}"
  
  # Get connected providers count
  CONNECTED_PROVIDERS=$(curl -s "$RELAYER_URL/api/stats/providers" 2>/dev/null | jq -r '.connected_count' || echo "0")
  TOTAL_PROVIDERS=$(curl -s "$RELAYER_URL/api/stats/providers" 2>/dev/null | jq -r '.total_registered' || echo "0")
  
  if [[ "$CONNECTED_PROVIDERS" -gt 0 ]]; then
    CONNECTION_RATIO=$(echo "scale=1; $CONNECTED_PROVIDERS * 100 / $TOTAL_PROVIDERS" | bc -l)
    log_status "✅" "PROVIDERS" "Connected: $CONNECTED_PROVIDERS/$TOTAL_PROVIDERS (${CONNECTION_RATIO}%)" "$GREEN"
  else
    log_status "❌" "PROVIDERS" "No providers connected" "$RED"
    return 1
  fi
  
  # Check task processing rate
  TASKS_PENDING=$(curl -s "$RELAYER_URL/api/stats/tasks" 2>/dev/null | jq -r '.pending_count' || echo "0")
  TASKS_PROCESSING=$(curl -s "$RELAYER_URL/api/stats/tasks" 2>/dev/null | jq -r '.processing_count' || echo "0")
  
  if [[ "$TASKS_PENDING" -lt 100 ]]; then
    log_status "✅" "TASK_QUEUE" "Pending: $TASKS_PENDING, Processing: $TASKS_PROCESSING" "$GREEN"
  elif [[ "$TASKS_PENDING" -lt 500 ]]; then
    log_status "⚠️" "TASK_QUEUE" "Pending: $TASKS_PENDING, Processing: $TASKS_PROCESSING" "$YELLOW"
  else
    log_status "❌" "TASK_QUEUE" "Queue backlog: $TASKS_PENDING pending tasks" "$RED"
  fi
}

check_consensus_layer() {
  echo -e "${BLUE}🔍 Checking Consensus Layer Health...${NC}"
  
  if [[ "$ENVIRONMENT" == "dev" ]]; then
    log_status "ℹ️" "CONSENSUS" "Simulated mode in dev environment" "$BLUE"
    return 0
  fi
  
  # Check coordinator election status
  COORDINATOR_COUNT=$(curl -s "$RELAYER_URL/api/consensus/coordinators" 2>/dev/null | jq -r '.active_count' || echo "0")
  ELECTION_STATUS=$(curl -s "$RELAYER_URL/api/consensus/election" 2>/dev/null | jq -r '.status' || echo "unknown")
  
  if [[ "$COORDINATOR_COUNT" -ge 3 && "$ELECTION_STATUS" == "stable" ]]; then
    log_status "✅" "CONSENSUS" "Coordinators: $COORDINATOR_COUNT, Status: $ELECTION_STATUS" "$GREEN"
  else
    log_status "⚠️" "CONSENSUS" "Coordinators: $COORDINATOR_COUNT, Status: $ELECTION_STATUS" "$YELLOW"
  fi
}

generate_health_report() {
  echo -e "${BLUE}📊 Health Check Summary for $ENVIRONMENT${NC}"
  echo "======================================"
  
  if [[ -f "/tmp/smainer_health_${ENVIRONMENT}.csv" ]]; then
    echo "Recent Health Events (last 10):"
    tail -10 "/tmp/smainer_health_${ENVIRONMENT}.csv" | column -t -s ','
  fi
  
  echo ""
  echo "Next Steps:"
  echo "- Review logs: kubectl logs -l app=smainer-relayer"
  echo "- Monitor metrics: https://grafana.smainer.com/d/system-health"
  echo "- Check alerts: https://prometheus.smainer.com/alerts"
}

# Main execution logic
main() {
  echo -e "${BLUE}🚀 Smainer Infrastructure Health Check${NC}"
  echo "Environment: $ENVIRONMENT"
  echo "Timestamp: $TIMESTAMP"
  echo "======================================"
  
  case "$COMPONENT" in
    "relayer"|"all")
      check_relayer_health || true
      ;;
  esac
  
  case "$COMPONENT" in
    "redis"|"all")
      check_redis_health || true
      ;;
  esac
  
  case "$COMPONENT" in
    "database"|"db"|"all")
      check_database_health || true
      ;;
  esac
  
  case "$COMPONENT" in
    "providers"|"network"|"all")
      check_provider_network || true
      ;;
  esac
  
  case "$COMPONENT" in
    "consensus"|"all")
      check_consensus_layer || true
      ;;
  esac
  
  if [[ "$COMPONENT" == "all" ]]; then
    generate_health_report
  fi
}

# Script execution
main "$@"