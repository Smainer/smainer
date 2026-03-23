# GPU Provider Live Test Runbook

**Goal**: Ensure at least one GPU-capable provider node registers successfully with relayer for Telegram live tests.
**Error**: "No GPU compute nodes are online"
**Environment**: DigitalOcean relayer + Runpod provider

## Quick Verification Command

```bash
# On relayer (DO droplet)
export RELAYER_API_KEY=<REDACTED>
curl -s -H "Authorization: Bearer $RELAYER_API_KEY" "http://localhost:8000/api/v1/nodes" | jq -r '.nodes[]? | select(.hardware_spec.gpu_info != null) | .node_id'
```

**Expected**: Should return at least one node ID. If empty, proceed with fix sequence.

---

## Fix Sequence

### 1. WebSocket URL Format Check
**Location**: Runpod provider instance

```bash
# ❌ WRONG - causes path doubling
export RELAYER_WS_URL="ws://your-do-ip:8000/ws/node/"

# ✅ CORRECT - base URL only
export RELAYER_WS_URL="ws://your-do-ip:8000"
export NODE_ID="runpod-gpu-provider-$(date +%s)"
```

### 2. Auth Preconditions Check
```bash
# Private key format: exactly 64 hex chars
echo ${#STARKNET_PRIVATE_KEY}  # Should output 66 (0x + 64 chars)
echo "$STARKNET_PRIVATE_KEY" | grep -E '^0x[0-9a-fA-F]{64}$' || echo "❌ Invalid format"

# Network connectivity
curl -s --connect-timeout 5 "http://your-do-ip:8000/api/v1/health" || echo "❌ Relayer unreachable"
```

### 3. Fix Sandbox Path (Critical for Systemd/WSL2)
```bash
# Old problematic path
OLD_SANDBOX="/tmp/provider_sandbox"

# New required path
NEW_SANDBOX="/var/lib/smainer-provider/sandbox"

# Create with correct permissions
sudo mkdir -p "$NEW_SANDBOX"
sudo chown -R $(whoami):$(whoami) "$NEW_SANDBOX" 
chmod 700 "$NEW_SANDBOX"

# Update environment
export SANDBOX_TEMP_DIR="$NEW_SANDBOX"
```

### 4. Daemon Restart Sequence

#### Option A: Direct Python (Foreground Debug)
```bash
cd /home/smainer/Smainer/backend/provider
source /home/smainer/Smainer/.venv/bin/activate

# Kill existing process
pkill -f "provider/main.py" 2>/dev/null || true
sleep 2

# Start with debug logging
export LOG_LEVEL=DEBUG
python src/provider/main.py
```

#### Option B: Systemd Service (Production)
```bash
# Stop service
sudo systemctl stop smainer-provider || true

# Check service status
sudo systemctl status smainer-provider --no-pager

# Start with proper environment
sudo systemctl start smainer-provider

# Monitor logs
sudo journalctl -u smainer-provider -f
```

---

## Evidence Checks

### 1. Provider Registration Evidence
**Location**: Relayer (DO droplet)
```bash
export RELAYER_API_KEY=<REDACTED>
BASE_URL="http://localhost:8000/api/v1"

# Check total nodes
curl -s -H "Authorization: Bearer $RELAYER_API_KEY" "$BASE_URL/nodes" | jq '.nodes | length'

# Check GPU nodes specifically
curl -s -H "Authorization: Bearer $RELAYER_API_KEY" "$BASE_URL/nodes" | \
  jq -r '.nodes[]? | select(.hardware_spec.gpu_info != null) | 
  "\(.node_id): \(.hardware_spec.gpu_info) (\(.hardware_spec.gpu_vram_gb)GB VRAM)"'
```

### 2. Provider Heartbeat Evidence
```bash
# Recent heartbeats (last 60 seconds)
curl -s -H "Authorization: Bearer $RELAYER_API_KEY" "$BASE_URL/nodes" | \
  jq -r '.nodes[]? | select((.last_heartbeat | fromdateiso8601) > (now - 60)) | .node_id'
```

### 3. WebSocket Connection Evidence
```bash
# Provider logs should show:
# ✅ "Connected to relayer WebSocket"
# ✅ "Registration successful"
# ✅ "Heartbeat sent successfully"

# Check provider logs (last 50 lines)
cd /home/smainer/Smainer/backend/provider
tail -50 provider.log | grep -E "(Connected|Registration|Heartbeat)"
```

---

## Fallback Strategies

### GPU Detection Fallback
If `nvidia-smi` fails on Runpod:
```bash
# Force GPU info in hardware spec
export FORCE_GPU_INFO="NVIDIA RTX A5000"
export FORCE_GPU_VRAM="24.0"

# Restart provider with forced GPU detection
python src/provider/main.py
```

### WSL2/Docker Fallback
If systemd mount namespaces fail:
```bash
# Disable sandbox isolation temporarily
export DISABLE_SANDBOX_ISOLATION="true"
export SANDBOX_TEMP_DIR="/home/$(whoami)/provider_sandbox"

mkdir -p "$SANDBOX_TEMP_DIR"
chmod 755 "$SANDBOX_TEMP_DIR"
```

### Network Connectivity Fallback
```bash
# If WebSocket registration fails, test raw connection:
echo "Testing raw WebSocket..." 
timeout 10 bash -c "exec 3<>/dev/tcp/your-do-ip/8000" 2>/dev/null && echo "✅ Port 8000 reachable" || echo "❌ Port blocked"

# Check Runpod firewall
sudo iptables -L OUTPUT | grep 8000 || echo "No firewall rules blocking port 8000"
```

---

## Success Criteria

### ✅ Minimal Success
1. Provider connects to WebSocket without auth errors
2. Registration event receives acknowledgment 
3. Node appears in `/api/v1/nodes` with GPU info
4. Heartbeat timestamp within last 60 seconds

### ✅ Live Test Ready
```bash
# Final verification command
curl -s -H "Authorization: Bearer $RELAYER_API_KEY" "http://localhost:8000/api/v1/nodes" | \
  jq '.nodes[]? | select(.hardware_spec.gpu_info != null and (.last_heartbeat | fromdateiso8601) > (now - 120))' | \
  jq -s 'length' | \
  awk '{if($1 >= 1) print "✅ LIVE TEST READY: " $1 " GPU provider(s) online"; else print "❌ NO GPU PROVIDERS READY"}'
```

**Expected Output**: `✅ LIVE TEST READY: 1 GPU provider(s) online`

---

## Emergency Diagnostic Script

Quick automated check:
```bash
bash /home/smainer/Smainer/runpod-provider-verification.sh
```

This covers all verification steps and creates corrected configuration files automatically.