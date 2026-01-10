#!/bin/bash
# n8n Automation Platform Setup - Krutrim Nexus Integration
# Compatible with existing Oracle Cloud ARM64 infrastructure

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
N8N_HOME="/opt/n8n-automation"
LOG_FILE="${N8N_HOME}/install.log"

# Helper functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null || true
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    echo "[ERROR] $1" >> "$LOG_FILE" 2>/dev/null || true
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[WARNING] $1" >> "$LOG_FILE" 2>/dev/null || true
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should NOT be run as root"
        exit 1
    fi
}

banner() {
    clear
    cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║          n8n Automation Platform Setup                   ║
║          Krutrim Nexus Ops Integration                   ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
}

# Main installation
main() {
    banner
    check_root
    
    log "Starting n8n setup..."
    
    # Create directories
    sudo mkdir -p "$N8N_HOME"/{workflows,backups,data,credentials} || error "Failed to create directories"
    sudo chown -R "$USER:$USER" "$N8N_HOME"
    touch "$LOG_FILE"
    
    # Step 1: Check prerequisites
    log "Step 1/8: Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker not found. Install via: make install"
        exit 1
    fi
    log "✓ Docker found: $(docker --version | cut -d' ' -f3)"
    
    if ! command -v docker-compose &> /dev/null; then
        log "Installing Docker Compose for ARM64..."
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" \
            -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
    log "✓ Docker Compose: $(docker-compose --version | cut -d' ' -f4)"
    
    # Step 2: Find available port
    log "Step 2/8: Finding available port..."
    
    N8N_PORT=""
    USED_PORTS=$(sudo ss -tulpn | grep LISTEN | awk '{print $5}' | cut -d: -f2 | sort -u)
    
    for PORT in 5678 5679 8080 8081 3000 3001 8088; do
        if ! echo "$USED_PORTS" | grep -q "^$PORT$"; then
            N8N_PORT=$PORT
            log "✓ Found available port: $N8N_PORT"
            break
        fi
    done
    
    if [ -z "$N8N_PORT" ]; then
        error "No available ports found"
        exit 1
    fi
    
    # Step 3: Generate credentials
    log "Step 3/8: Generating secure credentials..."
    
    N8N_PASSWORD=$(openssl rand -base64 16)
    WEBHOOK_SECRET=$(openssl rand -hex 32)
    
    log "✓ Credentials generated"
    
    # Step 4: Create Docker network
    log "Step 4/8: Configuring Docker network..."
    
    if ! docker network ls | grep -q "nexus-network"; then
        docker network create nexus-network
        log "✓ Created nexus-network"
    else
        log "✓ nexus-network already exists"
    fi
    
    # Step 5: Create Docker Compose
    log "Step 5/8: Creating Docker Compose configuration..."
    
    cat > "${N8N_HOME}/docker-compose.yml" <<EOF
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n-automation
    restart: unless-stopped
    ports:
      - "127.0.0.1:${N8N_PORT}:5678"
    environment:
      - N8N_HOST=\${N8N_HOST:-localhost}
      - N8N_PORT=5678
      - N8N_PROTOCOL=\${N8N_PROTOCOL:-http}
      - WEBHOOK_URL=\${WEBHOOK_URL:-http://localhost:${N8N_PORT}/}
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
    
    log "✓ Docker Compose file created"
    
    # Step 6: Start n8n
    log "Step 6/8: Starting n8n container..."
    
    cd "$N8N_HOME"
    docker-compose up -d
    
    log "Waiting for n8n to start (30 seconds)..."
    sleep 30
    
    if docker ps | grep -q "n8n-automation"; then
        log "✓ n8n container running"
    else
        error "n8n container failed to start. Check logs: docker-compose logs"
        exit 1
    fi
    
    # Step 7: Create systemd service
    log "Step 7/8: Creating systemd service..."
    
    sudo tee /etc/systemd/system/n8n-automation.service > /dev/null <<EOF
[Unit]
Description=n8n Automation Platform
Documentation=https://docs.n8n.io
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${N8N_HOME}
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
ExecReload=/usr/local/bin/docker-compose restart
Restart=on-failure
RestartSec=30s
User=${USER}
Group=${USER}

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=${N8N_HOME}

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable n8n-automation.service
    
    log "✓ Systemd service created"
    
    # Step 8: Register with Consul (if available)
    log "Step 8/8: Registering with Consul..."
    
    if command -v consul &> /dev/null; then
        curl -X PUT http://localhost:8500/v1/agent/service/register \
          -H "Content-Type: application/json" \
          -d "{
            \"ID\": \"n8n-automation\",
            \"Name\": \"n8n\",
            \"Tags\": [\"automation\", \"youtube\", \"nexus\"],
            \"Address\": \"127.0.0.1\",
            \"Port\": ${N8N_PORT},
            \"Check\": {
              \"HTTP\": \"http://127.0.0.1:${N8N_PORT}/healthz\",
              \"Interval\": \"30s\",
              \"Timeout\": \"5s\"
            },
            \"Meta\": {
              \"version\": \"latest\",
              \"type\": \"automation\"
            }
          }" 2>/dev/null && log "✓ Registered with Consul" || warning "Consul registration skipped"
    else
        warning "Consul not found, skipping registration"
    fi
    
    # Create access info file
    cat > "${N8N_HOME}/ACCESS_INFO.txt" <<EOF
═══════════════════════════════════════════════════════
  n8n Automation Platform - Access Information
═══════════════════════════════════════════════════════

🌐 Access URL:
   http://localhost:${N8N_PORT}

👤 Login Credentials:
   Username: admin
   Password: ${N8N_PASSWORD}

🔑 Encryption Key:
   ${WEBHOOK_SECRET}

📁 Installation Directory:
   ${N8N_HOME}

🔧 Management Commands:
   Status:  sudo systemctl status n8n-automation
   Logs:    docker-compose -f ${N8N_HOME}/docker-compose.yml logs -f
   Restart: sudo systemctl restart n8n-automation
   Stop:    docker-compose -f ${N8N_HOME}/docker-compose.yml down

📊 Monitoring:
   Container: docker ps | grep n8n
   Health:    docker inspect n8n-automation | grep -i health
   Consul:    curl http://localhost:8500/v1/catalog/service/n8n

═══════════════════════════════════════════════════════
   Installation Date: $(date)
   Generated by Krutrim Nexus Ops
═══════════════════════════════════════════════════════
EOF
    
    chmod 600 "${N8N_HOME}/ACCESS_INFO.txt"
    
    # Final output
    clear
    cat << EOF

${GREEN}╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║          ✓ n8n Successfully Installed!                   ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝${NC}

${YELLOW}🌐 Access n8n:${NC}
   URL:      ${GREEN}http://localhost:${N8N_PORT}${NC}
   
${YELLOW}🔑 Login Credentials:${NC}
   Username: ${GREEN}admin${NC}
   Password: ${GREEN}${N8N_PASSWORD}${NC}
   
${YELLOW}📁 Installation:${NC}
   Directory: ${N8N_HOME}
   Config:    ${N8N_HOME}/docker-compose.yml
   Access:    ${N8N_HOME}/ACCESS_INFO.txt
   Logs:      ${N8N_HOME}/install.log

${YELLOW}🔧 Quick Commands:${NC}
   Status:  ${GREEN}make n8n-status${NC}
   Logs:    ${GREEN}make n8n-logs${NC}
   Restart: ${GREEN}make n8n-restart${NC}

${YELLOW}📚 Next Steps:${NC}
   1. Access n8n: ${GREEN}http://localhost:${N8N_PORT}${NC}
   2. Install YouTube workflow: ${GREEN}make setup-youtube-workflow${NC}
   3. Configure API keys in n8n interface

${YELLOW}⚠️  Important:${NC}
   - Password saved in: ${GREEN}${N8N_HOME}/ACCESS_INFO.txt${NC}
   - Keep credentials secure
   - Backup workflows regularly

═══════════════════════════════════════════════════════════

EOF
    
    log "Installation completed successfully!"
}

main "$@"
