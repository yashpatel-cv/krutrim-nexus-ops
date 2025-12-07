#!/usr/bin/env bash
# fix-services.sh - Fix and restart all Nexus services
# Run this after pulling latest changes

set -e

echo "=== Krutrim Nexus Ops - Service Fix Script ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo ./fix-services.sh"
    exit 1
fi

# Pull latest changes
echo "[1/6] Pulling latest changes..."
git pull origin main

# Fix Consul service
echo "[2/6] Starting Consul service..."
systemctl start consul 2>/dev/null || {
    echo "Consul service not found, installing..."
    # Consul should have been installed by install.sh
    echo "Please re-run: sudo ./install.sh"
    exit 1
}

# Wait for Consul to be ready
echo "Waiting for Consul to start..."
sleep 3

# Check Consul status
if systemctl is-active --quiet consul; then
    echo "✓ Consul is running"
else
    echo "✗ Consul failed to start"
    journalctl -u consul -n 20
    exit 1
fi

# Update dashboard code
echo "[3/6] Updating dashboard..."
cd /opt/krutrim-nexus-ops/dashboard/backend

# Remove old venv and recreate
if [ -d "venv" ]; then
    echo "Removing old virtual environment..."
    rm -rf venv
fi

echo "Creating fresh virtual environment..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip setuptools wheel -q
pip install -r requirements.txt -q
deactivate

# Restart dashboard service
echo "[4/6] Restarting dashboard service..."
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
echo "[5/6] Restarting orchestrator..."
systemctl restart nexus-orchestrator
sleep 1

if systemctl is-active --quiet nexus-orchestrator; then
    echo "✓ Orchestrator is running"
else
    echo "✗ Orchestrator failed to start"
    journalctl -u nexus-orchestrator -n 20
fi

# Restart worker
echo "[6/6] Restarting worker..."
systemctl restart nexus-worker
sleep 1

if systemctl is-active --quiet nexus-worker; then
    echo "✓ Worker is running"
else
    echo "✗ Worker failed to start"
    journalctl -u nexus-worker -n 20
fi

echo ""
echo "=== Service Status ==="
echo ""
consul members
echo ""
systemctl status consul --no-pager -l
systemctl status nexus-orchestrator --no-pager -l
systemctl status nexus-worker --no-pager -l
systemctl status nexus-dashboard --no-pager -l

echo ""
echo "=== Access Points ==="
echo "Consul UI: http://64.181.212.50:8500"
echo "Dashboard: http://64.181.212.50:9000"
echo ""
echo "Done!"
