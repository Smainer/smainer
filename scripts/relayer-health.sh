#!/bin/bash
# Relayer-specific health check for production deployment
set -e

source .env.prod 2>/dev/null || echo "Warning: .env.prod not found"

RELAYER_URL="http://localhost:8000"
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "=== Relayer Health Check ==="

# HTTP Health
if curl -f -s "$RELAYER_URL/health" > /dev/null; then
    echo -e "${GREEN}✓ HTTP OK${NC}"
else
    echo -e "${RED}✗ HTTP FAILED${NC}"
    exit 1
fi

# Redis connectivity  
if docker exec smainer-redis redis-cli -a "$REDIS_PASSWORD" ping | grep -q PONG; then
    echo -e "${GREEN}✓ Redis OK${NC}"
else
    echo -e "${RED}✗ Redis FAILED${NC}"
    exit 1
fi

# WebSocket test (simple)
if timeout 5 python3 -c "
import asyncio, websockets, json, sys
async def test(): 
    async with websockets.connect('ws://localhost:8000/ws') as ws:
        await ws.send(json.dumps({'type':'ping'}))
        resp = await ws.recv()
        assert 'pong' in resp
asyncio.run(test())
" 2>/dev/null; then
    echo -e "${GREEN}✓ WebSocket OK${NC}"
else
    echo -e "${RED}✗ WebSocket FAILED${NC}"
fi

echo "Health check complete"