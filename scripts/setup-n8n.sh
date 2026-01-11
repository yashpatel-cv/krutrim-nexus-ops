#!/bin/bash
# n8n YouTube Shorts Automation Setup
# Integrates with Krutrim Nexus Ops infrastructure
# Author: Yash Patel
# Repository: github.com/yashpatel-cv/krutrim-nexus-ops

set -e

# Fix terminal type issues
export TERM="${TERM:-xterm}"
if ! tput colors &>/dev/null; then
    export TERM=xterm
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
N8N_HOME="/opt/n8n-automation"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Banner
clear 2>/dev/null || echo -e "\n\n"
cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║   n8n YouTube Shorts Automation Setup                ║
║   Krutrim Nexus Ops Integration                      ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF

echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}✗${NC} Please run as non-root user (script will use sudo when needed)"
    exit 1
fi

# Step 1: Pre-flight checks
echo -e "${BLUE}[1/12]${NC} Running pre-flight checks..."

if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗${NC} Docker not found. Please run main install.sh first"
    exit 1
fi
echo -e "${GREEN}✓${NC} Docker installed"

if ! command -v docker-compose &> /dev/null; then
    echo -e "${YELLOW}⚠${NC} Installing Docker Compose..."
    ARCH=$(uname -m)
    if [ "$ARCH" = "aarch64" ]; then
        COMPOSE_ARCH="aarch64"
    else
        COMPOSE_ARCH="x86_64"
    fi
    sudo curl -sL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${COMPOSE_ARCH}" \
        -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}✓${NC} Docker Compose installed"
else
    echo -e "${GREEN}✓${NC} Docker Compose found"
fi

# Step 2: Find available port
echo -e "\n${BLUE}[2/12]${NC} Finding available port..."

EXISTING_PORTS=$(sudo ss -tulpn 2>/dev/null | grep LISTEN | awk '{print $5}' | grep -oE '[0-9]+$' | sort -u)
N8N_PORT=""

for PORT in 5678 5679 8080 8081 3000 3001 8888; do
    if ! echo "$EXISTING_PORTS" | grep -q "^$PORT$"; then
        N8N_PORT=$PORT
        break
    fi
done

if [ -z "$N8N_PORT" ]; then
    echo -e "${RED}✗${NC} No available ports found"
    exit 1
fi

echo -e "${GREEN}✓${NC} Using port: $N8N_PORT"

# Step 3: Create directory structure
echo -e "\n${BLUE}[3/12]${NC} Creating directory structure..."

sudo mkdir -p "$N8N_HOME"/{workflows,backups,data,credentials,logs}
sudo chown -R "$USER":"$USER" "$N8N_HOME"

echo -e "${GREEN}✓${NC} Directories created: $N8N_HOME"

# Step 4: Generate credentials
echo -e "\n${BLUE}[4/12]${NC} Generating secure credentials..."

N8N_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-16)
WEBHOOK_SECRET=$(openssl rand -hex 32)

echo -e "${GREEN}✓${NC} Credentials generated"

# Step 5: Create Docker Compose file
echo -e "\n${BLUE}[5/12]${NC} Creating Docker Compose configuration..."

cat > "$N8N_HOME/docker-compose.yml" <<EOF
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n-shorts-automation
    restart: unless-stopped
    ports:
      - "127.0.0.1:${N8N_PORT}:5678"
    environment:
      - N8N_HOST=\${N8N_HOST:-localhost}
      - N8N_PORT=5678
      - N8N_PROTOCOL=\${N8N_PROTOCOL:-http}
      - WEBHOOK_URL=\${WEBHOOK_URL:-http://localhost:${N8N_PORT}}
      - NODE_ENV=production
      - GENERIC_TIMEZONE=\${TIMEZONE:-America/Toronto}
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=${N8N_PASSWORD}
      - N8N_ENCRYPTION_KEY=${WEBHOOK_SECRET}
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_PERSONALIZATION_ENABLED=false
      - EXECUTIONS_DATA_PRUNE=true
      - EXECUTIONS_DATA_MAX_AGE=168
      - N8N_METRICS=true
      - N8N_LOG_LEVEL=info
      - N8N_LOG_OUTPUT=console,file
      - N8N_LOG_FILE_LOCATION=/home/node/.n8n/logs
    volumes:
      - ${N8N_HOME}/data:/home/node/.n8n
      - ${N8N_HOME}/workflows:/home/node/.n8n/workflows
      - ${N8N_HOME}/backups:/home/node/.n8n/backups
      - ${N8N_HOME}/logs:/home/node/.n8n/logs
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
      - "com.krutrim.version=1.0"

networks:
  nexus-network:
    external: true
EOF

echo -e "${GREEN}✓${NC} Docker Compose file created"

# Step 6: Create environment file
echo -e "\n${BLUE}[6/12]${NC} Creating environment configuration..."

cat > "$N8N_HOME/.env" <<EOF
# n8n Configuration
N8N_HOST=localhost
N8N_PROTOCOL=http
WEBHOOK_URL=http://localhost:${N8N_PORT}
TIMEZONE=America/Toronto

# Optional: Update these if using domain
# N8N_HOST=krutrimseva.cbu.net
# N8N_PROTOCOL=https
# WEBHOOK_URL=https://krutrimseva.cbu.net/n8n/
EOF

chmod 600 "$N8N_HOME/.env"
echo -e "${GREEN}✓${NC} Environment file created"

# Step 7: Configure Docker network
echo -e "\n${BLUE}[7/12]${NC} Configuring Docker network..."

if ! docker network ls | grep -q "nexus-network"; then
    docker network create nexus-network 2>/dev/null || true
    echo -e "${GREEN}✓${NC} Created nexus-network"
else
    echo -e "${GREEN}✓${NC} nexus-network exists"
fi

# Step 8: Create Caddy configuration (optional)
echo -e "\n${BLUE}[8/12]${NC} Creating Caddy reverse proxy config..."

if [ -d "/etc/caddy" ]; then
    sudo mkdir -p /etc/caddy/conf.d/
    
    sudo tee /etc/caddy/conf.d/n8n.caddy > /dev/null <<EOF
# n8n Automation Platform
# Uncomment and configure domain below if using HTTPS

# krutrimseva.cbu.net/n8n/* {
#     reverse_proxy localhost:${N8N_PORT} {
#         header_up Host {host}
#         header_up X-Real-IP {remote_host}
#         header_up X-Forwarded-For {remote_host}
#         header_up X-Forwarded-Proto {scheme}
#         
#         # WebSocket support
#         header_up Connection {>Connection}
#         header_up Upgrade {>Upgrade}
#     }
# }
EOF
    echo -e "${GREEN}✓${NC} Caddy config created (edit /etc/caddy/conf.d/n8n.caddy to enable)"
else
    echo -e "${YELLOW}⚠${NC} Caddy not found - skipping reverse proxy setup"
fi

# Step 9: Start n8n container
echo -e "\n${BLUE}[9/12]${NC} Starting n8n container..."

cd "$N8N_HOME"

# Use docker-compose or docker compose (plugin)
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    echo -e "${RED}✗${NC} Neither docker-compose nor docker compose found"
    exit 1
fi

$COMPOSE_CMD up -d

echo -e "${GREEN}✓${NC} Container started"

# Wait for n8n to be ready
echo -e "${YELLOW}⏳${NC} Waiting for n8n to initialize..."
for _ in {1..30}; do
    if curl -s "http://localhost:${N8N_PORT}/healthz" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} n8n is ready!"
        break
    fi
    sleep 2
    echo -n "."
done
echo ""

# Step 10: Register with Consul (if available)
echo -e "\n${BLUE}[10/12]${NC} Registering with Consul..."

if command -v consul &> /dev/null && systemctl is-active --quiet consul; then
    curl -X PUT http://localhost:8500/v1/agent/service/register \
      -H "Content-Type: application/json" \
      -d "{
        \"ID\": \"n8n-automation\",
        \"Name\": \"n8n\",
        \"Tags\": [\"automation\", \"youtube\", \"shorts\"],
        \"Address\": \"127.0.0.1\",
        \"Port\": ${N8N_PORT},
        \"Check\": {
          \"HTTP\": \"http://127.0.0.1:${N8N_PORT}/healthz\",
          \"Interval\": \"30s\",
          \"Timeout\": \"5s\"
        },
        \"Meta\": {
          \"version\": \"latest\",
          \"type\": \"youtube-automation\"
        }
      }" 2>/dev/null && echo -e "${GREEN}✓${NC} Registered with Consul" || echo -e "${YELLOW}⚠${NC} Consul registration skipped"
else
    echo -e "${YELLOW}⚠${NC} Consul not available - skipping registration"
fi

# Step 11: Create systemd service
echo -e "\n${BLUE}[11/12]${NC} Creating systemd service..."

sudo tee /etc/systemd/system/n8n-automation.service > /dev/null <<EOF
[Unit]
Description=n8n YouTube Shorts Automation
Documentation=https://docs.n8n.io
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${N8N_HOME}
ExecStart=/bin/bash -c 'docker compose up -d 2>/dev/null || docker-compose up -d'
ExecStop=/bin/bash -c 'docker compose down 2>/dev/null || docker-compose down'
ExecReload=/bin/bash -c 'docker compose restart 2>/dev/null || docker-compose restart'
User=${USER}
Group=${USER}

# Security hardening
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

echo -e "${GREEN}✓${NC} Systemd service created and enabled"

# Step 12: Save access information
echo -e "\n${BLUE}[12/12]${NC} Saving access information..."

cat > "$N8N_HOME/ACCESS_INFO.txt" <<EOF
═══════════════════════════════════════════════════════
  n8n YouTube Shorts Automation - Access Information
═══════════════════════════════════════════════════════

📍 Installation: ${N8N_HOME}
📅 Installed: $(date)

🌐 Access URLs:
   Local:  http://localhost:${N8N_PORT}
   
   For HTTPS access via Caddy:
   1. Edit /etc/caddy/conf.d/n8n.caddy
   2. Uncomment and configure domain
   3. Run: sudo systemctl reload caddy

👤 Login Credentials:
   Username: admin
   Password: ${N8N_PASSWORD}

🔑 Encryption Key (KEEP SECRET):
   ${WEBHOOK_SECRET}

🔧 Management Commands:
   Status:     sudo systemctl status n8n-automation
   Logs:       docker-compose -f ${N8N_HOME}/docker-compose.yml logs -f
   Restart:    sudo systemctl restart n8n-automation
   Stop:       sudo systemctl stop n8n-automation
   
   Container:  docker ps | grep n8n
   Exec:       docker exec -it n8n-shorts-automation sh

📊 Monitoring:
   Health:     curl http://localhost:${N8N_PORT}/healthz
   Consul:     consul catalog services | grep n8n
   Dashboard:  http://localhost:9000

📁 Directory Structure:
   Workflows:  ${N8N_HOME}/workflows
   Data:       ${N8N_HOME}/data
   Backups:    ${N8N_HOME}/backups
   Logs:       ${N8N_HOME}/logs

🎬 Next Steps:
   1. Run: cd ${REPO_ROOT} && ./scripts/setup-youtube-workflow.sh
   2. Access: http://localhost:${N8N_PORT}
   3. Login with credentials above
   4. Import workflow and configure API keys

🔒 Security Notes:
   - Only accessible locally (127.0.0.1:${N8N_PORT})
   - Use Caddy reverse proxy for HTTPS
   - Basic authentication enabled
   - Credentials encrypted with AES-256

═══════════════════════════════════════════════════════
EOF

chmod 600 "$N8N_HOME/ACCESS_INFO.txt"

# Final output
clear

cat <<EOF

${GREEN}╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     ✓ n8n YouTube Shorts Automation Installed!           ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝${NC}

${YELLOW}🌐 Access n8n:${NC}
   ${GREEN}http://localhost:${N8N_PORT}${NC}

${YELLOW}🔑 Login Credentials:${NC}
   Username: ${GREEN}admin${NC}
   Password: ${GREEN}${N8N_PASSWORD}${NC}

${YELLOW}📊 Status:${NC}
   Container: ${GREEN}$(docker ps --filter "name=n8n-shorts" --format "{{.Status}}")${NC}
   Health:    ${GREEN}$(curl -s http://localhost:${N8N_PORT}/healthz && echo "Healthy" || echo "Starting...")${NC}

${YELLOW}📁 Installation:${NC}
   Location:  ${N8N_HOME}
   Logs:      ${N8N_HOME}/logs
   Access:    ${N8N_HOME}/ACCESS_INFO.txt

${YELLOW}🔧 Management:${NC}
   Status:    ${GREEN}sudo systemctl status n8n-automation${NC}
   Logs:      ${GREEN}cd ${N8N_HOME} && docker compose logs -f${NC}
   Restart:   ${GREEN}sudo systemctl restart n8n-automation${NC}

${YELLOW}🎬 Next Steps:${NC}
   1. Setup YouTube workflow:
      ${GREEN}cd ${REPO_ROOT} && ./scripts/setup-youtube-workflow.sh${NC}
   
   2. Access n8n dashboard:
      ${GREEN}http://localhost:${N8N_PORT}${NC}
   
   3. Configure API keys (Groq, Gemini, Pexels, etc.)

${YELLOW}⚠️  Important:${NC}
   ${RED}Save your password: ${N8N_PASSWORD}${NC}
   Stored in: ${N8N_HOME}/ACCESS_INFO.txt

═══════════════════════════════════════════════════════════
Installation complete! Ready to automate YouTube Shorts 🎬🤖
═══════════════════════════════════════════════════════════

EOF

# Log installation
echo "n8n installation completed at $(date)" >> "$N8N_HOME/install.log"
echo "Port: $N8N_PORT" >> "$N8N_HOME/install.log"
echo "User: $USER" >> "$N8N_HOME/install.log"
