#!/bin/bash
# Fix n8n installation issues
# Addresses: Docker permissions, network binding, firewall, service startup

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

N8N_HOME="/opt/n8n-automation"

echo -e "${BLUE}=== Fixing n8n Installation ===${NC}\n"

# 1. Fix Docker permissions
echo -e "${BLUE}[1/6]${NC} Adding user to docker group..."
if ! groups debian | grep -q docker; then
    sudo usermod -aG docker debian
    echo -e "${GREEN}✓${NC} User 'debian' added to docker group"
    echo -e "${YELLOW}⚠${NC} You'll need to logout/login for this to take effect"
else
    echo -e "${GREEN}✓${NC} User already in docker group"
fi

# 2. Fix docker-compose.yml to listen on all interfaces
echo -e "\n${BLUE}[2/6]${NC} Fixing network binding (0.0.0.0 instead of 127.0.0.1)..."
if [ -f "$N8N_HOME/docker-compose.yml" ]; then
    sudo sed -i 's/127\.0\.0\.1:5678:5678/5678:5678/' "$N8N_HOME/docker-compose.yml"
    echo -e "${GREEN}✓${NC} Network binding fixed"
else
    echo -e "${RED}✗${NC} docker-compose.yml not found"
    exit 1
fi

# 3. Configure firewall (iptables)
echo -e "\n${BLUE}[3/6]${NC} Configuring firewall..."
# Remove existing rule if present
sudo iptables -D INPUT -p tcp --dport 5678 -j ACCEPT 2>/dev/null || true

# Add new rule at the beginning
sudo iptables -I INPUT 1 -p tcp --dport 5678 -j ACCEPT

# Save iptables rules
if command -v netfilter-persistent &> /dev/null; then
    sudo netfilter-persistent save
    echo -e "${GREEN}✓${NC} Firewall configured (persistent)"
elif command -v iptables-save &> /dev/null; then
    sudo sh -c "iptables-save > /etc/iptables/rules.v4"
    echo -e "${GREEN}✓${NC} Firewall configured"
else
    echo -e "${YELLOW}⚠${NC} Firewall configured (non-persistent)"
fi

# 4. Stop any existing containers
echo -e "\n${BLUE}[4/6]${NC} Stopping existing containers..."
cd "$N8N_HOME"
sudo docker compose down 2>/dev/null || sudo docker-compose down 2>/dev/null || true
echo -e "${GREEN}✓${NC} Stopped"

# 5. Start n8n via systemd
echo -e "\n${BLUE}[5/6]${NC} Starting n8n service..."
sudo systemctl daemon-reload
sudo systemctl enable n8n-automation
sudo systemctl start n8n-automation

# Wait for service to start
sleep 5

# Check status
if sudo systemctl is-active --quiet n8n-automation; then
    echo -e "${GREEN}✓${NC} n8n service is running"
else
    echo -e "${RED}✗${NC} n8n service failed to start"
    sudo systemctl status n8n-automation --no-pager
    exit 1
fi

# 6. Verify container is running and accessible
echo -e "\n${BLUE}[6/6]${NC} Verifying accessibility..."

# Wait for container to be healthy
for i in {1..30}; do
    if sudo docker ps | grep -q "n8n-shorts-automation.*healthy"; then
        echo -e "${GREEN}✓${NC} Container is healthy"
        break
    fi
    sleep 2
done

# Check if listening on 0.0.0.0
if sudo netstat -tlnp | grep 5678 | grep -q "0.0.0.0"; then
    echo -e "${GREEN}✓${NC} Listening on all interfaces (0.0.0.0:5678)"
elif sudo netstat -tlnp | grep 5678 | grep -q "127.0.0.1"; then
    echo -e "${RED}✗${NC} Still listening on localhost only - restart required"
    echo -e "${YELLOW}⚠${NC} Run: sudo systemctl restart n8n-automation"
else
    echo -e "${YELLOW}⚠${NC} Port status unclear, checking container..."
fi

# Get credentials
if [ -f "$N8N_HOME/ACCESS_INFO.txt" ]; then
    PASSWORD=$(grep "Password:" "$N8N_HOME/ACCESS_INFO.txt" | awk '{print $2}')
else
    PASSWORD="(check $N8N_HOME/ACCESS_INFO.txt)"
fi

echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}║     ✓ n8n Fixed and Running!                             ║${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"

echo -e "\n${YELLOW}Access n8n:${NC}"
echo -e "  Local:    ${GREEN}http://localhost:5678${NC}"
echo -e "  Internet: ${GREEN}http://64.181.212.50:5678${NC}"

echo -e "\n${YELLOW}Credentials:${NC}"
echo -e "  Username: ${GREEN}admin${NC}"
echo -e "  Password: ${GREEN}${PASSWORD}${NC}"

echo -e "\n${YELLOW}Verify:${NC}"
echo -e "  ${BLUE}curl -I http://localhost:5678${NC}"
echo -e "  ${BLUE}sudo docker ps | grep n8n${NC}"

echo -e "\n${YELLOW}⚠️  Oracle Cloud Console:${NC}"
echo -e "  You may also need to add port 5678 in Oracle Cloud Console:"
echo -e "  Networking → Security Lists → Ingress Rules → Add Rule"
echo -e "  Source CIDR: 0.0.0.0/0, Destination Port: 5678, Protocol: TCP"

echo ""
