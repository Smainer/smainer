#!/bin/bash
# One-shot provider restart script for Runpod
# Kills all provider instances, starts exactly 1, verifies connection

set -euo pipefail

echo "=== STEP 1: Find all provider processes ==="
echo "--- pgrep ---"
pgrep -af 'provider' 2>/dev/null || echo "(none found via pgrep)"
echo "--- ps aux ---"
ps aux | grep -E 'provider\.main|provider/main' | grep -v grep || echo "(none found via ps)"

echo ""
echo "=== STEP 2: Kill ALL provider processes ==="
# Kill by pattern matching - provider module processes
pkill -f 'provider\.main' 2>/dev/null && echo "Killed provider.main processes" || echo "No provider.main processes to kill"
pkill -f 'provider/main' 2>/dev/null && echo "Killed provider/main processes" || echo "No provider/main processes to kill"

# Also kill any nohup provider processes
pkill -f 'nohup.*provider' 2>/dev/null && echo "Killed nohup provider processes" || echo "No nohup provider to kill"

# Wait for processes to die
sleep 2

# Verify all dead
REMAINING=$(pgrep -af provider 2>/dev/null | grep -v grep | grep -v "provider-restart" || true)
if [ -n "$REMAINING" ]; then
    echo "WARNING: Some provider processes still alive, force killing..."
    echo "$REMAINING"
    pkill -9 -f 'provider' 2>/dev/null || true
    sleep 1
fi

echo "--- Verify all killed ---"
pgrep -af 'python.*provider' 2>/dev/null || echo "All provider processes killed successfully"

echo ""
echo "=== STEP 3: Locate provider code ==="
for DIR in /workspace/smainer-backend/backend/provider /workspace/Smainer/backend/provider /workspace/provider; do
    if [ -f "$DIR/src/provider/main.py" ]; then
        echo "Found provider code at: $DIR"
        PROVIDER_DIR="$DIR"
        break
    fi
done

if [ -z "${PROVIDER_DIR:-}" ]; then
    echo "ERROR: Cannot find provider code!"
    find /workspace -name "main.py" -path "*/provider/*" 2>/dev/null
    exit 1
fi

echo ""
echo "=== STEP 4: Check environment ==="
# Check for .env files
for ENVF in "$PROVIDER_DIR/.env" /workspace/.env; do
    if [ -f "$ENVF" ]; then
        echo "Found .env at: $ENVF"
        # Show env var names only - NEVER values
        grep -oP '^\w+(?==)' "$ENVF" | sort
        break
    fi
done

# Check tunnel URL
echo ""
echo "--- Tunnel URL ---"
if [ -f /workspace/tunnel.log ]; then
    grep -oP 'https://[a-z0-9-]+\.trycloudflare\.com' /workspace/tunnel.log | tail -1
else
    echo "No tunnel.log found"
fi

echo ""
echo "=== STEP 5: Start exactly 1 provider instance ==="
cd "$PROVIDER_DIR"

# Truncate old log
: > /workspace/provider.log

# Start provider daemon - redirect all output
nohup python3 -m provider.main >> /workspace/provider.log 2>&1 &
NEW_PID=$!
echo "$NEW_PID" > /workspace/provider-daemon.pid
echo "Started provider daemon with PID: $NEW_PID"

# Give it time to connect
echo "Waiting 10s for connection..."
sleep 10

echo ""
echo "=== STEP 6: Verify provider started ==="
echo "--- Process check ---"
if kill -0 "$NEW_PID" 2>/dev/null; then
    echo "Provider process $NEW_PID is RUNNING"
else
    echo "ERROR: Provider process $NEW_PID is NOT running!"
fi

echo "--- Process list ---"
ps aux | grep -E 'provider' | grep -v grep | grep -v "provider-restart"

echo ""
echo "=== STEP 7: Check provider log ==="
tail -40 /workspace/provider.log

echo ""
echo "=== DONE ==="
