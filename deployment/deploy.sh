#!/bin/bash
# Smainer Production Deployment Script
# Execute on DigitalOcean server: smainer@138.197.11.147

set -euo pipefail

echo "🚀 Starting Smainer Production Deployment..."

# Constants
DEPLOY_DIR="/opt/smainer"
GIT_REPO="https://github.com/Smainer/Smainer.git"
DOMAIN="api.smainer.ai"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# 1. System Updates and Preparation
log_info "Step 1: System updates and preparation..."
sudo apt update && sudo apt upgrade -y
sudo reboot && log_info "System rebooted. Reconnect and run this script again."

# 2. Clone Repository
log_info "Step 2: Cloning Smainer repository..."
if [ ! -d "$DEPLOY_DIR" ]; then
    sudo mkdir -p "$DEPLOY_DIR" 
    sudo chown smainer:smainer "$DEPLOY_DIR"
    cd "$DEPLOY_DIR"
    git clone "$GIT_REPO" .
else
    cd "$DEPLOY_DIR"
    git pull origin main
fi

# 3. Security Validation
log_info "Step 3: Running security validation..."
if ! "$DEPLOY_DIR/scripts/security-validation.sh"; then
    log_error "Security validation failed. Deployment blocked."
    exit 1
fi

# 4. Generate Production Secrets
log_info "Step 4: Generating production secrets..."
cd "$DEPLOY_DIR/deployment"

if [ ! -f ".env.prod" ]; then
    cp .env.prod.template .env.prod
    
    # Generate secure secrets
    REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-25)
    API_KEY="sk-$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-25)"
    CALLBACK_SIGNING_SECRET="cb-$(openssl rand -base64 48 | tr -d '=+/' | cut -c1-40)"
    
    # Update .env.prod with generated secrets
    sed -i "s/REPLACE_WITH_SECURE_PASSWORD/$REDIS_PASSWORD/g" .env.prod
    sed -i "s/REPLACE_WITH_SECURE_API_KEY/$API_KEY/g" .env.prod
    sed -i "s/REPLACE_WITH_SECURE_CALLBACK_SIGNING_SECRET/$CALLBACK_SIGNING_SECRET/g" .env.prod
    
    # Set secure permissions
    chmod 600 .env.prod
    
    log_warn "⚠️  IMPORTANT: Update .env.prod with your actual RELAYER_PRIVATE_KEY"
    log_info "Generated production secrets and stored them in .env.prod"
fi

# 5. Deploy Redis and Relayer
log_info "Step 5: Deploying Redis and Relayer services..."
cd "$DEPLOY_DIR/deployment"

# Build and start services
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build

# Wait for services to start
sleep 10

# 6. Create systemd service for auto-restart
log_info "Step 6: Creating systemd services..."
sudo tee /etc/systemd/system/smainer-stack.service > /dev/null <<'EOF'
[Unit]
Description=Smainer Production Stack
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/smainer/deployment
ExecStart=/usr/bin/docker compose -f docker-compose.prod.yml --env-file .env.prod up -d
ExecStop=/usr/bin/docker compose -f docker-compose.prod.yml --env-file .env.prod down
User=smainer
Group=smainer

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable smainer-stack.service

# 7. Deploy Telegram Bot
log_info "Step 7: Deploying Telegram Bot..."
cd "$DEPLOY_DIR"

# Install Python dependencies
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
cd telegram/telegram-bot && pip install -e ".[dev]"

# Create bot environment (copy from template)
if [ ! -f ".env" ]; then
    cp .env.example .env
    chmod 600 .env
    log_warn "⚠️  IMPORTANT: Update telegram-bot/.env with your TELEGRAM_BOT_TOKEN"
fi

# Create systemd service for Telegram bot
sudo tee /etc/systemd/system/smainer-telegram-bot.service > /dev/null <<EOF
[Unit]
Description=Smainer Telegram Bot
After=network-online.target smainer-stack.service
Wants=network-online.target

[Service]
Type=simple
User=smainer
WorkingDirectory=$DEPLOY_DIR/telegram/telegram-bot
EnvironmentFile=$DEPLOY_DIR/telegram/telegram-bot/.env
ExecStart=$DEPLOY_DIR/.venv/bin/python -m src.telegram_bot.main
Restart=always
RestartSec=5
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable smainer-telegram-bot.service

# 8. Configure Nginx Reverse Proxy
log_info "Step 8: Configuring Nginx reverse proxy..."
sudo apt install -y nginx certbot python3-certbot-nginx

sudo tee /etc/nginx/sites-available/smainer > /dev/null <<'EOF'
server {
    listen 80;
    server_name api.smainer.ai;

    # Security headers
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Rate limiting
    limit_req zone=api_limit burst=20 nodelay;
    limit_req_status 429;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}

# Rate limiting config
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
EOF

sudo ln -sf /etc/nginx/sites-available/smainer /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl enable nginx && sudo systemctl restart nginx

# 9. Set up SSL with Let's Encrypt
log_info "Step 9: Setting up SSL certificate..."
if [ "$DOMAIN" != "api.smainer.ai" ] || read -p "Do you want to configure SSL for $DOMAIN? (y/n): " -n 1 -r && [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email admin@smainer.ai
fi

# 10. Configure Firewall
log_info "Step 10: Configuring firewall..."
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

# 11. Final Service Startup
log_info "Step 11: Starting all services..."
sudo systemctl start smainer-stack.service
sleep 5
sudo systemctl start smainer-telegram-bot.service

# 12. Health Checks
log_info "Step 12: Running health checks..."
echo ""
log_info "=== SERVICE STATUS ==="
sudo systemctl status smainer-stack.service --no-pager || true
echo ""
sudo systemctl status smainer-telegram-bot.service --no-pager || true
echo ""

log_info "=== DOCKER SERVICES ==="
docker ps

log_info "=== HEALTH CHECK ==="
sleep 5
curl -sS http://127.0.0.1:8000/api/v1/health || log_warn "Relayer health check failed"

log_info "=== NETWORK PORTS ==="
ss -tulpen | grep -E ':(22|80|443|8000|6379|8100)' || true

log_info "=== FAIL2BAN STATUS ==="
sudo fail2ban-client status sshd || true

echo ""
log_info "🎉 Deployment complete!"
log_info "Next steps:"
log_info "1. Update .env.prod with actual RELAYER_PRIVATE_KEY"
log_info "2. Update telegram-bot/.env with TELEGRAM_BOT_TOKEN"
log_info "3. Restart services: sudo systemctl restart smainer-stack smainer-telegram-bot"
log_info "4. Test API: curl -H 'X-API-Key: <redacted>' https://$DOMAIN/api/v1/health"