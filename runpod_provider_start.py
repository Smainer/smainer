#!/usr/bin/env python3
"""Runpod Provider Daemon Starter - Uses pexpect to handle SSH PTY issues"""
import pexpect
import sys
import time

def ssh_runpod_command(command, timeout=30):
    """Execute command on Runpod via SSH using pexpect"""
    ssh_cmd = "ssh -i ~/.ssh/runpod_smainer wumvfgod4894fx-64411be0@ssh.runpod.io"
    
    try:
        print(f"🔗 Connecting to Runpod...")
        child = pexpect.spawn(f'{ssh_cmd} "{command}"', timeout=timeout)
        
        # Enable logging for debugging
        child.logfile = sys.stdout.buffer
        
        # Wait for command to complete
        child.expect(pexpect.EOF)
        child.close()
        
        return child.exitstatus, child.before.decode() if child.before else ""
    except pexpect.TIMEOUT:
        print(f"❌ Command timed out after {timeout} seconds")
        return -1, ""
    except pexpect.EOF:
        return child.exitstatus, ""
    except Exception as e:
        print(f"❌ SSH error: {e}")
        return -1, ""

def main():
    print("🚀 Starting Smainer Provider Daemon on Runpod")
    print("=" * 50)
    
    # 1. Check if daemon is already running
    print("\n1️⃣ Checking if provider daemon is already running...")
    
    status_cmd = """
    echo "=== CHECKING PROVIDER DAEMON STATUS ==="
    ps aux | grep -E "python.*provider" | grep -v grep || echo "No provider daemon found"
    echo ""
    echo "=== CHECKING PID FILE ==="
    if [ -f /root/provider-daemon.pid ]; then
        echo "PID file exists: $(cat /root/provider-daemon.pid)"
        PID=$(cat /root/provider-daemon.pid)
        if kill -0 $PID 2>/dev/null; then
            echo "Process $PID is running"
        else
            echo "Process $PID is NOT running (stale PID file)"
            rm -f /root/provider-daemon.pid
        fi
    else
        echo "No PID file found"
    fi
    echo ""
    echo "=== CHECKING SMAINER DIRECTORY ==="
    ls -la /root/Smainer/backend/provider/ 2>/dev/null || echo "Smainer directory not found"
    """
    
    exit_code, output = ssh_runpod_command(status_cmd)
    print(f"Status check result: {output}")
    
    # 2. Check environment variables
    print("\n2️⃣ Checking environment variables...")
    
    env_cmd = """
    echo "=== CHECKING ENV VARS ==="
    cd /root/Smainer/backend/provider
    if [ -f .env ]; then
        echo "Found .env file:"
        grep -E "^(RELAYER_WS_URL|NODE_ID|STARKNET_PRIVATE_KEY)" .env | sed 's/STARKNET_PRIVATE_KEY=.*/STARKNET_PRIVATE_KEY=***REDACTED***/'
    else
        echo "No .env file found"
    fi
    """
    
    exit_code, output = ssh_runpod_command(env_cmd)
    print(f"Environment check result: {output}")
    
    # 3. Start the provider daemon
    print("\n3️⃣ Starting provider daemon...")
    
    start_cmd = """
    echo "=== STARTING PROVIDER DAEMON ==="
    cd /root/Smainer/backend/provider
    
    # Kill any existing daemon
    if [ -f /root/provider-daemon.pid ]; then
        PID=$(cat /root/provider-daemon.pid)
        if kill -0 $PID 2>/dev/null; then
            echo "Stopping existing daemon (PID: $PID)"
            kill $PID
            sleep 2
        fi
        rm -f /root/provider-daemon.pid
    fi
    
    # Set up environment
    export RELAYER_WS_URL="wss://api.smainer.io"
    export NODE_ID="runpod-a40-provider-001"
    export LOG_LEVEL="INFO"
    export SANDBOX_TEMP_DIR="/tmp/provider_sandbox"
    
    # Load any additional env from .env file
    if [ -f .env ]; then
        source .env
    fi
    
    echo "Starting daemon with:"
    echo "  RELAYER_WS_URL=$RELAYER_WS_URL"
    echo "  NODE_ID=$NODE_ID" 
    echo "  LOG_LEVEL=$LOG_LEVEL"
    echo ""
    
    # Start daemon in background and save PID
    nohup python3 -m provider.main > /root/provider-daemon.log 2>&1 &
    DAEMON_PID=$!
    echo $DAEMON_PID > /root/provider-daemon.pid
    
    echo "✅ Started provider daemon with PID: $DAEMON_PID"
    echo "📝 Logs: /root/provider-daemon.log"
    echo "📁 PID file: /root/provider-daemon.pid"
    
    # Give it a moment to start
    sleep 3
    
    # Check if it's still running
    if kill -0 $DAEMON_PID 2>/dev/null; then
        echo "✅ Daemon is running successfully"
    else
        echo "❌ Daemon failed to start, checking logs:"
        tail -20 /root/provider-daemon.log
    fi
    """
    
    exit_code, output = ssh_runpod_command(start_cmd, timeout=60)
    print(f"Start daemon result: {output}")
    
    # 4. Wait a bit and verify connection
    print("\n4️⃣ Waiting 15 seconds for daemon to connect to relayer...")
    time.sleep(15)
    
    return exit_code == 0

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)