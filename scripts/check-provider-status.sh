#!/bin/bash
# Quick Provider Heartbeat + Registration Verification
# Run this to check if provider successfully connected to relayer

set -euo pipefail

RELAYER_HOST="${1:-localhost}"
RELAYER_URL="http://${RELAYER_HOST}:8000"
API_KEY="${RELAYER_API_KEY:-${API_KEY:-}}"

if [ -z "$API_KEY" ]; then
    echo "❌ Missing RELAYER_API_KEY (or API_KEY) in environment"
    echo "Export before running: export RELAYER_API_KEY=<your-api-key>"
    exit 1
fi

AUTH_HEADER="Authorization: Bearer ${API_KEY}"

echo "🔍 Checking provider registration status..."
echo "Using relayer: $RELAYER_URL"

# Check if any nodes are registered
echo ""
echo "=== ACTIVE NODES ==="
curl -s -H "$AUTH_HEADER" "${RELAYER_URL}/api/v1/nodes" | jq -r '.nodes[]? | "\(.node_id): \(.hardware_spec.cpu_threads) CPU, \(.hardware_spec.ram_gb)GB RAM, GPU: \(.hardware_spec.gpu_info // "None")"' 2>/dev/null || {
    echo "❌ Could not fetch node list"
    exit 1
}

echo ""
echo "=== NODE COUNT ==="
node_count=$(curl -s -H "$AUTH_HEADER" "${RELAYER_URL}/api/v1/nodes" | jq -r '.nodes | length' 2>/dev/null || echo "0")
echo "Total registered nodes: $node_count"

if [ "$node_count" -gt 0 ]; then
    echo "✅ Providers are successfully registering"
else
    echo "❌ No providers registered - check WebSocket connectivity"
fi

echo ""
echo "=== GPU NODES ==="
gpu_count=$(curl -s -H "$AUTH_HEADER" "${RELAYER_URL}/api/v1/nodes" | jq -r '.nodes[]? | select(.hardware_spec.gpu_info != null) | .node_id' 2>/dev/null | wc -l || echo "0")
echo "GPU-capable nodes: $gpu_count"

if [ "$gpu_count" -gt 0 ]; then
    echo "✅ GPU nodes detected - 'No GPU compute nodes online' should be resolved"
else
    echo "⚠️  No GPU nodes detected yet"
fi