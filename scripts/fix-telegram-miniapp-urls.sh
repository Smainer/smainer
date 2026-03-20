#!/usr/bin/env bash
set -euo pipefail

# Fix Telegram Bot URL Configuration for Open App/Connect Wallet 404s
# Usage: ./scripts/fix-telegram-miniapp-urls.sh [miniapp_base_url] [relayer_url] [frontend_url]

# Configuration with defaults
MINIAPP_BASE_URL="${1:-https://smainer-miniapp.vercel.app}"
RELAYER_URL="${2:-https://api.smainer.io}"
FRONTEND_URL="${3:-https://smainer.io}"
BOT_USERNAME="${BOT_USERNAME:-smainer_ai_bot}"

echo "🔧 Fixing Telegram Bot URL Configuration..."
echo "  MINIAPP_URL: $MINIAPP_BASE_URL"
echo "  RELAYER_URL: $RELAYER_URL" 
echo "  FRONTEND_URL: $FRONTEND_URL"

# Step 1: Fix bot environment URLs
echo
echo "📱 1. Updating bot environment..."
cd /home/smainer/Smainer/telegram/telegram-bot

# Use existing fix script
if [ -f "./fix-miniapp-url-404.sh" ]; then
    # Existing script handles MINIAPP_URL, MINIAPP_OPEN_URL, MINIAPP_CONNECT_URL
    ./fix-miniapp-url-404.sh "$MINIAPP_BASE_URL"
else
    # Manual fix if script missing
    echo "  - Setting MINIAPP_URL=$MINIAPP_BASE_URL"
    echo "  - Setting MINIAPP_OPEN_URL=$MINIAPP_BASE_URL"
    echo "  - Setting MINIAPP_CONNECT_URL=$MINIAPP_BASE_URL/?mode=connect"
    
    if grep -q "^MINIAPP_URL=" .env; then
        sed -i "s|^MINIAPP_URL=.*|MINIAPP_URL=$MINIAPP_BASE_URL|" .env
    else
        echo "MINIAPP_URL=$MINIAPP_BASE_URL" >> .env
    fi
    
    if grep -q "^MINIAPP_OPEN_URL=" .env; then
        sed -i "s|^MINIAPP_OPEN_URL=.*|MINIAPP_OPEN_URL=$MINIAPP_BASE_URL|" .env
    else
        echo "MINIAPP_OPEN_URL=$MINIAPP_BASE_URL" >> .env
    fi
    
    if grep -q "^MINIAPP_CONNECT_URL=" .env; then
        sed -i "s|^MINIAPP_CONNECT_URL=.*|MINIAPP_CONNECT_URL=$MINIAPP_BASE_URL/?mode=connect|" .env
    else
        echo "MINIAPP_CONNECT_URL=$MINIAPP_BASE_URL/?mode=connect" >> .env
    fi
fi

# Step 2: Fix miniapp environment URLs  
echo
echo "🌐 2. Updating miniapp environment..."
cd /home/smainer/Smainer/telegram/miniapp

# Update or add VITE_RELAYER_URL
if grep -q "^VITE_RELAYER_URL=" .env.local; then
    sed -i "s|^VITE_RELAYER_URL=.*|VITE_RELAYER_URL=$RELAYER_URL|" .env.local
else
    echo "VITE_RELAYER_URL=$RELAYER_URL" >> .env.local
fi

# Update or add VITE_FRONTEND_URL (critical for "Open Full App" button)
if grep -q "^VITE_FRONTEND_URL=" .env.local; then
    sed -i "s|^VITE_FRONTEND_URL=.*|VITE_FRONTEND_URL=$FRONTEND_URL|" .env.local
else
    echo "VITE_FRONTEND_URL=$FRONTEND_URL" >> .env.local
fi

# Update or add VITE_TELEGRAM_BOT_USERNAME
if grep -q "^VITE_TELEGRAM_BOT_USERNAME=" .env.local; then
    sed -i "s|^VITE_TELEGRAM_BOT_USERNAME=.*|VITE_TELEGRAM_BOT_USERNAME=$BOT_USERNAME|" .env.local
else
    echo "VITE_TELEGRAM_BOT_USERNAME=$BOT_USERNAME" >> .env.local
fi

echo "  ✓ Updated miniapp environment"

# Step 3: Verify URLs are accessible
echo
echo "🔍 3. Verifying URL accessibility..."

# Test miniapp base URL
if command -v curl >/dev/null 2>&1; then
    echo -n "  - Testing $MINIAPP_BASE_URL: "
    if curl -fsS --max-time 10 "$MINIAPP_BASE_URL" >/dev/null 2>&1; then
        echo "✅ OK"
    else
        echo "❌ FAIL - Miniapp may not be deployed!"
        echo "    Deploy miniapp first: cd telegram/miniapp && npm run build && vercel"
    fi
    
    echo -n "  - Testing $MINIAPP_BASE_URL/?mode=connect: " 
    if curl -fsS --max-time 10 "$MINIAPP_BASE_URL/?mode=connect" >/dev/null 2>&1; then
        echo "✅ OK"
    else
        echo "❌ FAIL"
    fi
else
    echo "  - curl not available, skipping URL tests"
fi

# Step 4: Restart services if they exist
echo
echo "🔄 4. Restarting services..."

# Check for systemd services
RESTART_NEEDED=false
for service in telegram-bot smainer-telegram-bot; do
    if systemctl is-enabled "$service" >/dev/null 2>&1; then
        echo "  - Restarting $service..."
        sudo systemctl restart "$service"
        sudo systemctl status "$service" --no-pager -l | head -5
        RESTART_NEEDED=true
    fi
done

# Check for running processes  
if pgrep -f "telegram.*bot" >/dev/null 2>&1; then
    echo "  - Found running telegram bot processes"
    echo "  - Manual restart may be needed"
    RESTART_NEEDED=true
fi

if [ "$RESTART_NEEDED" = false ]; then
    echo "  - No active services found"
    echo "  - Start bot manually if needed"
fi

# Step 5: Rebuild miniapp if needed
echo
echo "🔨 5. Miniapp rebuild (if needed)..."
cd /home/smainer/Smainer/telegram/miniapp

if [ -d "node_modules" ] && command -v npm >/dev/null 2>&1; then
    echo "  - Rebuilding miniapp with new environment..."
    npm run build
    echo "  ✓ Miniapp rebuilt"
    echo "  - Deploy to Vercel: vercel --prod"
else
    echo "  - Run: cd telegram/miniapp && npm install && npm run build && vercel --prod"
fi

echo
echo "✅ Fix complete!"
echo
echo "🧪 Next steps for testing:"
echo "1. In Telegram, send /start to bot"  
echo "2. Tap 'Connect Wallet' button - should open miniapp, not 404"
echo "3. From bot menu, tap 'Open App' - should open miniapp, not 404"  
echo "4. In miniapp, 'Open Full App' should link to frontend"
echo
echo "🔧 If issues persist:"
echo "- Check bot token: cd telegram && ./verify-telegram-bot-token.sh"
echo "- Update BotFather menu: /setmenubutton -> $MINIAPP_BASE_URL"
echo "- Check Vercel deployment logs"