# DigitalOcean Droplet Operations Runbook

**Droplet Info:**
- Public IP: `138.197.11.147`
- Private IP: `10.108.0.2`
- Domain: `api.smainer.io`
- Service: Smainer Relayer (FastAPI + uvicorn)

---

## 1. SSH Access

### Basic Connection
```bash
ssh root@138.197.11.147
# OR using domain
ssh root@api.smainer.io
```

### Key-based Authentication (Recommended)
```bash
ssh -i ~/.ssh/smainer_do_key root@138.197.11.147
```

### Emergency Console Access
- DigitalOcean Console via web dashboard
- Recovery mode if SSH fails

---

## 2. Service Health Checks

### Quick Health Status
```bash
# Primary health endpoint
curl -f https://api.smainer.io/api/v1/health
# Expected: {"status": "healthy", "version": "...", "timestamp": "..."}

# Local health check (from droplet)
curl -f http://127.0.0.1:8000/api/v1/health
```

### Systemd Service Management
```bash
# Check relayer service status
sudo systemctl status smainer-relayer
sudo systemctl is-active smainer-relayer
sudo systemctl is-enabled smainer-relayer

# Check nginx proxy status
sudo systemctl status nginx
sudo systemctl is-active nginx

# View recent service logs
sudo journalctl -u smainer-relayer --since "1 hour ago"
sudo journalctl -u nginx --since "1 hour ago"
```

### Manual Process Verification
```bash
# Find relayer processes
ps aux | grep -E "(uvicorn|relayer)" | grep -v grep
pgrep -f "uvicorn.*relayer"

# Check listening ports
ss -tulnp | grep -E ":(8000|80|443)"
netstat -tulnp | grep -E ":(8000|80|443)"

# Resource usage
top -p $(pgrep -f uvicorn)
htop -p $(pgrep -f uvicorn)
```

---

## 3. Log Monitoring

### Application Logs
```bash
# Relayer application logs (systemd)
sudo journalctl -u smainer-relayer -f
sudo journalctl -u smainer-relayer --since "2 hours ago" | tail -100

# Direct log files (if configured)
sudo tail -f /var/log/smainer/relayer.log
sudo tail -f /var/log/smainer/error.log

# Search for errors in logs
sudo journalctl -u smainer-relayer --since "1 hour ago" | grep -iE "(error|exception|failed)"
```

### Nginx Logs
```bash
# Access and error logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# API-specific logs (if configured)
sudo tail -f /var/log/nginx/api.smainer.io.access.log
sudo tail -f /var/log/nginx/api.smainer.io.error.log

# WebSocket connection logs
sudo grep -E "websocket|upgrade" /var/log/nginx/access.log | tail -20
```

### System Logs
```bash
# System messages
sudo tail -f /var/log/syslog | grep -E "(smainer|relayer)"
sudo dmesg | tail -50

# Resource exhaustion indicators
sudo grep -E "(out of memory|killed process)" /var/log/syslog
```

---

## 4. Port & Firewall Verification

### Active Listeners
```bash
# All listening services
sudo ss -tulnp
sudo netstat -tulnp

# Key ports for Smainer
sudo ss -tulnp | grep -E ":(80|443|8000)"
```

### Firewall Status
```bash
# UFW firewall
sudo ufw status verbose
sudo ufw status numbered

# iptables (if UFW not used)
sudo iptables -L -n -v
sudo iptables -L INPUT -n --line-numbers
```

### External Connectivity Tests
```bash
# Test from external host
curl -I https://api.smainer.io/api/v1/health
curl -I http://api.smainer.io  # Should redirect to HTTPS

# WebSocket connectivity test
wscat -c wss://api.smainer.io/api/v1/ws/provider
# OR using curl
curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" \
     -H "Sec-WebSocket-Key: test" -H "Sec-WebSocket-Version: 13" \
     https://api.smainer.io/api/v1/ws/provider
```

---

## 5. Restart Procedures

### Systemd Service Restart
```bash
# Graceful restart
sudo systemctl reload smainer-relayer
sudo systemctl restart smainer-relayer

# Restart nginx proxy
sudo systemctl reload nginx
sudo systemctl restart nginx

# Check status after restart
sudo systemctl status smainer-relayer nginx
curl -f https://api.smainer.io/api/v1/health
```

### Manual Process Management
```bash
# If running as nohup/background process
# Find PID first
PID=$(pgrep -f "uvicorn.*relayer")
echo "Relayer PID: $PID"

# Graceful shutdown (SIGTERM)
sudo kill -TERM $PID
sleep 5

# Force kill if needed (SIGKILL)
sudo kill -KILL $PID

# Restart manually (example)
cd /opt/smainer-relayer
nohup python -m uvicorn relayer.main:app --host 127.0.0.1 --port 8000 > /var/log/smainer/relayer.log 2>&1 &

# Or using screen/tmux
screen -S relayer
cd /opt/smainer-relayer && python -m uvicorn relayer.main:app --host 127.0.0.1 --port 8000
# Ctrl+A, D to detach
```

### Environment Activation
```bash
# If using Python virtual environment
cd /opt/smainer-relayer
source .venv/bin/activate  # OR source venv/bin/activate
python -m uvicorn relayer.main:app --host 127.0.0.1 --port 8000
```

---

## 6. SSL Certificate Management

### Let's Encrypt Certificate Status
```bash
# Check certificate validity
sudo certbot certificates
openssl x509 -in /etc/letsencrypt/live/api.smainer.io/fullchain.pem -text -noout | grep -E "(Not Before|Not After)"

# Test certificate renewal
sudo certbot renew --dry-run

# Manual renewal if needed
sudo certbot renew --force-renewal
sudo systemctl reload nginx
```

### Certificate Files Location
```bash
# Standard Let's Encrypt paths
ls -la /etc/letsencrypt/live/api.smainer.io/
# Should contain: cert.pem, chain.pem, fullchain.pem, privkey.pem
```

---

## 7. Resource Monitoring

### System Resources
```bash
# CPU and memory usage
htop
free -h
df -h

# Disk I/O
iostat -x 1 5
iotop

# Network usage
iftop
nethogs
```

### Application-Specific Monitoring
```bash
# Python process memory
ps aux --sort=-%mem | head -20
pmap -x $(pgrep -f uvicorn)

# File descriptor usage
lsof -p $(pgrep -f uvicorn) | wc -l

# Database connections (if applicable)
ss -o state established '( sport = :postgresql or sport = :redis )'
```

---

## 8. Troubleshooting Checklist

### Service Not Responding
1. **Check service status**: `sudo systemctl status smainer-relayer`
2. **Verify process running**: `pgrep -f uvicorn`
3. **Check logs for errors**: `sudo journalctl -u smainer-relayer --since "1 hour ago"`
4. **Test local endpoint**: `curl http://127.0.0.1:8000/api/v1/health`
5. **Check nginx configuration**: `sudo nginx -t`
6. **Verify firewall**: `sudo ufw status`

### High Resource Usage
1. **Check memory**: `free -h` and `ps aux --sort=-%mem`
2. **Check CPU**: `top` or `htop`
3. **Check disk space**: `df -h`
4. **Check logs for spikes**: `sudo journalctl -u smainer-relayer --since "2 hours ago"`
5. **Consider restart**: If memory leak suspected

### SSL/TLS Issues
1. **Check certificate expiry**: `sudo certbot certificates`
2. **Test TLS handshake**: `openssl s_client -connect api.smainer.io:443`
3. **Verify nginx SSL config**: `sudo nginx -t`
4. **Check Let's Encrypt logs**: `sudo tail -f /var/log/letsencrypt/letsencrypt.log`

### WebSocket Connection Issues
1. **Check nginx WebSocket config**: Ensure `proxy_http_version 1.1` and upgrade headers
2. **Test WebSocket endpoint**: `wscat -c wss://api.smainer.io/api/v1/ws/provider`
3. **Check for WebSocket errors in logs**: `grep -i websocket /var/log/nginx/error.log`
4. **Verify relayer WebSocket handling**: Check application logs for WebSocket events

---

## 9. Success Criteria

### Healthy System Indicators
-  **HTTP 200 from health endpoint**: `curl -f https://api.smainer.io/api/v1/health`
-  **SSL certificate valid**: At least 30 days until expiry
-  **Services active**: Both `smainer-relayer` and `nginx` show "active (running)"
-  **No error logs**: No critical errors in last hour of logs
-  **Resource usage normal**: CPU < 80%, Memory < 80%, Disk < 90%
-  **WebSocket connectivity**: Can establish WebSocket connection
-  **External access**: HTTPS redirects working, API accessible from internet

### Performance Benchmarks
- **Response time**: Health endpoint responds < 200ms
- **Memory usage**: Relayer process < 512MB under normal load
- **Log volume**: < 100MB/hour under normal operation
- **Connection count**: < 1000 concurrent connections

---

## 10. Emergency Contacts & Escalation

### Quick Commands Reference
```bash
# Emergency restart everything
sudo systemctl restart smainer-relayer nginx
curl -f https://api.smainer.io/api/v1/health

# Check if only relayer is running (no bot processes)
ps aux | grep -E "(bot|telegram)" | grep -v grep
# Should return empty - only relayer runs on DO

# View capable nodes endpoint
curl -f https://api.smainer.io/api/v1/ai/capable-nodes
```

### Configuration File Locations
- **Relayer config**: `/opt/smainer-relayer/.env` or environment variables
- **Nginx config**: `/etc/nginx/sites-available/api.smainer.io`
- **SSL certificates**: `/etc/letsencrypt/live/api.smainer.io/`
- **Service files**: `/etc/systemd/system/smainer-relayer.service`

### Key Environment Variables to Verify
```bash
# From relayer process environment
sudo cat /proc/$(pgrep -f uvicorn)/environ | tr '\0' '\n' | grep -E "STARKNET|DATABASE|REDIS|API"
```

**Note**: Never include actual private keys or secrets in logs or output. Use placeholders like `STARKNET_PRIVATE_KEY=0x****...****` when documenting.