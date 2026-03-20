#!/usr/bin/env python3
"""
Smainer System Health Checker
Verifies all components with actual HTTP requests and reports structured status.
"""

import asyncio
import json
import os
import sys
import time
from datetime import datetime, timezone
from typing import Dict, Any, Optional

try:
    import httpx
    import requests
except ImportError:
    print("Installing required packages...")
    import subprocess
    subprocess.run([sys.executable, "-m", "pip", "install", "httpx", "requests"], check=True)
    import httpx
    import requests

class HealthChecker:
    def __init__(self):
        self.timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
        self.results = {}
    
    def log(self, component: str, status: str, evidence: str):
        """Log component status with evidence"""
        self.results[component] = {
            "status": status,
            "evidence": evidence,
            "timestamp": self.timestamp
        }
        print(f"[{self.timestamp}] {component}: {status}")
        print(f"  Evidence: {evidence}")
        print()
    
    def check_relayer_local(self):
        """Check Relayer running locally"""
        try:
            response = requests.get("http://localhost:8000/health", timeout=5)
            if response.status_code == 200:
                self.log("Relayer (Local)", "HEALTHY", 
                        f"HTTP {response.status_code}: {response.text[:100]}")
            else:
                self.log("Relayer (Local)", "DEGRADED", 
                        f"HTTP {response.status_code}: {response.text[:100]}")
        except Exception as e:
            self.log("Relayer (Local)", "DOWN", f"Connection failed: {str(e)}")
    
    def check_relayer_production(self):
        """Check Relayer on DigitalOcean production"""
        endpoints = [
            "https://api.smainer.ai/health",
            "https://api.smainer.ai/api/v1/health",
            "https://api.smainer.io/health",
            "https://api.smainer.io/api/v1/health"
        ]
        
        for endpoint in endpoints:
            try:
                response = requests.get(endpoint, timeout=10)
                if response.status_code == 200:
                    self.log("Relayer (Production)", "HEALTHY", 
                            f"HTTP {response.status_code} from {endpoint}: {response.text[:100]}")
                    return
                elif response.status_code in [404, 405]:
                    continue  # Try next endpoint
                else:
                    self.log("Relayer (Production)", "DEGRADED", 
                            f"HTTP {response.status_code} from {endpoint}")
                    return
            except Exception as e:
                continue
        
        self.log("Relayer (Production)", "UNVERIFIED", 
                "All endpoints unreachable or returned 404")
    
    def check_telegram_bot_local(self):
        """Check Telegram bot locally"""
        try:
            response = requests.get("http://localhost:8100/health", timeout=5)
            if response.status_code == 200:
                self.log("Telegram Bot (Local)", "HEALTHY", 
                        f"HTTP {response.status_code}: {response.text[:100]}")
            else:
                self.log("Telegram Bot (Local)", "DEGRADED", 
                        f"HTTP {response.status_code}: {response.text[:100]}")
        except Exception as e:
            self.log("Telegram Bot (Local)", "DOWN", f"Connection failed: {str(e)}")
    
    def check_miniapp_vercel(self):
        """Check MiniApp on Vercel"""
        urls = [
            "https://smainer-miniapp.vercel.app/",
            "https://smainer-miniapp.vercel.app/connect"
        ]
        
        for url in urls:
            try:
                response = requests.head(url, timeout=10)
                route = url.split('/')[-1] or 'root'
                if response.status_code == 200:
                    self.log(f"MiniApp ({route})", "HEALTHY", 
                            f"HTTP {response.status_code} from {url}")
                else:
                    self.log(f"MiniApp ({route})", "DEGRADED", 
                            f"HTTP {response.status_code} from {url}")
            except Exception as e:
                route = url.split('/')[-1] or 'root'
                self.log(f"MiniApp ({route})", "DOWN", f"Connection failed: {str(e)}")
    
    def check_frontend_vercel(self):
        """Check Frontend on Vercel"""
        try:
            response = requests.head("https://app.smainer.io/", timeout=10)
            if response.status_code == 200:
                self.log("Frontend", "HEALTHY", 
                        f"HTTP {response.status_code} from https://app.smainer.io/")
            else:
                self.log("Frontend", "DEGRADED", 
                        f"HTTP {response.status_code} from https://app.smainer.io/")
        except Exception as e:
            self.log("Frontend", "DOWN", f"Connection failed: {str(e)}")

    def check_provider_runpod_status(self):
        """Check if we can verify RunPod provider status"""
        # This would require SSH access which we don't have from local machine
        self.log("Provider (RunPod)", "UNVERIFIED", 
                "Cannot verify from local machine - requires SSH access to RunPod")

    def generate_summary(self):
        """Generate final summary report"""
        print("="*60)
        print("SMAINER SYSTEM HEALTH SUMMARY")
        print("="*60)
        
        healthy = sum(1 for r in self.results.values() if r["status"] == "HEALTHY")
        degraded = sum(1 for r in self.results.values() if r["status"] == "DEGRADED") 
        down = sum(1 for r in self.results.values() if r["status"] == "DOWN")
        unverified = sum(1 for r in self.results.values() if r["status"] == "UNVERIFIED")
        
        print(f"Components Checked: {len(self.results)}")
        print(f"✅ Healthy: {healthy}")
        print(f"🟡 Degraded: {degraded}")
        print(f"❌ Down: {down}")
        print(f"❓ Unverified: {unverified}")
        print()
        
        for component, result in self.results.items():
            status_icon = {
                "HEALTHY": "✅",
                "DEGRADED": "🟡", 
                "DOWN": "❌",
                "UNVERIFIED": "❓"
            }.get(result["status"], "❓")
            print(f"{status_icon} {component}: {result['status']}")
        
        print(f"\nVerified at: {self.timestamp}")

def main():
    checker = HealthChecker()
    
    print("Starting Smainer System Health Check...")
    print("="*60)
    
    # Check each component
    checker.check_relayer_local()
    checker.check_relayer_production()
    checker.check_telegram_bot_local() 
    checker.check_miniapp_vercel()
    checker.check_frontend_vercel()
    checker.check_provider_runpod_status()
    
    # Generate summary
    checker.generate_summary()

if __name__ == "__main__":
    main()