#!/bin/bash
# CRITICAL SECURITY REMEDIATION - Remove Private Keys from .env Files
# Run immediately to address SEC-001 finding

set -e

echo "🔒 CRITICAL SECURITY REMEDIATION - Removing Private Keys from .env Files"
echo "========================================================================="

# Backup files with private keys before modification
BACKUP_DIR="/tmp/smainer_env_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

FILES_WITH_KEYS=(
    "./backend/provider/.env.local"
    "./backend/provider/.env" 
    "./backend/relayer/.env"
    "./backend/relayer/.env.backup"
)

echo "1. Creating backup of files with private keys..."
for file in "${FILES_WITH_KEYS[@]}"; do
    if [[ -f "$file" ]]; then
        echo "   Backing up: $file"
        cp "$file" "$BACKUP_DIR/$(basename "$file").backup"
    fi
done

echo "2. Removing private keys from .env files..."

# Remove private keys from provider .env files
for file in "./backend/provider/.env" "./backend/provider/.env.local"; do
    if [[ -f "$file" ]]; then
        echo "   Securing: $file"
        # Replace actual private key with placeholder
        sed -i 's/STARKNET_PRIVATE_KEY=0x[0-9a-fA-F]*/STARKNET_PRIVATE_KEY=0x_YOUR_PRIVATE_KEY_HERE/g' "$file"
        # Add security warning
        echo "" >> "$file"
        echo "# WARNING: Never commit actual private keys to version control!" >> "$file"
        echo "# Use environment variables or external key management in production" >> "$file"
    fi
done

# Remove private keys from relayer .env files  
for file in "./backend/relayer/.env" "./backend/relayer/.env.backup"; do
    if [[ -f "$file" ]]; then
        echo "   Securing: $file"
        # Replace actual private key with placeholder
        sed -i 's/RELAYER_PRIVATE_KEY=0x[0-9a-fA-F]*/RELAYER_PRIVATE_KEY=0x_YOUR_PRIVATE_KEY_HERE/g' "$file"
        # Add security warning
        echo "" >> "$file"
        echo "# WARNING: Never commit actual private keys to version control!" >> "$file"
        echo "# Use environment variables or external key management in production" >> "$file"
    fi
done

echo "3. Verification - checking for remaining exposed keys..."
REMAINING=$(find . -name ".env*" -not -name "*.example" -not -name "*.template" -exec grep -l "PRIVATE_KEY=0x[0-9a-fA-F]\{40,\}" {} \; || true)

if [[ -n "$REMAINING" ]]; then
    echo "❌ FAILED: Private keys still found in:"
    echo "$REMAINING"
    exit 1
else
    echo "✅ SUCCESS: All private keys have been secured"
fi

echo ""
echo "4. Next Steps:"
echo "   - Backup created at: $BACKUP_DIR"
echo "   - Set private keys via environment variables:"
echo "     export STARKNET_PRIVATE_KEY=0x_your_actual_key_here"
echo "     export RELAYER_PRIVATE_KEY=0x_your_actual_key_here"
echo "   - Update deployment scripts to use environment variables"
echo "   - Consider using secret management tools (AWS Secrets Manager, etc.)"
echo ""
echo "✅ SECURITY REMEDIATION COMPLETE"