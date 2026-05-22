# Smainer Provider Host Bootstrap Runbook

**Target Host:** 10.100.102.208  
**Package Version:** 1.0.0  
**Date:** May 4, 2026

## Overview

This bootstrap package installs and configures the Smainer Provider daemon on host 10.100.102.208. The package includes dependency installation, secure configuration, systemd service setup, and verification tools.

## Prerequisites

- Ubuntu 20.04+ or Debian 11+ on target host
- Root/sudo access
- Network connectivity to Smainer relayer
- Starknet private key for provider identity

## Quick Start

```bash
# 1. Copy bootstrap package to target host
scp -r deployment/host-bootstrap/ user@10.100.102.208:/tmp/

# 2. SSH to target host  
ssh user@10.100.102.208

# 3. Navigate to bootstrap directory
cd /tmp/host-bootstrap

# 4. Make scripts executable
chmod +x *.sh

# 5. Run installation sequence
sudo ./install-dependencies.sh
sudo ./configure-env.sh
sudo ./install-systemd.sh
sudo ./verify-setup.sh
```

## Detailed Installation Steps

### Step 1: Install Dependencies

```bash
sudo ./install-dependencies.sh
```

**What it does:**
- Creates system user `smainer`
- Installs Python 3.11, virtual environment, and system dependencies
- Creates directory structure in `/opt/smainer-provider`
- Sets up secure sandbox directory at `/var/lib/smainer-provider/sandbox`
- Installs Python packages (starknet-py, websockets, psutil, etc.)
- Configures basic firewall rules

**Expected output:**
```
✅ Installation completed successfully!

📋 Summary:
   • System user: smainer
   • Install directory: /opt/smainer-provider
   • Python venv: /opt/smainer-provider/venv
   • Sandbox directory: /var/lib/smainer-provider/sandbox (700 permissions)
   • Logs: /var/log/smainer-provider
```

**Time:** ~5-10 minutes

### Step 2: Configure Environment

```bash
sudo ./configure-env.sh
```

**What it does:**
- Prompts for configuration values (relayer URL, node ID, etc.)
- Securely collects Starknet private key (no echo to screen)
- Creates environment file with restricted permissions
- Validates private key format

**Required inputs:**
- **Relayer WebSocket URL** (default: `ws://relay.smainer.com:8000`)
- **Node ID** (default: auto-generated unique ID)
- **Starknet Private Key** (64-character hex, required)
- **Performance settings** (defaults provided)

**Expected output:**
```
✅ Environment configuration completed successfully!

📋 Summary:
   • Main config: /opt/smainer-provider/config/.env (600 permissions)
   • Systemd config: /opt/smainer-provider/config/systemd.env (644 permissions)
   • Owner: smainer

⚠️  Security Notes:
   • Private key is stored in /opt/smainer-provider/config/.env with restricted permissions
   • Only the smainer user can read the configuration
   • Systemd environment file contains no secrets
```

**Time:** ~2-3 minutes

### Step 3: Install Systemd Service

```bash
sudo ./install-systemd.sh
```

**What it does:**
- Creates systemd service file with security hardening
- Installs daemon control script
- Enables service for auto-start at boot
- Creates convenient management symlinks

**Expected output:**
```
✅ Systemd service installation completed successfully!

📋 Summary:
   • Service file: /etc/systemd/system/smainer-provider.service
   • Control script: /usr/local/bin/provider-daemon
   • Service name: smainer-provider
   • User: smainer
   • Auto-start: enabled

🔧 Service Management Commands:
   provider-daemon start      # Start the service
   provider-daemon stop       # Stop the service
   provider-daemon status     # Check status
   provider-daemon logs       # Follow live logs
```

**Time:** ~1 minute

### Step 4: Verify Setup

```bash
sudo ./verify-setup.sh
```

**What it does:**
- Comprehensive verification of all installation components
- Tests service startup and shutdown
- Verifies network connectivity to relayer
- Checks Python module imports
- Validates security settings
- Generates detailed verification report

**Expected output:**
```
🔍 SMAINER PROVIDER VERIFICATION REPORT
=======================================
Date: Sat May  4 10:30:00 UTC 2026
Host: hostname (10.100.102.208)

[... detailed verification results ...]

✅ Verification completed!

Share this log file for support: /tmp/provider-verification-20260504_103000.log
```

**Time:** ~2-3 minutes

## Service Management

### Start the Provider Daemon

```bash
# Start the service
sudo provider-daemon start

# Check status
sudo provider-daemon status

# Follow live logs
sudo provider-daemon logs
```

### Stop the Provider Daemon

```bash
# Graceful stop
sudo provider-daemon stop

# Emergency kill (if graceful stop fails)
sudo provider-daemon kill
```

### Check Status

```bash
# Service status
sudo provider-daemon status

# Last 100 log entries
sudo provider-daemon logs-tail

# System resource usage
sudo ps aux | grep provider
sudo systemctl status smainer-provider
```

## Expected Success Output

### Successful Daemon Start
```
● smainer-provider.service - Smainer Provider Daemon
   Loaded: loaded (/etc/systemd/system/smainer-provider.service; enabled)
   Active: active (running) since Sat 2026-05-04 10:30:00 UTC; 5s ago
 Main PID: 1234 (python)
   Status: "Connected to relayer, ready for tasks"
```

### Successful Relayer Connection
```
2026-05-04 10:30:01 [INFO] Starting Smainer Provider Daemon
2026-05-04 10:30:01 [INFO] Node ID: provider-hostname-1714821001
2026-05-04 10:30:01 [INFO] Connecting to relayer: ws://relay.smainer.com:8000
2026-05-04 10:30:02 [INFO] WebSocket connected successfully
2026-05-04 10:30:02 [INFO] Provider registered with relayer
2026-05-04 10:30:02 [INFO] Ready to receive tasks (max_concurrent: 2)
```

### Resource Usage (Normal Operation)
- **CPU:** 0.1-1.0% (idle), 10-50% (processing tasks)
- **Memory:** 50-100MB (base), up to configured limit during tasks
- **Network:** Minimal heartbeat traffic, spikes during task execution

## Troubleshooting

### Common Issues

#### 1. Service Won't Start
```bash
# Check detailed status
sudo systemctl status smainer-provider -l

# Check logs
sudo journalctl -u smainer-provider -n 50

# Common causes:
# - Configuration file permissions
# - Missing environment variables
# - Network connectivity to relayer
```

#### 2. Can't Connect to Relayer
```bash
# Test connectivity
curl -v http://relay.smainer.com:8000/health

# Check firewall
sudo ufw status
sudo iptables -L

# Verify configuration
sudo -u smainer cat /opt/smainer-provider/config/.env | grep RELAYER_WS_URL
```

#### 3. Permission Errors
```bash
# Check directory ownership
ls -la /opt/smainer-provider/
ls -la /var/lib/smainer-provider/
ls -la /var/log/smainer-provider/

# Fix permissions
sudo chown -R smainer:smainer /opt/smainer-provider/
sudo chown -R smainer:smainer /var/lib/smainer-provider/
sudo chown -R smainer:smainer /var/log/smainer-provider/
```

### Emergency Recovery

#### Force Stop and Clean Restart
```bash
# Emergency stop
sudo provider-daemon kill

# Clean restart
sudo systemctl daemon-reload
sudo systemctl restart smainer-provider

# Monitor startup
sudo provider-daemon logs
```

#### Configuration Reset
```bash
# Back up current config
sudo cp /opt/smainer-provider/config/.env /opt/smainer-provider/config/.env.backup

# Reconfigure
sudo ./configure-env.sh
```

## File Locations

| Component | Location | Permissions | Owner |
|-----------|----------|-------------|-------|
| Main installation | `/opt/smainer-provider/` | 750 | smainer:smainer |
| Environment config | `/opt/smainer-provider/config/.env` | 600 | smainer:smainer |
| Systemd service | `/etc/systemd/system/smainer-provider.service` | 644 | root:root |
| Control script | `/usr/local/bin/provider-daemon` | 755 | root:root |
| Logs | `/var/log/smainer-provider/` | 750 | smainer:smainer |
| Sandbox | `/var/lib/smainer-provider/sandbox` | 700 | smainer:smainer |
| PID file | `/var/run/smainer-provider.pid` | 644 | smainer:smainer |

## Security Notes

1. **Private Key Protection:** Stored in `/opt/smainer-provider/config/.env` with 600 permissions
2. **Sandbox Isolation:** Tasks run in isolated directory with restricted permissions
3. **Systemd Hardening:** Service runs with multiple security restrictions
4. **Network Security:** Only required ports allowed through firewall
5. **User Isolation:** Daemon runs as unprivileged `smainer` user

## Support Information

If you encounter issues:

1. **Generate verification report:**
   ```bash
   sudo ./verify-setup.sh
   ```

2. **Collect logs:**
   ```bash
   sudo provider-daemon logs-tail > provider-logs.txt
   sudo journalctl -u smainer-provider -n 200 > systemd-logs.txt
   ```

3. **System information:**
   ```bash
   uname -a > system-info.txt
   df -h >> system-info.txt
   free -h >> system-info.txt
   ```

Share these files for debugging assistance.

## Rollback/Uninstall

### Stop and Disable Service
```bash
sudo provider-daemon stop
sudo systemctl disable smainer-provider
sudo rm /etc/systemd/system/smainer-provider.service
sudo systemctl daemon-reload
```

### Remove Installation
```bash
sudo rm -rf /opt/smainer-provider/
sudo rm -rf /var/lib/smainer-provider/
sudo rm -rf /var/log/smainer-provider/
sudo rm /usr/local/bin/provider-daemon
sudo userdel smainer
```

### Clean Firewall Rules
```bash
sudo ufw delete allow 8000/tcp
```

---

**End of Runbook**