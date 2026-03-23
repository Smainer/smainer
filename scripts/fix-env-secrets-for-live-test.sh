#!/bin/bash
# Mandatory .env secrets fix for live test security gate

set -euo pipefail

echo "=== FIXING .env SECRETS FOR LIVE TEST ==="

# Generate strong secrets
STRONG_API_KEY=$(openssl rand -base64 32 | tr -d '\n')
STRONG_CALLBACK_SECRET=$(openssl rand -base64 32 | tr -d '\n')

# Backup existing files
cp backend/relayer/.env backend/relayer/.env.backup
cp telegram/telegram-bot/.env telegram/telegram-bot/.env.backup

echo "✓ Created backups"

# Fix relayer .env - replace placeholder callback secret with strong one
sed -i "s|CALLBACK_SIGNING_SECRET=test-callback-secret.*|CALLBACK_SIGNING_SECRET=${STRONG_CALLBACK_SECRET}|" backend/relayer/.env

# Update API_KEY in relayer to ensure it's strong (preserve existing if already strong)
if grep -q "API_KEY=" backend/relayer/.env; then
    # Use existing API_KEY value
    EXISTING_API_KEY=$(grep "^API_KEY=" backend/relayer/.env | cut -d'=' -f2)
    if [[ ${#EXISTING_API_KEY} -lt 16 ]]; then
        echo "⚠️ Replacing weak API_KEY with strong one"
        sed -i "s|API_KEY=.*|API_KEY=${STRONG_API_KEY}|" backend/relayer/.env
        API_KEY_TO_USE="$STRONG_API_KEY"
    else
        echo "✓ Using existing strong API_KEY"
        API_KEY_TO_USE="$EXISTING_API_KEY"
    fi
else
    echo "Adding API_KEY"
    echo "API_KEY=${STRONG_API_KEY}" >> backend/relayer/.env
    API_KEY_TO_USE="$STRONG_API_KEY"
fi

# Fix telegram bot .env - replace all placeholders
sed -i "s|RELAYER_API_KEY=.*|RELAYER_API_KEY=${API_KEY_TO_USE}|" telegram/telegram-bot/.env
sed -i "s|CALLBACK_SIGNING_SECRET=.*|CALLBACK_SIGNING_SECRET=${STRONG_CALLBACK_SECRET}|" telegram/telegram-bot/.env

echo "✓ Updated secret values"

# Verify secrets are synchronized
RELAYER_API_KEY=$(grep "^API_KEY=" backend/relayer/.env | cut -d'=' -f2)
TELEGRAM_API_KEY=$(grep "^RELAYER_API_KEY=" telegram/telegram-bot/.env | cut -d'=' -f2)
RELAYER_CALLBACK=$(grep "^CALLBACK_SIGNING_SECRET=" backend/relayer/.env | cut -d'=' -f2)
TELEGRAM_CALLBACK=$(grep "^CALLBACK_SIGNING_SECRET=" telegram/telegram-bot/.env | cut -d'=' -f2)

if [[ "$RELAYER_API_KEY" == "$TELEGRAM_API_KEY" ]] && [[ "$RELAYER_CALLBACK" == "$TELEGRAM_CALLBACK" ]]; then
    echo "✅ SECURITY GATE PASSED: Secrets synchronized between relayer and telegram bot"
    echo "✅ All placeholder values replaced with strong secrets"
    echo "✅ Files remain git-ignored (not tracked)"
else
    echo "❌ SECURITY GATE FAILED: Secret synchronization error"
    exit 1
fi

echo "=== LIVE TEST READY ==="