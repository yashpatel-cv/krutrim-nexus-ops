#!/bin/bash
# Network diagnostics for n8n connectivity issues

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== n8n Network Diagnostics ===${NC}\n"

# 1. Check if n8n is running
echo -e "${BLUE}[1/7]${NC} Checking n8n container status..."
if sudo docker ps | grep -q "n8n-shorts-automation.*healthy"; then
    echo -e "${GREEN}✓${NC} Container running and healthy"
else
    echo -e "${RED}✗${NC} Container not running or unhealthy"
    sudo docker ps -a | grep n8n || echo "No n8n container found"
fi

# 2. Check port binding
echo -e "\n${BLUE}[2/7]${NC} Checking port binding..."
PORT_INFO=$(sudo netstat -tlnp | grep 5678 || true)
if echo "$PORT_INFO" | grep -q "0.0.0.0:5678"; then
    echo -e "${GREEN}✓${NC} Port 5678 listening on all interfaces (0.0.0.0)"
    echo "$PORT_INFO"
elif echo "$PORT_INFO" | grep -q "127.0.0.1:5678"; then
    echo -e "${RED}✗${NC} Port 5678 only listening on localhost (127.0.0.1)"
    echo "$PORT_INFO"
    echo -e "${YELLOW}Fix needed: Run fix-n8n.sh script${NC}"
else
    echo -e "${RED}✗${NC} Port 5678 not listening"
fi

# 3. Check iptables rules
echo -e "\n${BLUE}[3/7]${NC} Checking OS firewall (iptables)..."
IPTABLES_RULE=$(sudo iptables -L INPUT -n --line-numbers | grep 5678 || true)
if [ -n "$IPTABLES_RULE" ]; then
    echo -e "${GREEN}✓${NC} iptables rule exists:"
    echo "$IPTABLES_RULE"
else
    echo -e "${YELLOW}⚠${NC} No iptables rule for port 5678 (might be OK if using default ACCEPT policy)"
fi

# Check iptables default policy
DEFAULT_POLICY=$(sudo iptables -L INPUT | head -1 | grep -oP '\(policy \K[A-Z]+' || echo "UNKNOWN")
echo -e "   Default INPUT policy: ${DEFAULT_POLICY}"

# 4. Test local connectivity
echo -e "\n${BLUE}[4/7]${NC} Testing local connectivity..."
if curl -s -m 5 -o /dev/null -w "%{http_code}" http://localhost:5678 | grep -q "200"; then
    echo -e "${GREEN}✓${NC} Local access works (HTTP 200)"
else
    echo -e "${RED}✗${NC} Local access failed"
fi

# 5. Check if server is listening on all interfaces
echo -e "\n${BLUE}[5/7]${NC} Checking network interfaces..."
ip addr show | grep -E "inet " | grep -v "127.0.0.1"
echo ""

# Get primary IP
PRIMARY_IP=$(ip route get 1 2>/dev/null | awk '{print $7; exit}' || hostname -I | awk '{print $1}')
echo "Primary IP: ${PRIMARY_IP}"

# 6. Test connectivity to primary IP
echo -e "\n${BLUE}[6/7]${NC} Testing connectivity to primary IP..."
if curl -s -m 5 -o /dev/null -w "%{http_code}" http://${PRIMARY_IP}:5678 2>/dev/null | grep -q "200"; then
    echo -e "${GREEN}✓${NC} Can connect via primary IP (${PRIMARY_IP}:5678)"
else
    echo -e "${RED}✗${NC} Cannot connect via primary IP"
fi

# 7. Oracle Cloud specific checks
echo -e "\n${BLUE}[7/7]${NC} Oracle Cloud configuration status..."
echo ""
echo -e "${YELLOW}IMPORTANT: Oracle Cloud has TWO separate firewall layers:${NC}"
echo ""
echo -e "1. ${BLUE}Security Lists${NC} (Virtual Cloud Network level)"
echo -e "   Status: You showed this is configured ✓"
echo -e "   Rule: Source 0.0.0.0/0 → Port 5678 (TCP)"
echo ""
echo -e "2. ${BLUE}Network Security Groups (NSGs)${NC} - CHECK THIS!"
echo -e "   ${YELLOW}⚠ If NSG is attached to your instance, it OVERRIDES Security Lists${NC}"
echo ""
echo -e "${YELLOW}To check NSG in Oracle Cloud Console:${NC}"
echo "   1. Go to: Compute → Instances → Your Instance"
echo "   2. Look for: 'Network Security Groups' section"
echo "   3. If ANY NSG is listed there:"
echo "      → Click the NSG name"
echo "      → Check if it has a rule allowing port 5678"
echo "      → If not, ADD rule: Source 0.0.0.0/0, Port 5678, TCP"
echo ""
echo -e "   ${GREEN}If 'None' is shown → NSG not blocking, good!${NC}"
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Summary & Next Steps:${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}If connection still times out from internet:${NC}"
echo ""
echo "1. Check Network Security Groups (NSG) in Oracle Console"
echo "   Most common issue if Security List is correct"
echo ""
echo "2. Verify Security List is attached to CORRECT subnet"
echo "   Instance → VNIC → Subnet → Should match Security List location"
echo ""
echo "3. Check for additional firewalls"
echo "   Some regions have extra security features"
echo ""
echo "4. Test from different network/device"
echo "   Your ISP might block uncommon ports"
echo ""
echo -e "${GREEN}Test external access from another server:${NC}"
echo "   curl -I http://64.181.212.50:5678"
echo ""
