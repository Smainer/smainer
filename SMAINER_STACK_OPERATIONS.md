# Smainer Stack Operational Scripts

Complete one-shot operational package for launching Redis + Relayer + Provider stack with proper secret handling and resource management.

## 🚀 Quick Start

### First-Time Setup
```bash
# Interactive setup (recommended)
scripts/smainer-stack-master.sh deploy

# Manual setup
scripts/setup-smainer-env.sh setup
source .env.smainer-stack
scripts/launch-smainer-stack.sh
```

### Daily Operations
```bash
# Start stack
scripts/smainer-stack-master.sh start

# Check status
scripts/smainer-stack-master.sh status

# Verify all services
scripts/smainer-stack-master.sh verify

# Stop stack
scripts/smainer-stack-master.sh stop

# View logs
scripts/smainer-stack-master.sh logs
```

## 📁 Scripts Overview

### Core Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `smainer-stack-master.sh` | **Main controller** - handles all operations | `./smainer-stack-master.sh <command>` |
| `launch-smainer-stack.sh` | Launches Redis + Relayer + Provider with resource limits | `./launch-smainer-stack.sh` |
| `verify-smainer-stack.sh` | Comprehensive health checks and diagnostics | `./verify-smainer-stack.sh` |
| `stop-smainer-stack.sh` | Graceful shutdown with cleanup | `./stop-smainer-stack.sh [--force]` |
| `setup-smainer-env.sh` | Environment configuration and validation | `./setup-smainer-env.sh setup` |

### Resource Management

- **Half-Hardware Defaults**: Auto-detects system resources and allocates 50% to Smainer stack
- **Redis**: 25% of total system memory
- **Relayer**: Remaining allocated memory with 256MB buffer
- **Provider**: Half of available CPU cores for concurrent tasks

### Security Features

- ✅ **No Secret Exposure**: All secrets handled via environment variables
- ✅ **Input Validation**: Private key format validation without logging values
- ✅ **Sandboxed Execution**: Provider tasks run in isolated directories
- ✅ **Process Limits**: Memory and CPU limits enforced
- ✅ **Secure Defaults**: Production-ready configurations

## 🔧 Environment Configuration

### Required Secrets

Set these environment variables before launching:

```bash
export REDIS_PASSWORD="<your-secure-redis-password>"
export RELAYER_API_SECRET="<your-relayer-api-secret>"
export RELAYER_SIGNING_KEY="<your-64-char-hex-key>"
export STARKNET_ACCOUNT_KEY="<your-64-char-hex-key>"
```

### Optional Configuration

```bash
export NODE_ID="my-provider-node"
export LOG_LEVEL="INFO"
export MAX_CONCURRENT_TASKS="4"
export STARKNET_RPC_URL="https://your-preferred-rpc.com"
```

### Environment Setup Options

```bash
# Generate template with random secrets
scripts/setup-smainer-env.sh generate

# Interactive setup
scripts/setup-smainer-env.sh setup

# Validate existing config
scripts/setup-smainer-env.sh validate

# Load environment
source .env.smainer-stack
```

## 📊 Service Management

### Health Monitoring

```bash
# Quick status check
scripts/smainer-stack-master.sh status

# Comprehensive verification
scripts/smainer-stack-master.sh verify

# Real-time log monitoring
scripts/smainer-stack-master.sh monitor

# Run diagnostic checks
scripts/smainer-stack-master.sh doctor
```

### Troubleshooting

```bash
# Check service logs
scripts/smainer-stack-master.sh logs

# Stop with cleanup
scripts/smainer-stack-master.sh stop --force

# Complete reset
scripts/smainer-stack-master.sh reset

# Manual verification
scripts/verify-smainer-stack.sh --quiet
```

## 🏭 Production Operations

### Deployment Workflow

1. **Setup Environment**
   ```bash
   scripts/setup-smainer-env.sh setup
   # Edit .env.smainer-stack with production secrets
   ```

2. **Validate Configuration**
   ```bash
   scripts/setup-smainer-env.sh validate
   scripts/setup-smainer-env.sh security
   ```

3. **Deploy Stack**
   ```bash
   scripts/smainer-stack-master.sh deploy
   ```

4. **Verify Deployment**
   ```bash
   scripts/smainer-stack-master.sh verify
   ```

### Operations Commands

```bash
# Production deployment
scripts/smainer-stack-master.sh deploy

# Service restart
scripts/smainer-stack-master.sh restart

# Graceful shutdown
scripts/smainer-stack-master.sh stop

# Force shutdown and cleanup
scripts/smainer-stack-master.sh cleanup --force
```

## 📋 Service Details

### Redis Server
- **Port**: 6379 (localhost only)
- **Memory Limit**: Auto-detected (25% of system RAM)
- **Authentication**: Required (REDIS_PASSWORD)
- **Persistence**: AOF enabled
- **Health Check**: `redis-cli ping` with auth

### Relayer API
- **Port**: 8000
- **Workers**: 1 (production-optimized)
- **Health Endpoint**: `http://localhost:8000/api/v1/health`
- **WebSocket**: `ws://localhost:8000/ws`
- **Memory Limit**: Auto-detected with systemd (if available)

### Provider Daemon  
- **Connection**: WebSocket to Relayer
- **Sandbox**: `/tmp/provider_sandbox_$(whoami)`
- **Resource Limits**: CPU time, memory per task
- **Max Tasks**: Auto-detected (50% of CPU cores)
- **Monitoring**: Real-time resource tracking

## 🛡️ Security Considerations

### Secret Management
- Never commit `.env.*` files to version control
- Use strong, unique passwords (>12 characters)
- Private keys must be valid 64-character hex strings
- Secrets are never logged or exposed in output

### Process Security
- Provider tasks run in sandboxed directories
- Resource limits prevent runaway processes
- All services use least-privilege principles
- Network binding to localhost only (production deploys behind proxy)

### System Hardening
- File permissions: `.env` files should be 600 (owner read/write only)
- User isolation: Don't run as root
- Resource monitoring: Automatic detection of resource exhaustion

## 📝 Log Management

### Log Locations
- **All Logs**: `/home/smainer/Smainer/logs/`
- **Redis**: `logs/redis.log`
- **Relayer**: `logs/relayer.log`
- **Provider**: `logs/provider.log`

### Log Operations
```bash
# View recent logs
scripts/smainer-stack-master.sh logs

# Monitor in real-time  
scripts/smainer-stack-master.sh monitor

# Archive logs on stop
scripts/stop-smainer-stack.sh  # Automatically archives

# Manual log checks
tail -f logs/*.log
grep -i error logs/*.log
```

## 🔄 Development Mode

```bash
# Launch with debug logging
scripts/smainer-stack-master.sh dev

# Use development environment
cp .env.smainer-stack .env.dev
# Edit .env.dev with test settings
scripts/smainer-stack-master.sh dev
```

Development mode features:
- Debug-level logging
- Single concurrent task limit
- Batch submission disabled
- Test environment support

## 🚨 Emergency Procedures

### Complete System Reset
```bash
scripts/smainer-stack-master.sh reset
# This will stop all services and remove all configuration
```

### Force Stop Everything
```bash
scripts/stop-smainer-stack.sh --force
# Kills processes, cleans ports, removes temp files
```

### Manual Process Cleanup
```bash
# Find Smainer processes
ps aux | grep -E 'redis.*6379|relayer|provider'

# Kill by PID
kill -9 <PID>

# Check ports
lsof -i :6379
lsof -i :8000
```

## 📞 Support

For issues or questions:

1. **Check logs**: `scripts/smainer-stack-master.sh logs`
2. **Run diagnostics**: `scripts/smainer-stack-master.sh doctor`
3. **Verify configuration**: `scripts/setup-smainer-env.sh validate`
4. **Review this README** for common operations

## 🧪 Testing Your Setup

```bash
# Full deployment test
scripts/smainer-stack-master.sh deploy

# Verify all components
scripts/smainer-stack-master.sh verify

# Test connectivity
curl http://localhost:8000/api/v1/health
redis-cli -a "$REDIS_PASSWORD" ping

# Clean shutdown test
scripts/smainer-stack-master.sh stop
```

---

✅ **Ready for production deployment on DigitalOcean droplets**
🔒 **Secure by default with proper secret management**
⚡ **Optimized for half-hardware resource allocation**
🛠️ **Complete operational lifecycle management**