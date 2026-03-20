---
name: systemd-service-hardening
description: "Use when generating systemd service files or deployment scripts for the Smainer stack."
argument-hint: "Systemd limits, hardening, deployment scripts..."
user-invocable: true
disable-model-invocation: false
---

# Systemd Service Hardening

Derived from live production issues tracking mount namespace crashes.

## 1. Mount Namespace Safety 
- AVOID `/tmp` sandboxes for Systemd. `PrivateTmp=true` causes severe namespace collision (status 226/NAMESPACE). 
- Use `/var/lib/smainer-provider/sandbox` instead. Ensure filesystem rules block traversal.
- Map exactly these properties: `ReadWritePaths=/var/lib/smainer-provider` and `StateDirectory=smainer-provider`.

## 2. Resource Constraints (Cgroups)
Smainer is multi-tenant by default. Systemd limits must be dynamically populated during deploy.
```ini
# Template variables: calculate 50-80% of machine bounds
MemoryMax=2G
MemoryHigh=1.8G
CPUQuota=200%
TasksMax=100
```

## 3. Deployment Topology
Always enforce the 3-script deployment topology (avoids monolithic breakage):
1. `setup-provider-service.sh` (Create system user and root paths)
2. `troubleshoot-provider-service.sh` (Test run the binary manually toggling constraints)
3. `deploy-provider-service.sh` (Daemon-reload and bind link to system start)