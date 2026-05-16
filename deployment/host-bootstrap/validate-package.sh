#!/bin/bash
# Bootstrap Package Validation Script  
# Purpose: Verify package integrity before deployment to target host

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔍 SMAINER PROVIDER BOOTSTRAP PACKAGE VALIDATION"
echo "================================================"
echo "Package Directory: $SCRIPT_DIR"
echo "Date: $(date)"
echo ""

# Check required files exist
REQUIRED_FILES=(
    "install-dependencies.sh"
    "configure-env.sh" 
    "install-systemd.sh"
    "verify-setup.sh"
    "README.md"
    "RUNBOOK.md"
)

echo "📋 1. REQUIRED FILES CHECK"
echo "=========================="
for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$SCRIPT_DIR/$file" ]]; then
        echo "   ✅ $file"
    else
        echo "   ❌ $file (missing)"
        exit 1
    fi
done

echo ""
echo "🔧 2. SCRIPT PERMISSIONS CHECK"
echo "=============================="
for script in *.sh; do
    if [[ -x "$script" ]]; then
        PERMS=$(stat -c "%a" "$script")
        echo "   ✅ $script (permissions: $PERMS)"
    else
        echo "   ❌ $script (not executable)"
        exit 1
    fi
done

echo ""
echo "📝 3. SYNTAX CHECK"
echo "=================="
for script in *.sh; do
    if bash -n "$script"; then
        echo "   ✅ $script (syntax valid)"
    else
        echo "   ❌ $script (syntax error)"
        exit 1
    fi
done

echo ""
echo "🏷️  4. PACKAGE METADATA"
echo "======================="
TOTAL_SIZE=$(du -sh "$SCRIPT_DIR" | cut -f1)
FILE_COUNT=$(find "$SCRIPT_DIR" -type f | wc -l)
echo "   • Total size: $TOTAL_SIZE"
echo "   • File count: $FILE_COUNT"
echo "   • Package directory: $SCRIPT_DIR"

echo ""
echo "📦 5. PROVIDER SOURCE CHECK"
echo "=========================="
PROVIDER_SOURCE="../backend/provider"
if [[ -d "$PROVIDER_SOURCE" ]]; then
    echo "   ✅ Provider source found: $PROVIDER_SOURCE"
    
    # Check key provider files
    PROVIDER_FILES=("pyproject.toml" "src/provider/main.py" "src/provider/config.py")
    for file in "${PROVIDER_FILES[@]}"; do
        if [[ -f "$PROVIDER_SOURCE/$file" ]]; then
            echo "   ✅ $file"
        else
            echo "   ❌ $file (missing from provider source)"
        fi
    done
else
    echo "   ❌ Provider source not found: $PROVIDER_SOURCE"
    echo "   Warning: Manual copy will be required during installation"
fi

echo ""
echo "🎯 6. DEPLOYMENT READINESS CHECK"
echo "==============================="

# Check if we can create archive
if command -v tar &> /dev/null; then
    echo "   ✅ tar available for packaging"
else
    echo "   ⚠️  tar not available"
fi

if command -v scp &> /dev/null; then
    echo "   ✅ scp available for file transfer"
else
    echo "   ⚠️  scp not available"
fi

if command -v ssh &> /dev/null; then
    echo "   ✅ ssh available for remote access"
else
    echo "   ⚠️  ssh not available"
fi

echo ""
echo "💾 7. CREATING DEPLOYMENT ARCHIVE"
echo "================================="

ARCHIVE_NAME="smainer-provider-bootstrap-$(date +%Y%m%d_%H%M%S).tar.gz"
cd "$(dirname "$SCRIPT_DIR")"
tar -czf "$ARCHIVE_NAME" host-bootstrap/

if [[ -f "$ARCHIVE_NAME" ]]; then
    ARCHIVE_SIZE=$(du -sh "$ARCHIVE_NAME" | cut -f1)
    echo "   ✅ Archive created: $ARCHIVE_NAME ($ARCHIVE_SIZE)"
    echo "   📁 Location: $(pwd)/$ARCHIVE_NAME"
else
    echo "   ❌ Failed to create archive"
    exit 1
fi

echo ""
echo "🚀 DEPLOYMENT COMMANDS"
echo "====================="
echo ""
echo "# Copy archive to target host:"
echo "scp $(pwd)/$ARCHIVE_NAME user@10.100.102.208:/tmp/"
echo ""
echo "# SSH to target host and extract:"
echo "ssh user@10.100.102.208"
echo "cd /tmp && tar -xzf $ARCHIVE_NAME"
echo "cd host-bootstrap"
echo ""
echo "# Run installation sequence:"
echo "sudo ./install-dependencies.sh"
echo "sudo ./configure-env.sh"
echo "sudo ./install-systemd.sh" 
echo "sudo ./verify-setup.sh"
echo ""
echo "# Start daemon:"
echo "sudo provider-daemon start"
echo "sudo provider-daemon status"

echo ""
echo "✅ PACKAGE VALIDATION COMPLETED SUCCESSFULLY!"
echo ""
echo "📋 Summary:"
echo "   • All required files present and executable"
echo "   • Scripts have valid syntax"
echo "   • Deployment archive created: $ARCHIVE_NAME"
echo "   • Ready for deployment to 10.100.102.208"
echo ""
echo "Next: Transfer archive to target host and follow RUNBOOK.md"