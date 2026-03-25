#!/bin/bash
# Runpod diagnostic script - runs on the pod

echo "=== PROVIDER PROCESSES ==="
pgrep -fa "provider\|python.*main" 2>/dev/null || echo "No provider processes found"

echo "=== GPU STATUS ==="
nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu --format=csv,noheader 2>&1

echo "=== PID FILE ==="
cat /root/provider-daemon.pid 2>/dev/null || echo "NO_PID_FILE"

echo "=== UPTIME ==="
uptime

echo "=== PROVIDER LOGS ==="
if [ -f /root/smainer-backend/provider/provider.log ]; then
    tail -30 /root/smainer-backend/provider/provider.log
elif [ -f /root/smainer-backend/provider/nohup.out ]; then
    tail -30 /root/smainer-backend/provider/nohup.out
else
    echo "No provider log files found"
    find /root/smainer-backend/provider/ -name "*.log" -o -name "nohup.out" 2>/dev/null
fi

echo "=== PROVIDER ENV (redacted) ==="
if [ -f /root/smainer-backend/provider/.env ]; then
    sed -E 's/(KEY|SECRET|PASSWORD|TOKEN|MNEMONIC|PRIVATE)=.*/\1=<REDACTED>/gi' /root/smainer-backend/provider/.env
else
    echo "No .env file found"
    find /root/smainer-backend/ -name ".env" 2>/dev/null
fi

echo "=== PROVIDER DIR CONTENTS ==="
ls -la /root/smainer-backend/provider/ 2>/dev/null | head -20

echo "=== NETWORK CONNECTIONS TO RELAYER ==="
ss -tp 2>/dev/null | grep -i "smainer\|8000\|443" | head -5 || echo "ss not available"

echo "=== ALLDONE ==="
