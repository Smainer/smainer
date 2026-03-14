#!/bin/bash
# EMERGENCY API Key Rotation Playbook
set -e

echo "🔥 EMERGENCY API Key Rotation - Execute Immediately"
echo "Reason: API key potentially exposed in chat/logs"

# Constants
BACKUP_DIR="/tmp/smainer-key-rotation-$(date +%s)"
ENV_FILE="/home/smainer/Smainer/.env"
STAGING_ENV="/home/smainer/Smainer/.env.staging"
PRODUCTION_ENV="/home/smainer/Smainer/.env.production"

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "Step 1: Backing up current configurations..."
cp "$ENV_FILE" "$BACKUP_DIR/env.backup" 2>/dev/null || echo "No .env file found"
cp "$STAGING_ENV" "$BACKUP_DIR/env.staging.backup" 2>/dev/null || echo "No staging env found"
cp "$PRODUCTION_ENV" "$BACKUP_DIR/env.production.backup" 2>/dev/null || echo "No production env found"

echo "Step 2: Generating new API key..."
NEW_API_KEY="sk-$(openssl rand -hex 32)"
echo "New API key: $NEW_API_KEY"

echo "Step 3: Updating environment files..."

# Function to update or add API key in env file
update_api_key() {
    local file="$1"
    local key="$2"
    
    if [ -f "$file" ]; then
        if grep -q "^API_KEY=" "$file"; then
            # Update existing
            sed -i "s/^API_KEY=.*/API_KEY=$key/" "$file"
        else
            # Add new
            echo "API_KEY=$key" >> "$file"
        fi
        echo "Updated $file"
    fi
}

# Update all environment files
update_api_key "$ENV_FILE" "$NEW_API_KEY"
update_api_key "$STAGING_ENV" "$NEW_API_KEY" 
update_api_key "$PRODUCTION_ENV" "$NEW_API_KEY"

echo "Step 4: Restarting services..."

# Kill existing relayer processes
pkill -f "relayer" || echo "No relayer processes found"
pkill -f "provider" || echo "No provider processes found"

# Wait a moment for cleanup
sleep 2

echo "Step 5: Starting services with new key..."
cd /home/smainer/Smainer/backend/relayer
export API_KEY="$NEW_API_KEY"
nohup python -m relayer.main > /tmp/relayer.log 2>&1 &
RELAYER_PID=$!

# Start provider if configured
if [ -f "/home/smainer/Smainer/backend/provider/src/provider/main.py" ]; then
    cd /home/smainer/Smainer/backend/provider
    nohup python -m provider.main > /tmp/provider.log 2>&1 &
    PROVIDER_PID=$!
fi

echo "Step 6: Validating new deployment..."

# Wait for services to start
sleep 5

# Test new API key
echo "Testing new API key..."
HEALTH_CHECK=$(curl -s -w "%{http_code}" \
    -H "Authorization: Bearer $NEW_API_KEY" \
    "http://localhost:8000/health" || echo "FAIL")

if echo "$HEALTH_CHECK" | grep -q "200"; then
    echo "✅ New API key working correctly"
else
    echo "❌ New API key test failed: $HEALTH_CHECK"
    echo "Rolling back..."
    
    # Rollback
    if [ -f "$BACKUP_DIR/env.backup" ]; then
        cp "$BACKUP_DIR/env.backup" "$ENV_FILE"
    fi
    
    # Restart with old config
    kill $RELAYER_PID $PROVIDER_PID 2>/dev/null || true
    echo "Manual intervention required"
    exit 1
fi

echo "Step 7: Security verification..."

# Check that old key is no longer accepted
sleep 2
OLD_KEY_TEST=$(curl -s -w "%{http_code}" \
    -H "Authorization: Bearer dev-api-key" \
    "http://localhost:8000/health" || echo "401")

if echo "$OLD_KEY_TEST" | grep -q "401"; then
    echo "✅ Old key properly rejected"
else
    echo "⚠️  Old key might still be accepted: $OLD_KEY_TEST"
fi

echo "Step 8: Log analysis and cleanup..."

# Check for any remaining instances of old keys in logs
OLD_KEY_PATTERN="dev-api-key\|sk-[a-zA-Z0-9]\{20,64\}"
if find /tmp /var/log -type f -name "*.log" -exec grep -l "$OLD_KEY_PATTERN" {} \; 2>/dev/null | head -5; then
    echo "⚠️  Found old keys in logs - consider log rotation"
fi

echo "Step 9: Notification and documentation..."
cat << EOF > "$BACKUP_DIR/rotation-summary.txt"
API Key Rotation Summary - $(date)
====================================

Reason: Potential key exposure in chat/public logs
Old Key Pattern: dev-api-key, sk-*
New Key: $NEW_API_KEY
Backup Location: $BACKUP_DIR

Services Restarted:
- Relayer: PID $RELAYER_PID
- Provider: PID ${PROVIDER_PID:-"Not running"}

Verification:
- New key test: $(echo "$HEALTH_CHECK" | grep -o "200" || echo "FAILED")
- Old key rejected: $(echo "$OLD_KEY_TEST" | grep -o "401" || echo "FAILED")

Next Steps:
1. Update any external clients with new key
2. Verify frontend/telegram bot configurations
3. Update monitoring/alerting systems
4. Schedule log rotation if needed

EOF

echo "✅ API Key Rotation Complete!"
echo ""
echo "🔔 IMPORTANT NEXT STEPS:"
echo "1. Update any external services using the old API key"
echo "2. Notify team members of the new key via secure channel"
echo "3. Update documentation and runbooks"
echo "4. Consider implementing key rotation automation"
echo ""
echo "📋 Summary written to: $BACKUP_DIR/rotation-summary.txt"
echo "🔑 New API Key: $NEW_API_KEY"
echo ""
echo "🔍 Services Status:"
ps aux | grep -E "(relayer|provider)" | grep -v grep || echo "No services running"