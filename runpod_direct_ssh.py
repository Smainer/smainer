#!/usr/bin/env python3
"""Direct pexpect SSH to Runpod without shell interpretation"""
import pexpect
import sys
import time

def main():
    print("🚀 Connecting to Runpod directly with pexpect...")
    
    try:
        # Start SSH connection
        ssh_host = "wumvfgod4894fx-64411be0@ssh.runpod.io"
        ssh_key = "/home/smainer/.ssh/runpod_smainer"
        
        print(f"🔗 Spawning SSH: ssh -o StrictHostKeyChecking=no -i {ssh_key} {ssh_host}")
        
        child = pexpect.spawn(f"ssh -o StrictHostKeyChecking=no -i {ssh_key} {ssh_host}")
        child.logfile = sys.stdout.buffer
        
        # Look for common SSH prompts
        index = child.expect([
            "~]#",  # root prompt  
            "~]$",  # user prompt
            "$ ",   # basic prompt
            "# ",   # root prompt
            "> ",   # some prompt
            pexpect.TIMEOUT,
            pexpect.EOF
        ], timeout=20)
        
        if index >= 5:  # timeout or EOF
            print(f"❌ Failed to get shell prompt. Index: {index}")
            if child.before:
                print(f"Output: {child.before.decode()}")
            if child.after:
                print(f"After: {child.after.decode()}")
            return False
            
        print(f"✅ Got shell prompt (index: {index})")
        
        # Execute status commands one by one
        commands = [
            "echo '=== CHECKING PROCESSES ==='",
            "ps aux | grep -E 'python.*provider' | grep -v grep || echo 'No provider daemon found'",
            "echo '=== CHECKING PID FILE ==='", 
            "ls -la /root/provider-daemon.pid 2>/dev/null || echo 'No PID file'",
            "echo '=== CHECKING SMAINER DIRECTORY ==='",
            "ls -la /root/Smainer/backend/provider/ 2>/dev/null | head -5 || echo 'Directory not found'",
            "echo '=== CHECKING ENV FILE ==='",
            "cd /root/Smainer/backend/provider && ls -la .env* 2>/dev/null || echo 'No env files'",
        ]
        
        for cmd in commands:
            child.sendline(cmd)
            child.expect(["~]#", "~]$", "$ ", "# "], timeout=10)
            time.sleep(0.5)
            
        # Now try to start the daemon
        print("\n🚀 Starting provider daemon...")
        
        start_commands = [
            "cd /root/Smainer/backend/provider",
            "export RELAYER_WS_URL='wss://api.smainer.io'",
            "export NODE_ID='runpod-a40-provider-001'",
            "export LOG_LEVEL='INFO'",
            "export SANDBOX_TEMP_DIR='/tmp/provider_sandbox'",
            "# Kill any existing daemon",
            "pkill -f 'python.*provider.main' || echo 'No existing daemon'",
            "rm -f /root/provider-daemon.pid",
            "# Start the daemon",
            "nohup python3 -m provider.main > /root/provider-daemon.log 2>&1 &",
            "echo $! > /root/provider-daemon.pid",
            "sleep 3",
            "echo 'Daemon PID:' $(cat /root/provider-daemon.pid 2>/dev/null || echo 'No PID file')",
            "ps aux | grep -E 'python.*provider' | grep -v grep || echo 'Daemon not found in process list'"
        ]
        
        for cmd in start_commands:
            if cmd.startswith("#"):
                continue
            print(f"Executing: {cmd}")
            child.sendline(cmd)
            child.expect(["~]#", "~]$", "$ ", "# "], timeout=15)
            time.sleep(1)
            
        # Check logs
        child.sendline("tail -20 /root/provider-daemon.log 2>/dev/null || echo 'No log file'")
        child.expect(["~]#", "~]$", "$ ", "# "], timeout=10)
        
        child.close()
        return True
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    success = main()
    print(f"\n{'✅ SUCCESS' if success else '❌ FAILED'}")
    sys.exit(0 if success else 1)