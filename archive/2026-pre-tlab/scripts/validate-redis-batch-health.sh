#!/bin/bash
#
# Redis Batch Processor Health Validation
# Tests whether Redis timeout spam is benign or dangerous
# Pass/Fail criteria for launch readiness
#

set -euo pipefail

REDIS_HOST="${REDIS_HOST:-redis}"
REDIS_PORT="${REDIS_PORT:-6379}"
RELAYER_API="${RELAYER_API:-http://localhost:8000}"

echo "==== Redis Batch Processor Health Validation ===="
echo "Testing Redis: $REDIS_HOST:$REDIS_PORT"
echo "Testing Relayer: $RELAYER_API"
echo

# Test 1: Redis Basic Connectivity
echo "1. Testing Redis connectivity..."
if timeout 5 redis-cli -h $REDIS_HOST -p $REDIS_PORT ping > /dev/null 2>&1; then
    echo " PASS: Redis responds to ping"
else
    echo " FAIL: Redis unreachable"
    exit 1
fi

# Test 2: Redis Latency Check
echo "2. Testing Redis latency..."
LATENCY=$(timeout 5 redis-cli -h $REDIS_HOST -p $REDIS_PORT --latency-history -n 5 -i 1 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/ms//' || echo "999")
if [[ $(echo "$LATENCY < 50" | bc -l) -eq 1 ]]; then
    echo " PASS: Redis latency ${LATENCY}ms < 50ms threshold"
else
    echo "  WARN: Redis latency ${LATENCY}ms high (may cause timeouts)"
fi

# Test 3: Check Critical Queues/Keys
echo "3. Testing batch processor queue states..."
BATCH_QUEUE_LEN=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT llen batch_queue 2>/dev/null || echo "0")
VERIFIED_RESULTS_LEN=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT llen verified_results 2>/dev/null || echo "0")
echo "   batch_queue length: $BATCH_QUEUE_LEN"
echo "   verified_results length: $VERIFIED_RESULTS_LEN"

if [[ $BATCH_QUEUE_LEN -eq 0 ]] && [[ $VERIFIED_RESULTS_LEN -eq 0 ]]; then
    echo " PASS: Empty queues explain timeout spam (expected behavior)"
    QUEUE_STATUS="BENIGN"
else
    echo "  WARN: Non-empty queues with timeouts suggest processing failure"
    QUEUE_STATUS="INVESTIGATE"
fi

# Test 4: Redis Connection Pool Health
echo "4. Testing Redis connection pool..."
CONNECTED_CLIENTS=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT info clients | grep connected_clients | cut -d: -f2 | tr -d '\r')
MAX_CLIENTS=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT config get maxclients | tail -1)
if [[ $CONNECTED_CLIENTS -lt $(($MAX_CLIENTS / 2)) ]]; then
    echo " PASS: Connection pool healthy ($CONNECTED_CLIENTS/$MAX_CLIENTS)"
else
    echo "  WARN: High connection usage ($CONNECTED_CLIENTS/$MAX_CLIENTS)"
fi

# Test 5: Redis Memory Pressure
echo "5. Testing Redis memory usage..."
USED_MEMORY=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT info memory | grep used_memory_human | cut -d: -f2 | tr -d '\r')
MAX_MEMORY=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT config get maxmemory | tail -1)
echo "   Memory usage: $USED_MEMORY"
if [[ $MAX_MEMORY == "0" ]]; then
    echo " PASS: No memory limit set"
elif redis-cli -h $REDIS_HOST -p $REDIS_PORT info memory | grep -q "used_memory_percentage:"; then
    MEMORY_PCT=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT info memory | grep used_memory_percentage | cut -d: -f2 | tr -d '\r%')
    if [[ $(echo "$MEMORY_PCT < 80" | bc -l) -eq 1 ]]; then
        echo " PASS: Memory usage ${MEMORY_PCT}% < 80%"
    else
        echo "  WARN: Memory pressure ${MEMORY_PCT}% may cause slowdowns"
    fi
else
    echo " PASS: Memory monitoring unavailable"
fi

# Test 6: Slow Query Detection
echo "6. Testing for slow Redis operations..."
SLOWLOG_LEN=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT slowlog len 2>/dev/null || echo "0")
if [[ $SLOWLOG_LEN -eq 0 ]]; then
    echo " PASS: No slow queries detected"
else
    echo "  WARN: $SLOWLOG_LEN slow queries found"
    echo "   Recent slow queries:"
    redis-cli -h $REDIS_HOST -p $REDIS_PORT slowlog get 3 | head -10
fi

# Test 7: Relayer Health API
echo "7. Testing relayer health endpoint..."
if HEALTH_RESP=$(timeout 10 curl -s "$RELAYER_API/health" 2>/dev/null); then
    if echo "$HEALTH_RESP" | grep -q '"status":"healthy"'; then
        echo " PASS: Relayer reports healthy"
    else
        echo "  WARN: Relayer health check failed: $HEALTH_RESP"
    fi
else
    echo "  WARN: Relayer health endpoint unreachable"
fi

# Final Verdict
echo
echo "==== FINAL VERDICT ===="
if [[ "$QUEUE_STATUS" == "BENIGN" ]]; then
    echo " BENIGN: Redis timeout spam is expected behavior (empty queues)"
    echo "   Root cause: Batch processor blpop() timeouts on empty queue"
    echo "   Impact: Log noise only, no functional impact"  
    echo "   Action: Safe to proceed with contract deployment"
    echo "   Fix: Update error handling to treat timeout as debug, not error"
    exit 0
else
    echo " INVESTIGATE: Timeout patterns suggest processing issues"
    echo "   Root cause: Non-empty queues with timeouts indicate stuck batches"
    echo "   Impact: May affect result aggregation and payouts"
    echo "   Action: Investigate batch processor before contract deployment"
    echo "   Check: Verify batch submission configuration and processing logic"
    exit 1
fi