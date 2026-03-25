#!/bin/bash
set -e
echo "=PULL="
cd /workspace/smainer-backend
git pull origin chore/live-test-fixes-20260320 2>&1 | tail -5

echo "=KILL="
if [ -f /root/provider-daemon.pid ]; then
    kill $(cat /root/provider-daemon.pid) 2>/dev/null || true
    rm -f /root/provider-daemon.pid
fi
pkill -f "python.*enhanced_api_client" 2>/dev/null || true
pkill -f "python.*provider.main" 2>/dev/null || true
sleep 2

echo "=ENV="
cd /workspace/smainer-backend/provider
if ! grep -q STARKNET_ACCOUNT_ADDRESS .env 2>/dev/null; then
    echo 'STARKNET_ACCOUNT_ADDRESS=0x071cd50ddd9a2d0e1e95e6decd9f0a292b489dc6b9b13e68aac43b2295b626d6' >> .env
    echo "Added STARKNET_ACCOUNT_ADDRESS"
else
    echo "STARKNET_ACCOUNT_ADDRESS already in .env"
fi
grep STARKNET_ACCOUNT_ADDRESS .env

echo "=VERIFY_CONFIG="
wc -l /workspace/smainer-backend/provider/src/provider/config.py
grep -n STARKNET_ACCOUNT_ADDRESS /workspace/smainer-backend/provider/src/provider/config.py | head -5

echo "=START="
source /workspace/smainer-backend/provider/venv/bin/activate 2>/dev/null || true
cd /workspace/smainer-backend/provider
nohup python -m provider.enhanced_api_client > /root/provider.log 2>&1 &
BGPID=$!
echo $BGPID > /root/provider-daemon.pid
echo "Provider started with PID $BGPID"
sleep 4

echo "=RUNNING="
ps aux | grep enhanced_api_client | grep -v grep || echo "NOT RUNNING"

echo "=LOGS="
tail -25 /root/provider.log 2>/dev/null || echo "No log file"
echo "=DONE="
