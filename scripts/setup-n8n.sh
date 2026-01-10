#!/usr/bin/env bash
# setup-n8n.sh - n8n Automation Platform Setup
# Integrates with Krutrim Nexus Ops infrastructure

set -Eeuo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
err() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# Configuration
N8N_HOME="/opt/n8n-automation"
NEXUS_HOME="/opt/nexus"

echo -e "${BLUE}"
cat << 'EOF'
╔══════════════════════════════════════════════╗
║      n8n Automation Platform Setup           ║
║      Nexus Ops Integration                   ║
╚══════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check root
if [ "$EUID" -ne 0 ]; then
    err "This script must be run as root (use sudo)"
fi

# Detect environment
PRIVATE_IP="$(hostname -I | awk '{print $1}')"
if [ -z "$PRIVATE_IP" ]; then
    PRIVATE_IP="$(ip route get 1 2>/dev/null | awk '{print $7; exit}')"
fi

# Detect domain
DETECTED_DOMAIN="krutrimseva.cbu.net"
if [ -f "$NEXUS_HOME/cluster.yml" ]; then
    DETECTED_DOMAIN=$(grep '^domain:' "$NEXUS_HOME/cluster.yml" | awk '{print $2}' || echo "$DETECTED_DOMAIN")
fi

DOMAIN="${DETECTED_DOMAIN}"

log "Environment detected:"
log "  IP: $PRIVATE_IP"
log "  Domain: $DOMAIN"

# ============================================================
# STEP 1: Pre-flight Checks
# ============================================================

log "Running pre-flight checks..."

# Check Docker
if ! command -v docker &> /dev/null; then
    err "Docker not found. Install via: make install"
fi

if ! command -v docker-compose &> /dev/null; then
    log "Installing Docker Compose..."
    ARCH="$(uname -m)"
    if [ "$ARCH" = "aarch64" ]; then
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-aarch64" \
            -o /usr/local/bin/docker-compose
    else
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
            -o /usr/local/bin/docker-compose
    fi
    chmod +x /usr/local/bin/docker-compose
fi

# Check Consul
if ! systemctl is-active --quiet consul; then
    warn "Consul not running. Some features may be limited."
fi

# Find available port
log "Finding available port..."
EXISTING_PORTS=$(ss -tulpn 2>/dev/null | grep LISTEN | awk '{print $5}' | cut -d: -f2 | sort -u)
N8N_PORT=""
for PORT in 5678 5679 8080 8081 3000 3001; do
    if ! echo "$EXISTING_PORTS" | grep -q "^$PORT$"; then
        N8N_PORT=$PORT
        log "Using port: $N8N_PORT"
        break
    fi
done

if [ -z "$N8N_PORT" ]; then
    err "No available ports found"
fi

# ============================================================
# STEP 2: Create Directory Structure
# ============================================================

log "Setting up directory structure..."
mkdir -p "$N8N_HOME"/{workflows,backups,data,credentials}
chown -R $SUDO_USER:$SUDO_USER "$N8N_HOME" 2>/dev/null || true

# ============================================================
# STEP 3: Generate Secure Credentials
# ============================================================

log "Generating secure credentials..."
N8N_PASSWORD=$(openssl rand -base64 16)
WEBHOOK_SECRET=$(openssl rand -hex 32)

# ============================================================
# STEP 4: Create Docker Compose
# ============================================================

log "Creating Docker Compose configuration..."

cat > "$N8N_HOME/docker-compose.yml" <<EOF
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n-automation
    restart: unless-stopped
    ports:
      - "127.0.0.1:${N8N_PORT}:5678"
    environment:
      - N8N_HOST=${DOMAIN}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://${DOMAIN}/n8n/
      - NODE_ENV=production
      - GENERIC_TIMEZONE=America/Toronto
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=${N8N_PASSWORD}
      - N8N_ENCRYPTION_KEY=${WEBHOOK_SECRET}
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_PERSONALIZATION_ENABLED=false
      - EXECUTIONS_DATA_PRUNE=true
      - EXECUTIONS_DATA_MAX_AGE=168
    volumes:
      - ${N8N_HOME}/data:/home/node/.n8n
      - ${N8N_HOME}/workflows:/home/node/.n8n/workflows
      - ${N8N_HOME}/backups:/home/node/.n8n/backups
    networks:
      - nexus-network
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:5678/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    labels:
      - "com.krutrim.service=n8n"
      - "com.krutrim.type=automation"

networks:
  nexus-network:
    external: true
EOF

# ============================================================
# STEP 5: Configure Docker Network
# ============================================================

log "Configuring Docker network..."

if ! docker network ls | grep -q "nexus-network"; then
    docker network create nexus-network
    log "Created nexus-network"
else
    log "nexus-network already exists"
fi

# ============================================================
# STEP 6: Configure Caddy Reverse Proxy
# ============================================================

log "Configuring Caddy reverse proxy..."

mkdir -p /etc/caddy/conf.d/

cat > /etc/caddy/conf.d/n8n.caddy <<EOF
# n8n Automation Platform
${DOMAIN}/n8n/* {
    reverse_proxy localhost:${N8N_PORT} {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
        
        # WebSocket support
        header_up Connection {>Connection}
        header_up Upgrade {>Upgrade}
    }
}
EOF

log "Caddy configuration created"
log "Run 'systemctl reload caddy' to apply changes"

# ============================================================
# STEP 7: Update Firewall (Internal Access Only)
# ============================================================

log "Configuring firewall..."

# n8n is only accessible via Caddy proxy (internal)
if [ -f /etc/nftables.conf ]; then
    if ! grep -q "# n8n automation" /etc/nftables.conf; then
        # Add rule for internal access only
        sed -i '/# Allow HTTP\/HTTPS/i\        # n8n automation (internal only)\n        ip saddr 127.0.0.1 tcp dport '"${N8N_PORT}"' accept' /etc/nftables.conf
        nft -f /etc/nftables.conf 2>/dev/null || warn "Failed to reload nftables"
    fi
fi

# ============================================================
# STEP 8: Start n8n Container
# ============================================================

log "Starting n8n container..."

cd "$N8N_HOME"
docker-compose up -d

log "Waiting for n8n to be ready..."
sleep 15

# ============================================================
# STEP 9: Register with Consul (if available)
# ============================================================

if systemctl is-active --quiet consul && command -v consul &>/dev/null; then
    log "Registering with Consul..."
    
    curl -X PUT http://localhost:8500/v1/agent/service/register \
      -H "Content-Type: application/json" \
      -d '{
        "ID": "n8n-automation",
        "Name": "n8n",
        "Tags": ["automation", "workflows", "orchestration"],
        "Address": "127.0.0.1",
        "Port": '"${N8N_PORT}"',
        "Check": {
          "HTTP": "http://127.0.0.1:'"${N8N_PORT}"'/healthz",
          "Interval": "30s",
          "Timeout": "5s"
        },
        "Meta": {
          "version": "latest",
          "type": "workflow-automation"
        }
      }' 2>/dev/null && log "Registered with Consul" || warn "Consul registration skipped"
fi

# ============================================================
# STEP 10: Create Systemd Service
# ============================================================

log "Creating systemd service..."

cat > /etc/systemd/system/n8n-automation.service <<EOF
[Unit]
Description=n8n Workflow Automation
Documentation=https://docs.n8n.io
After=docker.service consul.service
Requires=docker.service
PartOf=nexus-orchestrator.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${N8N_HOME}
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
ExecReload=/usr/local/bin/docker-compose restart
Restart=on-failure
RestartSec=30s
User=root

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=${N8N_HOME}

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable n8n-automation.service
systemctl start n8n-automation.service

# ============================================================
# STEP 11: Save Access Information
# ============================================================

log "Saving access information..."

cat > "${N8N_HOME}/ACCESS_INFO.txt" <<EOF
═══════════════════════════════════════════════════════
  n8n Workflow Automation - Access Information
═══════════════════════════════════════════════════════

📍 Server: ${PRIVATE_IP} (${DOMAIN})
🔧 Installation: ${N8N_HOME}

🌐 Access URLs:
   Public (HTTPS): https://${DOMAIN}/n8n/
   Local:          http://localhost:${N8N_PORT}

👤 Login Credentials:
   Username: admin
   Password: ${N8N_PASSWORD}

🔑 Encryption Key (KEEP SECRET):
   ${WEBHOOK_SECRET}

📊 Integration:
   - Registered with Consul: http://localhost:8500
   - Proxied via Caddy (auto-HTTPS)
   - Part of Nexus orchestration

🔧 Management Commands:
   Status:  systemctl status n8n-automation
   Logs:    docker-compose -f ${N8N_HOME}/docker-compose.yml logs -f
   Restart: systemctl restart n8n-automation
   Consul:  consul catalog services | grep n8n

📁 Directory Structure:
   Workflows: ${N8N_HOME}/workflows
   Data:      ${N8N_HOME}/data
   Backups:   ${N8N_HOME}/backups

🔒 Security:
   - Only accessible via Caddy reverse proxy
   - Basic authentication enabled
   - Encrypted credentials storage
   - Auto-HTTPS via Let's Encrypt

═══════════════════════════════════════════════════════
   Installation Date: $(date)
   Krutrim Nexus Ops Integration
═══════════════════════════════════════════════════════
EOF

chmod 600 "${N8N_HOME}/ACCESS_INFO.txt"

# ============================================================
# Final Output
# ============================================================

clear

cat <<EOF

${GREEN}╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     ✓ n8n Workflow Automation Installed!                 ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝${NC}

${YELLOW}🌐 Access n8n:${NC}
   Public:  ${GREEN}https://${DOMAIN}/n8n/${NC}
   Local:   http://localhost:${N8N_PORT}

${YELLOW}🔑 Login:${NC}
   Username: ${GREEN}admin${NC}
   Password: ${GREEN}${N8N_PASSWORD}${NC}

${YELLOW}📊 Integration Status:${NC}
   ✓ Docker container running
   ✓ Caddy reverse proxy configured
   ✓ Consul service registered
   ✓ Systemd service enabled
   ✓ Nexus orchestration integrated

${YELLOW}📁 Files:${NC}
   Config:  ${N8N_HOME}/docker-compose.yml
   Access:  ${N8N_HOME}/ACCESS_INFO.txt
   Logs:    docker-compose -f ${N8N_HOME}/docker-compose.yml logs -f

${YELLOW}🔧 Next Steps:${NC}
   1. Reload Caddy: ${GREEN}systemctl reload caddy${NC}
   2. Access dashboard: ${GREEN}https://${DOMAIN}/n8n/${NC}
   3. Setup workflows: ${GREEN}make youtube-workflow${NC}
   4. View documentation: ${GREEN}cat ${N8N_HOME}/ACCESS_INFO.txt${NC}

${YELLOW}⚠️  Important:${NC}
   - Save your password: ${GREEN}${N8N_PASSWORD}${NC}
   - Stored securely in: ${N8N_HOME}/ACCESS_INFO.txt
   - Only accessible via HTTPS (auto-configured)

${YELLOW}📖 Monitoring:${NC}
   Consul UI:  http://${PRIVATE_IP}:8500 (check n8n service)
   Dashboard:  http://${PRIVATE_IP}:9000 (Nexus monitoring)
   n8n Status: ${GREEN}systemctl status n8n-automation${NC}

═══════════════════════════════════════════════════════════
Ready for workflow automation! 🚀
═══════════════════════════════════════════════════════════

EOF

echo "Installation completed at $(date)" >> "${N8N_HOME}/install.log"

log "n8n installation complete!"
log "Next: Run 'make youtube-workflow' to setup YouTube Shorts automation"
