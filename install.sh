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

# --- Colors (MUST BE DEFINED FIRST) ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
err() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# --- Dynamic Environment Detection ---
# Auto-detect private IP (works on ARM64 and AMD64)
PRIVATE_IP="$(hostname -I | awk '{print $1}')"
if [ -z "$PRIVATE_IP" ] || [ "$PRIVATE_IP" == "127.0.0.1" ]; then
    # Fallback: try to get IP from default route
    PRIVATE_IP="$(ip route get 1 2>/dev/null | awk '{print $7; exit}')"
fi
if [ -z "$PRIVATE_IP" ]; then
    PRIVATE_IP="unknown"
fi

# Detect domain (try multiple methods)
DETECTED_DOMAIN="$(hostname -d 2>/dev/null)"
if [ -z "$DETECTED_DOMAIN" ]; then
    DETECTED_DOMAIN="$(dnsdomainname 2>/dev/null)"
fi
if [ -z "$DETECTED_DOMAIN" ]; then
    DETECTED_DOMAIN="local.domain"
fi

# Try to detect public IP (for cloud instances)
PUBLIC_IP="$(curl -s -m 5 ifconfig.me 2>/dev/null || curl -s -m 5 icanhazip.com 2>/dev/null || echo "")"

# Display auto-detected values
echo -e "${BLUE}=== Auto-Detected Environment ===${NC}"
echo "Architecture: Detecting..."
echo "Private IP: ${PRIVATE_IP}"
if [ -n "$PUBLIC_IP" ]; then
    echo "Public IP (detected): ${PUBLIC_IP}"
fi
echo "Domain (detected): ${DETECTED_DOMAIN}"
echo ""

# Smart IP configuration for cloud instances
echo -e "${YELLOW}Network Configuration:${NC}"
if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "$PRIVATE_IP" ]; then
    # Cloud instance detected (public IP differs from private IP)
    echo -e "${GREEN}✓ Cloud instance detected (Oracle, AWS, GCP, Azure)${NC}"
    echo ""
    echo "Your instance has:"
    echo "  - Private IP: ${PRIVATE_IP} (bound to network interface)"
    echo "  - Public IP:  ${PUBLIC_IP} (NAT'd by cloud provider)"
    echo ""
    echo -e "${YELLOW}IMPORTANT: Consul must bind to PRIVATE IP, not public IP!${NC}"
    echo "  bind_addr:      ${PRIVATE_IP}  (what Consul binds to)"
    echo "  advertise_addr: ${PUBLIC_IP}   (what Consul advertises)"
    echo ""
    read -p "Press Enter to use PRIVATE IP (${PRIVATE_IP}) for Consul [recommended]: " USER_CONFIRM
    
    # Always use private IP for bind, public for advertise in cloud
    BIND_IP="$PRIVATE_IP"
    ADVERTISE_IP="$PUBLIC_IP"
    echo -e "${GREEN}✓ Using private IP for bind_addr: ${BIND_IP}${NC}"
    echo -e "${GREEN}✓ Using public IP for advertise_addr: ${ADVERTISE_IP}${NC}"
else
    # Non-cloud or single IP instance
    echo "Single IP detected: ${PRIVATE_IP}"
    read -p "Enter server IP (press Enter for ${PRIVATE_IP}): " USER_IP
    if [ -z "$USER_IP" ]; then
        BIND_IP="$PRIVATE_IP"
    else
        BIND_IP="$USER_IP"
    fi
    ADVERTISE_IP="$BIND_IP"
fi

# Validate IP was provided
if [ -z "$BIND_IP" ] || [ "$BIND_IP" == "unknown" ]; then
    err "Server IP is required"
fi

# Ask user for domain
echo ""
echo -e "${YELLOW}Domain Configuration:${NC}"
echo "Detected domain: ${DETECTED_DOMAIN}"
read -p "Enter domain name (press Enter for '${DETECTED_DOMAIN}', or input custom): " USER_DOMAIN
if [ -z "$USER_DOMAIN" ]; then
    DOMAIN="$DETECTED_DOMAIN"
else
    DOMAIN="$USER_DOMAIN"
fi

# Store for compatibility
SERVER_IP="$BIND_IP"
if [ -z "$ADVERTISE_IP" ]; then
    ADVERTISE_IP="$BIND_IP"
fi

echo -e "${BLUE}"
cat << 'EOF'
╔══════════════════════════════════════════════╗
║   Krutrim Nexus Ops - HA Installation        ║
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
log "Architecture: ${ARCH_LABEL} (${ARCH})"
log "OS: $([ -f /etc/debian_version ] && echo 'Debian/Ubuntu' || [ -f /etc/oracle-release ] && echo 'Oracle Linux' || echo 'Other')"

# Display final configuration for user confirmation
echo ""
echo -e "${GREEN}=== Final Installation Configuration ===${NC}"
echo -e "${BLUE}System:${NC}"
echo "  Architecture: ${ARCH_LABEL} (${ARCH})"
echo "  OS: $([ -f /etc/debian_version ] && echo 'Debian/Ubuntu' || [ -f /etc/oracle-release ] && echo 'Oracle Linux' || echo 'Other')"
echo ""
echo -e "${BLUE}Network:${NC}"
if [ "$BIND_IP" != "$ADVERTISE_IP" ]; then
    echo "  Bind IP (Consul binds to):      ${BIND_IP}"
    echo "  Advertise IP (Consul advertises): ${ADVERTISE_IP}"
else
    echo "  Server IP: ${BIND_IP}"
fi
echo "  Domain: ${DOMAIN}"
if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "$BIND_IP" ]; then
    echo "  Public IP (detected): ${PUBLIC_IP}"
fi
if [ -n "$PRIVATE_IP" ] && [ "$PRIVATE_IP" != "$BIND_IP" ]; then
    echo "  Private IP (detected): ${PRIVATE_IP}"
fi
echo ""
echo -e "${BLUE}Installation:${NC}"
echo "  Consul Version: ${CONSUL_VERSION}"
echo "  Installation Path: ${NEXUS_HOME}"
echo ""
echo -e "${YELLOW}These values will be used for Consul bind_addr, dashboard endpoints, etc.${NC}"
read -p "Proceed with installation? [Y/n]: " confirm
if [[ "$confirm" =~ ^([nN][oO]|[nN])$ ]]; then
    echo -e "${RED}Installation cancelled by user${NC}"
    exit 0
fi

# --- Pre-flight Validation ---
prevalidate_environment() {
    local errors=0
    
    echo ""
    log "Running pre-flight checks..."
    
    # Check root
    if [ "$EUID" -ne 0 ]; then
        err "This script must be run as root (use sudo)"
    fi
    
    # Check OS
    if [ ! -f /etc/debian_version ] && [ ! -f /etc/arch-release ]; then
        warn "Unsupported OS detected. This script supports Debian/Ubuntu and Arch Linux."
        errors=$((errors + 1))
    fi
    
    # Check disk space
    local free_space
    free_space=$(df / | awk 'NR==2 {print $4}')
    if [ "$free_space" -lt 2097152 ]; then  # Less than 2GB
        warn "Low disk space: $(df -h / | awk 'NR==2 {print $4}') free. Minimum 2GB recommended."
        errors=$((errors + 1))
    fi
    
    # Check memory
    local free_mem
    free_mem=$(free -m | awk 'NR==2 {print $7}')
    if [ "$free_mem" -lt 512 ]; then
        warn "Low memory: ${free_mem}MB available. Minimum 512MB recommended."
        errors=$((errors + 1))
    fi
    
    # Check network connectivity
    if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        warn "Network connectivity test failed. Internet access may be required."
        errors=$((errors + 1))
    fi
    
    # Check required commands
    for cmd in systemctl wget curl unzip; do
        if ! command -v "$cmd" &>/dev/null; then
            warn "Required command not found: $cmd (will be installed)"
        fi
    done
    
    # Check Python 3
    if ! command -v python3 &>/dev/null; then
        warn "Python 3 not found (will be installed)"
    else
        local py_version
        py_version=$(python3 --version | awk '{print $2}' | cut -d. -f1,2)
        log "Python version: $py_version"
        if [ "${py_version//./}" -lt 38 ]; then
            warn "Python 3.8+ recommended, found $py_version"
            errors=$((errors + 1))
        fi
    fi
    
    # Check for existing Consul ports
    log "Checking for port conflicts..."
    local consul_ports_used=false
    for port in 8500 8600 8301 8302; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            warn "Port $port already in use (will attempt cleanup)"
            consul_ports_used=true
        fi
    done
    
    if [ "$errors" -gt 0 ]; then
        warn "Pre-flight checks completed with $errors warnings"
        read -p "Continue anyway? [y/N]: " response
        if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            err "Installation cancelled by user"
        fi
    else
        log "Pre-flight checks passed"
    fi
}

prevalidate_environment

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
        log "Updating package lists..."
        apt-get update -y -qq > /dev/null 2>&1
        log "Installing system packages (this may take a few minutes)..."
        apt-get install -y -qq curl wget unzip jq git python3 python3-pip python3-yaml python3-docker \
            openssh-server rsync net-tools htop vim docker.io docker-compose > /dev/null 2>&1
        echo -e "${GREEN}✓ System packages installed${NC}"
    elif [ -f /etc/arch-release ]; then
        pacman -Sy --noconfirm curl wget unzip jq git python python-pip python-yaml \
            openssh rsync net-tools htop vim docker docker-compose
    fi
    
    systemctl enable docker
    systemctl start docker
    log "Base dependencies installed"
}

# --- Consul Cleanup ---
cleanup_consul() {
    log "Cleaning up any existing Consul processes..."
    
    # Stop any running Consul service
    systemctl stop consul 2>/dev/null || true
    
    # Kill any stray Consul processes
    pkill -9 consul 2>/dev/null || true
    sleep 1
    
    # Reset systemd failure state
    systemctl reset-failed consul 2>/dev/null || true
    
    # Clean up data directory (preserve config)
    if [ -d "/var/consul" ]; then
        log "Cleaning Consul data directory..."
        rm -rf /var/consul/*
    fi
    
    # Remove any lock files
    rm -f /var/consul/.lock 2>/dev/null || true
    
    log "Consul cleanup complete"
}

# --- Service Discovery (Consul) ---
install_consul() {
    local mode="$1"  # client or server
    log "Installing Consul ($mode mode)..."
    
    # Clean up any previous failed Consul installations
    cleanup_consul
    
    local already_installed=false
    if command -v consul &>/dev/null; then
        log "Consul already installed: $(consul version | head -1)"
        already_installed=true
    fi
    
    # Only download and install if not already installed
    if [ "$already_installed" = false ]; then
        cd /tmp
        wget -q "https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_${CONSUL_ARCH}.zip"
        unzip -q consul_${CONSUL_VERSION}_linux_${CONSUL_ARCH}.zip
        mv consul /usr/local/bin/
        chmod +x /usr/local/bin/consul
    fi
    
    mkdir -p /etc/consul.d /var/consul
    
    if [ "$mode" == "server" ]; then
        log "Configuring Consul server with bind_addr=$BIND_IP, advertise_addr=$ADVERTISE_IP"
        cat > /etc/consul.d/consul.json <<EOF
{
  "server": true,
  "bootstrap_expect": 1,
  "data_dir": "/var/consul",
  "datacenter": "krutrim-dc1",
  "bind_addr": "$BIND_IP",
  "advertise_addr": "$ADVERTISE_IP",
  "client_addr": "0.0.0.0",
  "ui_config": {
    "enabled": true
  },
  "log_level": "INFO",
  "enable_syslog": false
}
EOF
    else
        read -p "Enter Manager IP for Consul cluster: " manager_ip
        log "Configuring Consul client with bind_addr=$BIND_IP, advertise_addr=$ADVERTISE_IP, joining $manager_ip"
        cat > /etc/consul.d/client.json <<EOF
{
  "server": false,
  "data_dir": "/var/consul",
  "datacenter": "krutrim-dc1",
  "bind_addr": "$BIND_IP",
  "advertise_addr": "$ADVERTISE_IP",
  "client_addr": "0.0.0.0",
  "retry_join": ["$manager_ip"],
  "log_level": "INFO",
  "enable_syslog": false
}
EOF
    fi
    
    # Validate Consul configuration
    log "Validating Consul configuration..."
    if ! /usr/local/bin/consul validate /etc/consul.d 2>&1 | tee /tmp/consul_validate.log; then
        error "Consul configuration validation failed!"
        cat /tmp/consul_validate.log
        return 1
    fi
    log "Consul configuration validated successfully"
    
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
    
    # Ensure service file exists and is configured
    if [ "$already_installed" = false ]; then
        systemctl daemon-reload
    fi
    
    # Always ensure service is enabled and running
    systemctl daemon-reload
    systemctl enable consul 2>/dev/null || true
    
    # Check if already running
    if systemctl is-active --quiet consul 2>/dev/null; then
        log "Consul service already running"
    else
        log "Starting Consul service..."
        
        # Check for port conflicts BEFORE starting
        log "Checking for port conflicts..."
        local ports_in_use=()
        for port in 8500 8600 8301 8302; do
            if netstat -tuln 2>/dev/null | grep -q ":$port "; then
                ports_in_use+=("$port")
            fi
        done
        
        if [ ${#ports_in_use[@]} -gt 0 ]; then
            error "Consul ports already in use: ${ports_in_use[*]}"
            echo "Processes using Consul ports:"
            for port in "${ports_in_use[@]}"; do
                echo "Port $port:"
                lsof -i ":$port" 2>/dev/null || netstat -tulnp | grep ":$port"
            done
            return 1
        fi
        
        # Start Consul and capture any immediate errors
        log "Starting Consul with bind address: $BIND_IP"
        if ! systemctl start consul 2>&1 | tee /tmp/consul_start.log; then
            error "Failed to start Consul service"
            echo "Recent Consul logs:"
            journalctl -u consul -n 30 --no-pager
            echo ""
            echo "Consul config:"
            cat /etc/consul.d/*.json 2>/dev/null || true
            echo ""
            echo "Network interfaces:"
            ip addr show
            return 1
        fi
        
        # Wait for Consul to be ready
        log "Waiting for Consul to start..."
        local max_wait=30
        local waited=0
        while ! systemctl is-active --quiet consul 2>/dev/null; do
            if [ $waited -ge $max_wait ]; then
                error "Consul failed to start after ${max_wait}s"
                echo "Consul service status:"
                systemctl status consul --no-pager -l || true
                echo ""
                echo "Recent Consul logs:"
                journalctl -u consul -n 50 --no-pager
                echo ""
                echo "Checking for port conflicts:"
                netstat -tuln | grep -E ':(8500|8600|8301|8302)' || echo "No conflicts found"
                return 1
            fi
            
            # Check if service failed during startup
            if systemctl is-failed --quiet consul 2>/dev/null; then
                error "Consul service failed during startup"
                journalctl -u consul -n 30 --no-pager
                return 1
            fi
            
            sleep 1
            waited=$((waited + 1))
        done
    fi
    
    # Additional wait for Consul to be fully ready
    sleep 2
    
    if consul members &>/dev/null; then
        log "Consul installed and running"
    else
        warn "Consul service started but not yet responding"
    fi
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
    
    # Stop existing service if running (for re-installation)
    if systemctl is-active --quiet nexus-dashboard 2>/dev/null; then
        log "Stopping existing dashboard service..."
        systemctl stop nexus-dashboard
    fi
    
    # Install Python virtual environment package
    if [ -f /etc/debian_version ]; then
        apt-get install -y -qq python3-venv python3-full > /dev/null 2>&1
    fi
    
    cd "$backend_path"
    
    # Remove broken/old venv if it exists
    if [ -d "venv" ]; then
        log "Removing old virtual environment..."
        rm -rf venv
    fi
    
    # Create fresh virtual environment
    log "Creating Python virtual environment..."
    python3 -m venv venv || {
        error "Failed to create virtual environment"
        cd - > /dev/null
        return 1
    }
    
    # Install dependencies with error handling
    log "Installing dashboard dependencies (this may take a few minutes)..."
    source venv/bin/activate
    
    # Upgrade pip first (quietly)
    log "Upgrading pip, setuptools, wheel..."
    pip install --upgrade pip setuptools wheel -q
    
    # Install requirements with retry logic
    local max_attempts=3
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        log "Installing dashboard dependencies (attempt $attempt/$max_attempts)..."
        if pip install -r requirements.txt -q --no-cache-dir 2>&1 | grep -E "(Successfully installed|ERROR|error)" || [ ${PIPESTATUS[0]} -eq 0 ]; then
            echo -e "${GREEN}✓ Dependencies installed successfully${NC}"
            break
        else
            if [ $attempt -eq $max_attempts ]; then
                error "Failed to install dependencies after $max_attempts attempts"
                echo "Run manually: cd dashboard/backend && source venv/bin/activate && pip install -r requirements.txt"
                deactivate
                cd - > /dev/null
                return 1
            fi
            warn "Installation failed, retrying in 5 seconds..."
            sleep 5
            attempt=$((attempt + 1))
        fi
    done
    
    deactivate
    
    # Verify critical files exist
    if [ ! -f "app.py" ]; then
        error "app.py not found in $backend_path"
        cd - > /dev/null
        return 1
    fi
    
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
    
    # Wait a moment and check if service started successfully
    sleep 2
    if systemctl is-active --quiet nexus-dashboard; then
        log "Dashboard service started successfully"
    else
        warn "Dashboard service may have failed to start. Check: journalctl -u nexus-dashboard -n 50"
    fi
    
    # Open firewall if ufw is active
    if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
        log "Opening firewall port 9000..."
        ufw allow 9000/tcp 2>/dev/null || true
    fi
    
    log "Dashboard installed successfully!"
    echo -e "${GREEN}Dashboard URL: http://$SERVER_IP:9000${NC}"
    echo -e "${YELLOW}Check status: systemctl status nexus-dashboard${NC}"
    echo -e "${YELLOW}View logs: journalctl -u nexus-dashboard -f${NC}"
    
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

# --- Validation ---
validate_installation() {
    local has_errors=false
    
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  VALIDATING INSTALLATION"
    echo "═══════════════════════════════════════════════"
    echo ""
    
    # Check Consul
    echo -n "Checking Consul... "
    if systemctl is-active --quiet consul 2>/dev/null; then
        echo -e "${GREEN}✓ Running${NC}"
    else
        echo -e "${YELLOW}✗ NOT RUNNING (attempting to fix)${NC}"
        echo "  Restarting Consul..."
        systemctl restart consul
        sleep 3
        if systemctl is-active --quiet consul 2>/dev/null; then
            echo -e "${GREEN}  ✓ Consul restarted successfully${NC}"
        else
            echo -e "${RED}  ✗ ERROR: Consul failed to start!${NC}"
            echo -e "${YELLOW}  Check logs: journalctl -u consul -n 50${NC}"
            has_errors=true
        fi
    fi
    
    # Check Orchestrator (if manager or both)
    if [[ "$ROLE" == "manager" ]] || [[ "$ROLE" == "both" ]]; then
        echo -n "Checking Orchestrator... "
        if systemctl is-active --quiet nexus-orchestrator 2>/dev/null; then
            echo -e "${GREEN}✓ Running${NC}"
        else
            echo -e "${YELLOW}✗ NOT RUNNING (attempting to fix)${NC}"
            echo "  Restarting Orchestrator..."
            systemctl restart nexus-orchestrator
            sleep 2
            if systemctl is-active --quiet nexus-orchestrator 2>/dev/null; then
                echo -e "${GREEN}  ✓ Orchestrator restarted successfully${NC}"
            else
                echo -e "${RED}  ✗ ERROR: Orchestrator failed to start!${NC}"
                echo -e "${YELLOW}  Check logs: journalctl -u nexus-orchestrator -n 50${NC}"
                has_errors=true
            fi
        fi
    fi
    
    # Check Worker
    if [[ "$ROLE" == "worker" ]] || [[ "$ROLE" == "both" ]]; then
        echo -n "Checking Worker... "
        if systemctl is-active --quiet nexus-worker 2>/dev/null; then
            echo -e "${GREEN}✓ Running${NC}"
        else
            echo -e "${YELLOW}✗ NOT RUNNING (attempting to fix)${NC}"
            echo "  Restarting Worker..."
            systemctl restart nexus-worker
            sleep 2
            if systemctl is-active --quiet nexus-worker 2>/dev/null; then
                echo -e "${GREEN}  ✓ Worker restarted successfully${NC}"
            else
                echo -e "${RED}  ✗ ERROR: Worker failed to start!${NC}"
                echo -e "${YELLOW}  Check logs: journalctl -u nexus-worker -n 50${NC}"
                has_errors=true
            fi
        fi
    fi
    
    # Check Dashboard (if it was installed)
    if systemctl is-enabled --quiet nexus-dashboard 2>/dev/null; then
        echo -n "Checking Dashboard... "
        if systemctl is-active --quiet nexus-dashboard 2>/dev/null; then
            echo -e "${GREEN}✓ Running${NC}"
            echo -e "${GREEN}  Access at: http://$SERVER_IP:9000${NC}"
        else
            echo -e "${YELLOW}✗ NOT RUNNING (attempting to fix)${NC}"
            echo "  Restarting Dashboard..."
            systemctl restart nexus-dashboard
            sleep 2
            if systemctl is-active --quiet nexus-dashboard 2>/dev/null; then
                echo -e "${GREEN}  ✓ Dashboard restarted successfully${NC}"
                echo -e "${GREEN}  Access at: http://$SERVER_IP:9000${NC}"
            else
                echo -e "${RED}  ✗ ERROR: Dashboard failed to start!${NC}"
                echo -e "${YELLOW}  Check logs: journalctl -u nexus-dashboard -n 50${NC}"
                has_errors=true
            fi
        fi
    fi
    
    # Check Consul connectivity
    echo -n "Checking Consul connectivity... "
    if consul members &>/dev/null; then
        echo -e "${GREEN}✓ Connected${NC}"
    else
        echo -e "${YELLOW}✗ FAILED (waiting for Consul)${NC}"
        echo "  Waiting for Consul to be ready..."
        local max_wait=10
        local waited=0
        while ! consul members &>/dev/null; do
            if [ $waited -ge $max_wait ]; then
                echo -e "${RED}  ✗ ERROR: Cannot connect to Consul!${NC}"
                echo -e "${YELLOW}  Check status: systemctl status consul${NC}"
                has_errors=true
                break
            fi
            sleep 1
            waited=$((waited + 1))
        done
        if consul members &>/dev/null; then
            echo -e "${GREEN}  ✓ Consul connectivity established${NC}"
        fi
    fi
    
    # Check Docker
    echo -n "Checking Docker... "
    if systemctl is-active --quiet docker 2>/dev/null; then
        echo -e "${GREEN}✓ Running${NC}"
    else
        echo -e "${RED}✗ NOT RUNNING${NC}"
        echo -e "${RED}  ERROR: Docker service is not running!${NC}"
        echo -e "${YELLOW}  Fix: systemctl start docker${NC}"
        has_errors=true
    fi
    
    echo ""
    echo "═══════════════════════════════════════════════"
    
    if [ "$has_errors" = true ]; then
        echo -e "${RED}  ✗ INSTALLATION COMPLETED WITH ERRORS${NC}"
        echo "═══════════════════════════════════════════════"
        echo ""
        echo -e "${YELLOW}Some services failed to start. Please fix the errors above.${NC}"
        echo ""
        echo -e "${YELLOW}Quick Fix Commands:${NC}"
        echo "  1. Check service logs:"
        echo "     journalctl -u consul -n 50"
        echo "     journalctl -u nexus-orchestrator -n 50"
        echo "     journalctl -u nexus-worker -n 50"
        echo "     journalctl -u nexus-dashboard -n 50"
        echo ""
        echo "  2. Restart all services:"
        echo "     systemctl restart consul"
        echo "     systemctl restart nexus-orchestrator"
        echo "     systemctl restart nexus-worker"
        echo "     systemctl restart nexus-dashboard"
        echo ""
        echo "  3. Or run the fix script:"
        echo "     cd /opt/krutrim-nexus-ops"
        echo "     chmod +x fix-services.sh"
        echo "     sudo ./fix-services.sh"
        echo ""
        return 1
    else
        echo -e "${GREEN}  ✓ ALL SERVICES RUNNING SUCCESSFULLY${NC}"
        echo "═══════════════════════════════════════════════"
        echo ""
        echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║      Krutrim Nexus Ops is now running!      ║${NC}"
        echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${GREEN}Access Points:${NC}"
        echo "  - Consul UI: http://$SERVER_IP:8500"
        if systemctl is-active --quiet nexus-dashboard 2>/dev/null; then
            echo "  - Dashboard: http://$SERVER_IP:9000"
        fi
        echo ""
        echo -e "${GREEN}Useful Commands:${NC}"
        echo "  - Check cluster: consul members"
        echo "  - View services: consul catalog services"
        echo "  - Check logs: journalctl -u nexus-orchestrator -f"
        echo "  - Docker status: docker ps"
        echo ""
        return 0
    fi
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

log "Installation phase complete. Validating..."
validate_installation
