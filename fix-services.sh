#!/usr/bin/env bash
# fix-services.sh - Fix and restart all Nexus services
# Run this after pulling latest changes

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

echo "=== Krutrim Nexus Ops - Service Fix Script ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root"
    echo "Usage: sudo ./fix-services.sh"
    exit 1
fi

# Detect bind IP
BIND_IP="$(hostname -I | awk '{print $1}')"
if [ -z "$BIND_IP" ]; then
    BIND_IP="64.181.212.50"
fi
log "Using bind IP: $BIND_IP"

# Pull latest changes
log "[1/7] Pulling latest changes..."
if ! git pull origin main 2>&1; then
    warn "Git pull failed, continuing with local version"
fi

# Fix Consul service
log "[2/7] Fixing Consul service..."

# Stop and clean up Consul
systemctl stop consul 2>/dev/null || true
pkill -9 consul 2>/dev/null || true
systemctl reset-failed consul 2>/dev/null || true

# Clean data directory but preserve config
if [ -d "/var/consul" ]; then
    log "Cleaning Consul data directory..."
    rm -rf /var/consul/*
fi

# Fix Consul config if bind_addr is 0.0.0.0
if [ -f "/etc/consul.d/server.json" ]; then
    if grep -q '"bind_addr": "0.0.0.0"' /etc/consul.d/server.json; then
        log "Fixing Consul bind_addr in configuration..."
        sed -i "s|\"bind_addr\": \"0.0.0.0\"|\"bind_addr\": \"$BIND_IP\"|g" /etc/consul.d/server.json
        sed -i "s|{|{\n  \"advertise_addr\": \"$BIND_IP\",|" /etc/consul.d/server.json
    fi
fi

if [ -f "/etc/consul.d/client.json" ]; then
    if grep -q '"bind_addr": "0.0.0.0"' /etc/consul.d/client.json; then
        log "Fixing Consul bind_addr in client configuration..."
        sed -i "s|\"bind_addr\": \"0.0.0.0\"|\"bind_addr\": \"$BIND_IP\"|g" /etc/consul.d/client.json
        sed -i "s|{|{\n  \"advertise_addr\": \"$BIND_IP\",|" /etc/consul.d/client.json
    fi
fi

# Validate Consul config
if command -v consul &>/dev/null; then
    log "Validating Consul configuration..."
    if ! consul validate /etc/consul.d 2>&1; then
        error "Consul configuration invalid!"
        cat /etc/consul.d/*.json
        exit 1
    fi
    log "Consul configuration validated"
fi

# Start Consul
systemctl start consul 2>/dev/null || {
    error "Consul service not found!"
    echo "Please re-run: sudo ./install.sh"
    exit 1
}

# Wait for Consul to be ready
log "Waiting for Consul to start..."
local max_wait=30
local waited=0
while ! systemctl is-active --quiet consul; do
    if [ $waited -ge $max_wait ]; then
        error "Consul failed to start after ${max_wait}s"
        journalctl -u consul -n 30 --no-pager
        exit 1
    fi
    sleep 1
    waited=$((waited + 1))
done

if systemctl is-active --quiet consul; then
    log "✓ Consul is running"
else
    error "✗ Consul failed to start"
    journalctl -u consul -n 20
    exit 1
fi

# Update dashboard code
log "[3/7] Updating dashboard..."
if [ ! -d "/opt/krutrim-nexus-ops/dashboard/backend" ]; then
    error "Dashboard backend directory not found!"
    exit 1
fi
cd /opt/krutrim-nexus-ops/dashboard/backend

# Remove old venv and recreate
if [ -d "venv" ]; then
    echo "Removing old virtual environment..."
    rm -rf venv
fi

echo "Creating fresh virtual environment..."
python3 -m venv venv
source venv/bin/activate
echo "Upgrading pip, setuptools, wheel..."
pip install --upgrade pip setuptools wheel -q
echo "Installing dashboard dependencies (this may take a minute)..."
pip install -r requirements.txt -q --no-cache-dir
echo "✓ Dependencies installed"
deactivate

# Restart dashboard service
log "[4/7] Restarting dashboard service..."
systemctl restart nexus-dashboard
sleep 2

if systemctl is-active --quiet nexus-dashboard; then
    echo "✓ Dashboard is running"
else
    echo "✗ Dashboard failed to start"
    echo "Logs:"
    journalctl -u nexus-dashboard -n 20
fi

# Restart orchestrator
log "[5/7] Restarting orchestrator..."
systemctl restart nexus-orchestrator
sleep 1

if systemctl is-active --quiet nexus-orchestrator; then
    echo "✓ Orchestrator is running"
else
    echo "✗ Orchestrator failed to start"
    journalctl -u nexus-orchestrator -n 20
fi

# Restart worker
log "[6/7] Restarting worker..."
systemctl restart nexus-worker
sleep 1

if systemctl is-active --quiet nexus-worker; then
    echo "✓ Worker is running"
else
    echo "✗ Worker failed to start"
    journalctl -u nexus-worker -n 20
fi

# Final validation
log "[7/7] Final validation..."
local all_ok=true

if ! systemctl is-active --quiet consul; then
    error "✗ Consul is not running"
    all_ok=false
fi

if ! systemctl is-active --quiet nexus-orchestrator; then
    warn "✗ Orchestrator is not running"
fi

if ! systemctl is-active --quiet nexus-worker; then
    warn "✗ Worker is not running"
fi

if ! systemctl is-active --quiet nexus-dashboard; then
    warn "✗ Dashboard is not running"
fi

echo ""
log "=== Service Status ==="
echo ""
if consul members &>/dev/null; then
    consul members
else
    error "Consul not responding to members command"
fi
echo ""
systemctl status consul --no-pager -l || true
systemctl status nexus-orchestrator --no-pager -l || true
systemctl status nexus-worker --no-pager -l || true
systemctl status nexus-dashboard --no-pager -l || true

echo ""
log "=== Access Points ==="
echo "Consul UI: http://$BIND_IP:8500"
echo "Dashboard: http://$BIND_IP:9000"
echo ""

if [ "$all_ok" = true ]; then
    log "✓ All services are running!"
else
    error "Some services failed. Check logs above."
    exit 1
fi
