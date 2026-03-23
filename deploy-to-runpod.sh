#!/bin/bash

# Remote Runpod Setup Deployment Script
# Deploys and executes the setup script on the Runpod pod

set -e

RUNPOD_HOST="wumvfgod4894fx-64411be0@ssh.runpod.io"
SSH_KEY="$HOME/.ssh/runpod_smainer"
SETUP_SCRIPT="$(dirname "$(readlink -f "$0")")/runpod-setup.sh"

echo "=== Deploying Smainer Setup to Runpod ==="
echo "Host: $RUNPOD_HOST"
echo "Script: $SETUP_SCRIPT"
echo

if [ ! -f "$SSH_KEY" ]; then
    echo "ERROR: SSH key not found at $SSH_KEY"
    exit 1
fi

if [ ! -f "$SETUP_SCRIPT" ]; then
    echo "ERROR: Setup script not found at $SETUP_SCRIPT"
    exit 1
fi

echo "Copying setup script to Runpod..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SETUP_SCRIPT" "$RUNPOD_HOST:/root/runpod-setup.sh"

echo "Making script executable and running..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$RUNPOD_HOST" "chmod +x /root/runpod-setup.sh && /root/runpod-setup.sh"

echo
echo "=== Deployment Complete ==="
echo "To check logs later:"
echo "ssh -i $SSH_KEY $RUNPOD_HOST 'tail -f /root/provider-daemon.log'"
echo "ssh -i $SSH_KEY $RUNPOD_HOST 'tail -f /root/telegram-bot.log'"