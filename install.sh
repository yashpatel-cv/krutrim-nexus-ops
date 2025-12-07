#!/usr/bin/env bash
# install.sh - Krutrim Nexus Ops HA Setup
#
# Usage: sudo ./install.sh
# High Availability Manager-Worker Architecture
# Supports: Manager-only, Worker-only, or Both on same machine

set -Eeuo pipefail
NEXUS_HOME="/opt/nexus"
CLUSTER_FILE="$NEXUS_HOME/cluster.yml"
CONSUL_VERSION="1.17.0"
DOMAIN="krutrimseva.cbu.net"
SERVER_IP="64.181.212.50"

# --- Colors ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
err() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

echo -e "${BLUE}"
cat << 'EOF'
╔══════════════════════════════════════════════╗
║   Krutrim Nexus Ops - HA Installation       ║
║   Manager-Worker High Availability Pattern   ║
╚══════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# --- Architecture Detection ---
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)  ARCH_LABEL="amd64"; CONSUL_ARCH="amd64" ;;
    aarch64) ARCH_LABEL="arm64"; CONSUL_ARCH="arm64" ;;
    armv7l)  ARCH_LABEL="armv7"; CONSUL_ARCH="arm" ;;
    *)       err "Unsupported architecture: $ARCH" ;;
esac
log "Detected architecture: ${ARCH_LABEL}"

# --- Interactive Role Selection ---
ROLE=""
if [ -z "${1:-}" ]; then
    echo ""
    echo -e "${YELLOW}Select deployment mode:${NC}"
    echo "  1) Manager Only    (Control plane, orchestration)"
    echo "  2) Worker Only     (Execution node)"
    echo "  3) Both            (Manager + Worker on same machine - Oracle setup)"
    echo "  4) Load Balancer   (Caddy reverse proxy)"
    echo ""
    read -p "Select [1/2/3/4]: " choice
    case "$choice" in
        1) ROLE="manager" ;;
        2) ROLE="worker" ;;
        3) ROLE="both" ;;
        4) ROLE="loadbalancer" ;;
        *) err "Invalid choice." ;;
    esac
else
    if [[ "$1" == "--role" && -n "${2:-}" ]]; then
        ROLE="$2"
    fi
fi

log "Deployment mode: ${ROLE}"

# --- Common Dependencies ---
install_base_deps() {
    log "Installing base dependencies..."
    if [ -f /etc/debian_version ]; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y
        apt-get install -y curl wget unzip jq git python3 python3-pip python3-yaml python3-docker \
            openssh-server rsync net-tools htop vim docker.io docker-compose
    elif [ -f /etc/arch-release ]; then
        pacman -Sy --noconfirm curl wget unzip jq git python python-pip python-yaml \
            openssh rsync net-tools htop vim docker docker-compose
    fi
    
    systemctl enable docker
    systemctl start docker
    log "Base dependencies installed"
}

# --- Service Discovery (Consul) ---
install_consul() {
    local mode="$1"  # client or server
    log "Installing Consul ($mode mode)..."
    
    if command -v consul &>/dev/null; then
        log "Consul already installed: $(consul version | head -1)"
        return
    fi
    
    cd /tmp
    wget -q "https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_${CONSUL_ARCH}.zip"
    unzip -q consul_${CONSUL_VERSION}_linux_${CONSUL_ARCH}.zip
    mv consul /usr/local/bin/
    chmod +x /usr/local/bin/consul
    
    mkdir -p /etc/consul.d /var/consul
    
    if [ "$mode" == "server" ]; then
        cat > /etc/consul.d/server.json <<EOF
{
  "server": true,
  "bootstrap_expect": 1,
  "data_dir": "/var/consul",
  "datacenter": "krutrim-dc1",
  "bind_addr": "0.0.0.0",
  "client_addr": "0.0.0.0",
  "ui_config": {
    "enabled": true
  },
  "log_level": "INFO"
}
EOF
    else
        read -p "Enter Manager IP for Consul cluster: " manager_ip
        cat > /etc/consul.d/client.json <<EOF
{
  "server": false,
  "data_dir": "/var/consul",
  "datacenter": "krutrim-dc1",
  "bind_addr": "0.0.0.0",
  "client_addr": "0.0.0.0",
  "retry_join": ["$manager_ip"],
  "log_level": "INFO"
}
EOF
    fi
    
    cat > /etc/systemd/system/consul.service <<'EOF'
[Unit]
Description=Consul Service Discovery
Documentation=https://www.consul.io/
After=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable consul
    systemctl start consul
    log "Consul installed and started"
}

# --- Manager Setup ---
ensure_manager_role() {
    local this_host
    this_host="$(hostnamectl --static 2>/dev/null || hostname)"

    if [ -f "$CLUSTER_FILE" ]; then
        local existing
        existing="$(grep '^manager_host:' "$CLUSTER_FILE" | awk '{print $2}')"
        if [ -n "$existing" ] && [ "$existing" != "$this_host" ]; then
            warn "Cluster already has a manager on: $existing"
            read -r -p "Add this node as SECONDARY manager? [y/N]: " answer
            case "$answer" in
                Y|y) log "Configuring as secondary manager..."; return 0 ;;
                *) err "Refusing to configure multiple primary managers." ;;
            esac
        fi
        log "Manager role already configured on this host"
        return 0
    fi

    mkdir -p "$NEXUS_HOME"
    {
        echo "cluster_id: krutrim-$(date +%s)"
        echo "manager_host: $this_host"
        echo "manager_ip: $SERVER_IP"
        echo "domain: $DOMAIN"
        echo "created_at: $(date -Iseconds)"
        echo "role: primary"
    } > "$CLUSTER_FILE"
    log "Cluster metadata created"
}

create_orchestrator() {
    log "Creating orchestration service..."
    cat > "$NEXUS_HOME/orchestrator.py" <<'PYEOF'
#!/usr/bin/env python3
import subprocess
import time
import json
import sys

def check_consul():
    try:
        result = subprocess.run(['consul', 'catalog', 'nodes', '-format=json'],
                              capture_output=True, text=True, check=True)
        nodes = json.loads(result.stdout)
        return len(nodes)
    except:
        return 0

def check_services():
    try:
        result = subprocess.run(['consul', 'catalog', 'services', '-format=json'],
                              capture_output=True, text=True, check=True)
        services = json.loads(result.stdout)
        return services
    except:
        return {}

def monitor_cluster():
    print("[Orchestrator] Starting cluster monitor...")
    while True:
        nodes = check_consul()
        services = check_services()
        
        print(f"[Orchestrator] Active nodes: {nodes}, Services: {list(services.keys())}")
        
        # Health check logic
        if nodes == 0:
            print("[Orchestrator] WARNING: No consul nodes detected!")
        
        time.sleep(30)

if __name__ == '__main__':
    try:
        monitor_cluster()
    except KeyboardInterrupt:
        print("[Orchestrator] Stopped")
        sys.exit(0)
PYEOF

    chmod +x "$NEXUS_HOME/orchestrator.py"
    
    cat > /etc/systemd/system/nexus-orchestrator.service <<EOF
[Unit]
Description=Krutrim Nexus Orchestrator
After=consul.service docker.service
Requires=consul.service

[Service]
Type=simple
User=root
WorkingDirectory=$NEXUS_HOME
ExecStart=/usr/bin/python3 $NEXUS_HOME/orchestrator.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable nexus-orchestrator
    systemctl start nexus-orchestrator
    log "Orchestrator service created"
}

# --- Dashboard Installation ---
install_dashboard() {
    log "Installing Nexus Dashboard (Web UI)..."
    
    local dashboard_path="$(pwd)/dashboard"
    local backend_path="$dashboard_path/backend"
    
    if [ ! -d "$backend_path" ]; then
        warn "Dashboard directory not found at $dashboard_path"
        return 1
    fi
    
    # Install Python virtual environment package
    if [ -f /etc/debian_version ]; then
        apt-get install -y python3-venv python3-full
    fi
    
    # Create virtual environment
    cd "$backend_path"
    log "Creating Python virtual environment..."
    python3 -m venv venv
    
    # Install dependencies
    log "Installing dashboard dependencies..."
    source venv/bin/activate
    pip install -r requirements.txt
    deactivate
    
    # Install systemd service
    log "Installing dashboard service..."
    local service_file="$(pwd)/../../config/systemd/nexus-dashboard.service"
    
    if [ -f "$service_file" ]; then
        # Update service file with correct paths
        sed -e "s|WorkingDirectory=.*|WorkingDirectory=$backend_path|g" \
            -e "s|ExecStart=.*|ExecStart=$backend_path/venv/bin/uvicorn app:app --host 0.0.0.0 --port 9000|g" \
            "$service_file" > /etc/systemd/system/nexus-dashboard.service
    else
        # Create service file if not exists
        cat > /etc/systemd/system/nexus-dashboard.service <<EOF
[Unit]
Description=Krutrim Nexus Dashboard
After=network.target consul.service
Requires=consul.service

[Service]
Type=simple
User=root
WorkingDirectory=$backend_path
ExecStart=$backend_path/venv/bin/uvicorn app:app --host 0.0.0.0 --port 9000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    fi
    
    # Start dashboard service
    systemctl daemon-reload
    systemctl enable nexus-dashboard
    systemctl start nexus-dashboard
    
    # Open firewall if ufw is active
    if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
        log "Opening firewall port 9000..."
        ufw allow 9000/tcp
    fi
    
    log "Dashboard installed successfully!"
    echo -e "${GREEN}Dashboard URL: http://$SERVER_IP:9000${NC}"
    
    cd - > /dev/null
}

setup_manager() {
    log "Setting up Manager node..."
    
    ensure_manager_role
    install_base_deps
    install_consul "server"
    
    # Install Python dependencies (pyyaml and docker already installed via apt)
    pip3 install python-consul --break-system-packages 2>/dev/null || true
    
    # Copy nexus files
    mkdir -p "$NEXUS_HOME"
    for f in nexus.py inventory.yml services.yml bootstrap_worker.sh run-services.sh services.py proc_ipc.py; do
        [ -f "$f" ] && cp "$f" "$NEXUS_HOME/" || warn "$f not found, skipping"
    done
    
    # Copy config files
    for f in config/*.conf config/*.service config/torrc; do
        [ -f "$f" ] && cp "$f" "$NEXUS_HOME/" || true
    done
    
    # Copy setup scripts
    for f in scripts/setup-*.sh; do
        [ -f "$f" ] && cp "$f" "$NEXUS_HOME/" || true
    done

    [ -f "$NEXUS_HOME/nexus.py" ] && chmod +x "$NEXUS_HOME/nexus.py" && \
        ln -sf "$NEXUS_HOME/nexus.py" /usr/local/bin/nexus

    # SSH Key
    if [ ! -f ~/.ssh/id_rsa ]; then
        log "Generating SSH key..."
        mkdir -p ~/.ssh && chmod 700 ~/.ssh
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -q
    fi
    
    # Create orchestrator
    create_orchestrator
    
    # Prompt for dashboard installation
    echo ""
    echo -e "${YELLOW}Would you like to install the Web Dashboard (recommended)? [Y/n]${NC}"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY]|)$ ]]; then
        install_dashboard
    else
        log "Skipping dashboard installation"
        echo -e "${YELLOW}To install later, run: cd dashboard/backend && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt${NC}"
    fi
    
    log "Manager setup complete!"
    echo ""
    echo -e "${GREEN}Next steps:${NC}"
    echo "  1. Consul UI: http://$SERVER_IP:8500"
    echo "  2. Add worker IPs to: $NEXUS_HOME/inventory.yml"
    echo "  3. Run on workers: curl -sSL http://$SERVER_IP/install.sh | sudo bash -s -- --role worker"
}

# --- Worker Setup ---
register_worker_service() {
    local service_name="$1"
    local port="$2"
    
    log "Registering service: $service_name on port $port"
    cat > /etc/consul.d/${service_name}.json <<EOF
{
  "service": {
    "name": "$service_name",
    "port": $port,
    "check": {
      "http": "http://localhost:$port/health",
      "interval": "10s",
      "timeout": "5s"
    }
  }
}
EOF
    consul reload
}

setup_worker() {
    log "Setting up Worker node..."
    
    install_base_deps
    install_consul "client"
    
    # Worker services setup
    mkdir -p "$NEXUS_HOME"
    
    for f in run-services.sh services.py proc_ipc.py services.yml; do
        [ -f "$f" ] && cp "$f" "$NEXUS_HOME/" || warn "$f not found"
    done
    
    # Create worker agent
    cat > /etc/systemd/system/nexus-worker.service <<EOF
[Unit]
Description=Krutrim Nexus Worker Agent
After=consul.service docker.service
Requires=consul.service

[Service]
Type=simple
User=root
WorkingDirectory=$NEXUS_HOME
ExecStart=/opt/nexus/run-services.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable nexus-worker
    systemctl start nexus-worker
    
    log "Worker setup complete!"
    echo -e "${GREEN}Worker registered with cluster${NC}"
}

# --- Load Balancer Setup ---
setup_loadbalancer() {
    log "Setting up Load Balancer (Caddy)..."
    
    install_base_deps
    
    # Install Caddy
    if ! command -v caddy &>/dev/null; then
        log "Installing Caddy..."
        if [ -f /etc/debian_version ]; then
            apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | \
                gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | \
                tee /etc/apt/sources.list.d/caddy-stable.list
            apt update
            apt install -y caddy
        fi
    fi
    
    # Create Caddyfile with HA configuration
    cat > /etc/caddy/Caddyfile <<EOF
{
    email admin@${DOMAIN}
    admin off
}

# Main domain with load balancing
${DOMAIN} {
    reverse_proxy {
        # Dynamic upstream from Consul
        # Add worker IPs here
        to localhost:8080 localhost:8081 localhost:8082
        
        lb_policy least_conn
        lb_try_duration 10s
        lb_try_interval 1s
        
        health_uri /health
        health_interval 10s
        health_timeout 5s
        
        fail_duration 30s
    }
    
    # Security headers
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
    }
    
    # Logging
    log {
        output file /var/log/caddy/access.log
    }
}

# Consul UI
:8500 {
    reverse_proxy localhost:8500
}
EOF

    systemctl enable caddy
    systemctl restart caddy
    
    log "Load Balancer configured!"
    echo -e "${GREEN}Access points:${NC}"
    echo "  - Main site: https://${DOMAIN}"
    echo "  - Consul UI: http://${SERVER_IP}:8500"
}

# --- Both (Manager + Worker) Setup ---
setup_both() {
    log "Setting up Manager + Worker (Oracle combined setup)..."
    
    # Setup manager first
    ensure_manager_role
    install_base_deps
    install_consul "server"
    
    # Manager components (pyyaml and docker already installed via apt)
    pip3 install python-consul --break-system-packages 2>/dev/null || true
    
    mkdir -p "$NEXUS_HOME"
    
    # Copy core files
    for f in nexus.py inventory.yml services.yml bootstrap_worker.sh run-services.sh services.py proc_ipc.py; do
        [ -f "$f" ] && cp "$f" "$NEXUS_HOME/" || warn "$f not found"
    done
    
    # Copy config files
    for f in config/*.conf config/*.service config/torrc; do
        [ -f "$f" ] && cp "$f" "$NEXUS_HOME/" || true
    done
    
    # Copy setup scripts
    for f in scripts/setup-*.sh; do
        [ -f "$f" ] && cp "$f" "$NEXUS_HOME/" || true
    done
    
    create_orchestrator
    
    # Worker components on same machine
    cat > /etc/systemd/system/nexus-worker.service <<EOF
[Unit]
Description=Krutrim Nexus Worker Agent (Collocated)
After=consul.service docker.service nexus-orchestrator.service
Requires=consul.service

[Service]
Type=simple
User=root
WorkingDirectory=$NEXUS_HOME
ExecStart=/opt/nexus/run-services.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable nexus-worker
    systemctl start nexus-worker
    
    # Prompt for dashboard installation
    echo ""
    echo -e "${YELLOW}Would you like to install the Web Dashboard (recommended)? [Y/n]${NC}"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY]|)$ ]]; then
        install_dashboard
    else
        log "Skipping dashboard installation"
        echo -e "${YELLOW}To install later, run: cd dashboard/backend && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt${NC}"
    fi
    
    log "Combined Manager+Worker setup complete!"
    echo ""
    echo -e "${GREEN}✓ Manager node: Active${NC}"
    echo -e "${GREEN}✓ Worker node: Active${NC}"
    echo -e "${GREEN}✓ Consul: http://$SERVER_IP:8500${NC}"
    echo ""
    echo "This node is running BOTH manager and worker roles."
}

# --- Execution ---
case "$ROLE" in
    manager)
        setup_manager
        ;;
    worker)
        setup_worker
        ;;
    both)
        setup_both
        ;;
    loadbalancer)
        setup_loadbalancer
        ;;
    *)
        err "Unknown role: $ROLE"
        ;;
esac

log "Installation complete!"
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      Krutrim Nexus Ops is now running!      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Useful commands:${NC}"
echo "  - Check Consul: consul members"
echo "  - View services: consul catalog services"
echo "  - Check logs: journalctl -u nexus-orchestrator -f"
echo "  - Docker status: docker ps"
echo ""
