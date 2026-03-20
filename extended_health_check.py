#!/usr/bin/env python3
"""
Extended health check including RunPod provider and local frontend
"""

import requests
import subprocess
import sys
from datetime import datetime, timezone

def check_local_frontend():
    """Check local frontend on port 5173"""
    try:
        response = requests.get("http://localhost:5173/", timeout=5)
        if response.status_code == 200:
            print("✅ Local Frontend (5173): HEALTHY")
            print(f"  Evidence: HTTP {response.status_code}")
        else:
            print("🟡 Local Frontend (5173): DEGRADED") 
            print(f"  Evidence: HTTP {response.status_code}")
    except Exception as e:
        print("❌ Local Frontend (5173): DOWN")
        print(f"  Evidence: {str(e)}")

def check_runpod_provider():
    """Attempt to check RunPod provider status via SSH"""
    print("Checking RunPod Provider...")
    
    # Check if we can SSH to RunPod
    ssh_cmd = [
        "ssh", 
        "-i", "/home/smainer/.ssh/runpod_smainer",
        "-o", "ConnectTimeout=10",
        "-o", "StrictHostKeyChecking=no",
        "vrh09kn5mzzjq5-64410b1d@ssh.runpod.io",
        "echo 'SSH connection successful'"
    ]
    
    try:
        result = subprocess.run(ssh_cmd, capture_output=True, text=True, timeout=15)
        if result.returncode == 0:
            print("✅ RunPod SSH: ACCESSIBLE")
            print(f"  Evidence: {result.stdout.strip()}")
            
            # Now check if provider daemon is running
            daemon_check_cmd = [
                "ssh", 
                "-i", "/home/smainer/.ssh/runpod_smainer",
                "-o", "ConnectTimeout=10",
                "-o", "StrictHostKeyChecking=no",
                "vrh09kn5mzzjq5-64410b1d@ssh.runpod.io",
                "pgrep -f 'provider|daemon' || echo 'No provider process found'"
            ]
            
            daemon_result = subprocess.run(daemon_check_cmd, capture_output=True, text=True, timeout=15)
            if daemon_result.returncode == 0 and daemon_result.stdout.strip():
                if "No provider process found" in daemon_result.stdout:
                    print("❌ RunPod Provider Daemon: DOWN")
                    print(f"  Evidence: {daemon_result.stdout.strip()}")
                else:
                    print("✅ RunPod Provider Daemon: RUNNING")
                    print(f"  Evidence: PID(s): {daemon_result.stdout.strip()}")
            else:
                print("❓ RunPod Provider Status: UNVERIFIED")
                print("  Evidence: Could not check daemon status")
        else:
            print("❌ RunPod SSH: INACCESSIBLE")
            print(f"  Evidence: SSH failed: {result.stderr.strip()}")
            
    except subprocess.TimeoutExpired:
        print("❌ RunPod SSH: TIMEOUT")
        print("  Evidence: SSH connection timed out after 15 seconds")
    except Exception as e:
        print("❌ RunPod SSH: ERROR")
        print(f"  Evidence: {str(e)}")

def check_telegram_webhook():
    """Check Telegram bot webhook configuration"""
    # Read telegram bot env file to get token
    try:
        with open("/home/smainer/Smainer/telegram/telegram-bot/.env", "r") as f:
            content = f.read()
            
        # Look for token (but don't print it)
        if "TELEGRAM_BOT_TOKEN=" in content:
            print("✅ Telegram Bot Token: CONFIGURED")
            print("  Evidence: TELEGRAM_BOT_TOKEN found in .env")
            
            # Try to get webhook info (would need the actual token, so just report presence)
            print("❓ Telegram Webhook: REQUIRES_MANUAL_CHECK")
            print("  Evidence: Use 'curl -s https://api.telegram.org/bot<TOKEN>/getWebhookInfo' to verify")
        else:
            print("❌ Telegram Bot Token: MISSING")
            print("  Evidence: No TELEGRAM_BOT_TOKEN in .env file")
            
    except Exception as e:
        print("❌ Telegram Bot Config: UNREADABLE")
        print(f"  Evidence: {str(e)}")

def main():
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    print(f"Extended System Health Check - {timestamp}")
    print("="*60)
    
    check_local_frontend()
    print()
    check_runpod_provider() 
    print()
    check_telegram_webhook()

if __name__ == "__main__":
    main()