#!/bin/bash

# Runpod Provider Daemon & Telegram Bot Setup Script
# Usage: Run this directly on the Runpod pod after SSH'ing in

set -e

echo "=== Smainer Runpod Setup Starting ==="
echo "Date: $(date)"
echo "Hostname: $(hostname)"
echo

echo "=== STEP 1: Environment Assessment ==="
echo "Root directory contents:"
ls -la /root/

echo
echo "GPU Status:"
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader || echo "GPU check failed"

echo
echo "Python Status:"
python3 --version
pip --version

echo
echo "=== STEP 2: Checking for Existing Repositories ==="

# Check for existing code from migration
PROVIDER_PATH=""
TELEGRAM_PATH=""

if [ -d "/root/Smainer-backend" ]; then
    PROVIDER_PATH="/root/Smainer-backend"
    echo "Found Smainer-backend at $PROVIDER_PATH"
elif [ -d "/root/smainer-backend" ]; then
    PROVIDER_PATH="/root/smainer-backend"
    echo "Found smainer-backend at $PROVIDER_PATH"
elif [ -d "/root/Smainer/backend" ]; then
    PROVIDER_PATH="/root/Smainer/backend"
    echo "Found Smainer/backend at $PROVIDER_PATH"
else
    echo "No existing provider code found - will clone"
fi

if [ -d "/root/smainer-telegram" ]; then
    TELEGRAM_PATH="/root/smainer-telegram"
    echo "Found smainer-telegram at $TELEGRAM_PATH"
elif [ -d "/root/Smainer/telegram" ]; then
    TELEGRAM_PATH="/root/Smainer/telegram"
    echo "Found Smainer/telegram at $TELEGRAM_PATH"
else
    echo "No existing telegram code found - will clone"
fi

echo
echo "=== STEP 3: Setting up Provider Daemon ==="

# Clone or use existing provider code
if [ -z "$PROVIDER_PATH" ]; then
    echo "Cloning provider repository..."
    cd /root
    git clone https://github.com/Smainer/smainer-backend.git || {
        echo "Failed to clone smainer-backend, creating minimal setup..."
        mkdir -p /root/smainer-backend/provider/src/provider
        PROVIDER_PATH="/root/smainer-backend"
    }
    PROVIDER_PATH="/root/smainer-backend"
fi

cd "$PROVIDER_PATH"
echo "Working in provider directory: $(pwd)"

# Install Python dependencies
echo "Installing provider dependencies..."
if [ -f "provider/requirements.txt" ]; then
    pip install -r provider/requirements.txt
elif [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
else
    echo "Installing basic dependencies..."
    pip install websockets starknet-py pydantic pydantic-settings aiohttp
fi

# Set up provider configuration
cd "$PROVIDER_PATH/provider" 2>/dev/null || cd "$PROVIDER_PATH"

echo "Checking provider .env configuration..."
if [ -f ".env" ]; then
    echo "Existing .env found:"
    cat .env | grep -v STARKNET_PRIVATE_KEY || true
else
    echo "Creating provider .env..."
    cat > .env << 'ENVEOF'
RELAYER_WS_URL=wss://api.smainer.io
NODE_ID=runpod-a40-provider-001
MAX_CONCURRENT_TASKS=2
LOG_LEVEL=INFO
SANDBOX_TEMP_DIR=/tmp/provider_sandbox
HEARTBEAT_INTERVAL=30
ENVEOF
    echo "Created basic .env - STARKNET_PRIVATE_KEY needs to be added manually"
fi

# Create sandbox directory
echo "Creating sandbox directory..."
mkdir -p /tmp/provider_sandbox

# Start provider daemon
echo "Starting provider daemon..."
PROVIDER_MAIN=""
if [ -f "src/provider/main.py" ]; then
    PROVIDER_MAIN="src/provider/main.py"
elif [ -f "provider/main.py" ]; then
    PROVIDER_MAIN="provider/main.py"
elif [ -f "main.py" ]; then
    PROVIDER_MAIN="main.py"
else
    echo "WARNING: Could not find provider main.py"
fi

if [ ! -z "$PROVIDER_MAIN" ]; then
    # Kill existing provider if running
    if [ -f "/root/provider-daemon.pid" ]; then
        kill $(cat /root/provider-daemon.pid) 2>/dev/null && echo "Killed existing provider daemon"
        rm -f /root/provider-daemon.pid
    fi
    
    echo "Starting provider daemon from $PROVIDER_MAIN..."
    nohup python3 -u "$PROVIDER_MAIN" > /root/provider-daemon.log 2>&1 &
    echo $! > /root/provider-daemon.pid
    echo "Provider daemon started with PID $(cat /root/provider-daemon.pid)"
else
    echo "SKIPPING: Provider daemon start (main.py not found)"
fi

echo
echo "=== STEP 4: Setting up Telegram Bot ==="

# Clone or use existing telegram code
if [ -z "$TELEGRAM_PATH" ]; then
    echo "Cloning telegram repository..."
    cd /root
    git clone https://github.com/Smainer/smainer-telegram.git || {
        echo "Failed to clone smainer-telegram, creating minimal setup..."
        mkdir -p /root/smainer-telegram/bot
        TELEGRAM_PATH="/root/smainer-telegram"
    }
    TELEGRAM_PATH="/root/smainer-telegram"
fi

cd "$TELEGRAM_PATH"
echo "Working in telegram directory: $(pwd)"

# Install Telegram dependencies
echo "Installing telegram dependencies..."
if [ -f "bot/requirements.txt" ]; then
    pip install -r bot/requirements.txt
elif [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
else
    echo "Installing basic telegram dependencies..."
    pip install python-telegram-bot aiohttp
fi

# TELEGRAM_BOT_TOKEN must be injected as an environment variable before running this script
# e.g.: export TELEGRAM_BOT_TOKEN="your-token-here"
if [ -z "${TELEGRAM_BOT_TOKEN:-}" ]; then
    echo "WARNING: TELEGRAM_BOT_TOKEN is not set. Bot will not start correctly."
    echo "Set it before running: export TELEGRAM_BOT_TOKEN=\"<your-bot-token>\""
fi

# Check/create telegram configuration
cd "$TELEGRAM_PATH/bot" 2>/dev/null || cd "$TELEGRAM_PATH"

echo "Checking telegram .env configuration..."
if [ -f ".env" ]; then
    echo "Existing telegram .env found:"
    cat .env | head -5
else
    echo "Creating telegram .env..."
    cat > .env << TENVEOF
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN:-<set-telegram-bot-token>}
RELAYER_API_URL=https://api.smainer.io
CALLBACK_PORT=8081
LOG_LEVEL=INFO
TENVEOF
    echo "Created telegram .env"
fi

# Start telegram bot
echo "Starting telegram bot..."
TELEGRAM_MAIN=""
if [ -f "src/telegram_bot/main.py" ]; then
    TELEGRAM_MAIN="src/telegram_bot/main.py"
elif [ -f "bot/main.py" ]; then
    TELEGRAM_MAIN="bot/main.py"
elif [ -f "main.py" ]; then
    TELEGRAM_MAIN="main.py"
elif [ -f "bot.py" ]; then
    TELEGRAM_MAIN="bot.py"
else
    echo "WARNING: Could not find telegram main.py or bot.py"
fi

if [ ! -z "$TELEGRAM_MAIN" ]; then
    # Kill existing telegram bot if running
    if [ -f "/root/telegram-bot.pid" ]; then
        kill $(cat /root/telegram-bot.pid) 2>/dev/null && echo "Killed existing telegram bot"
        rm -f /root/telegram-bot.pid
    fi
    
    echo "Starting telegram bot from $TELEGRAM_MAIN..."
    nohup python3 -u "$TELEGRAM_MAIN" > /root/telegram-bot.log 2>&1 &
    echo $! > /root/telegram-bot.pid
    echo "Telegram bot started with PID $(cat /root/telegram-bot.pid)"
else
    echo "SKIPPING: Telegram bot start (main.py/bot.py not found)"
fi

echo
echo "=== STEP 5: Verification ==="

sleep 5

# Check processes
echo "Process status:"
ps aux | grep -E "(provider|telegram)" | grep -v grep || echo "No provider/telegram processes found"

# Check logs
echo
echo "Provider daemon log (last 10 lines):"
if [ -f "/root/provider-daemon.log" ]; then
    tail -10 /root/provider-daemon.log
else
    echo "No provider daemon log found"
fi

echo
echo "Telegram bot log (last 10 lines):"
if [ -f "/root/telegram-bot.log" ]; then
    tail -10 /root/telegram-bot.log
else
    echo "No telegram bot log found"
fi

# Check relayer connection
echo
echo "Checking relayer connectivity:"
curl -s https://api.smainer.io/api/v1/nodes | python3 -m json.tool 2>/dev/null || echo "Failed to connect to relayer"

echo
echo "NFT endpoints check:"
curl -s https://api.smainer.io/api/v1/nft/stats/marketplace 2>/dev/null || echo "NFT stats endpoint failed" 
curl -s https://api.smainer.io/api/v1/nft/listings 2>/dev/null || echo "NFT listings endpoint failed"

# GPU final check
echo
echo "GPU specification:"
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader || echo "GPU query failed"

echo
echo "=== Setup Complete ==="
echo "Provider daemon PID: $(cat /root/provider-daemon.pid 2>/dev/null || echo 'N/A')"
echo "Telegram bot PID: $(cat /root/telegram-bot.pid 2>/dev/null || echo 'N/A')"
echo
echo "Next steps:"
echo "1. Check logs: tail -f /root/provider-daemon.log"
echo "2. Check logs: tail -f /root/telegram-bot.log"
echo "3. Verify STARKNET_PRIVATE_KEY in provider .env if needed"
echo "4. Test Telegram bot: Send /start to @SMainer_bot"