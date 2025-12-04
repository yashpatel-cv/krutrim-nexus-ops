#!/usr/bin/env bash
#
# install.sh - Krutrim Nexus Ops Cluster Installer
#
# Usage:
#   sudo ./install.sh --role [manager|worker] [--dry-run]
#

set -Eeuo pipefail
trap 'echo "[ERROR] Line $LINENO: Command failed" >&2' ERR

# --- Configuration ---
ROLE="worker" # Default
HOSTNAME_LOCK="krutrim-db-0"
DRY_RUN=false
NEXUS_HOME="/opt/nexus"

# --- Helpers ---
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] [NEXUS] $*"; }
err() { echo "[ERROR] $*" >&2; exit 1; }

require_root() { [ "${EUID:-$(id -u)}" -eq 0 ] || err "Run as root."; }
is_debian() { [ -f /etc/debian_version ]; }
is_arch() { [ -f /etc/arch-release ]; }

# --- Args ---
for arg in "$@"; do
  case $arg in
    --role) shift; ROLE="$1" ;;
    --dry-run) DRY_RUN=true ;;
    *) ;;
  esac
done

# --- Core Setup ---
setup_base() {
    log "Setting up Base System ($ROLE)..."
    if $DRY_RUN; then return; fi

    # OS Detection & Update
    if is_debian; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y
        apt-get install -y curl wget vim git htop rsync net-tools python3-venv python3-pip wireguard
    elif is_arch; then
        pacman -Sy --noconfirm --needed curl wget vim git htop rsync net-tools python wireguard-tools
    fi

    # Create Nexus Home
    mkdir -p "$NEXUS_HOME"
    
    # Firewall (Common)
    if [ -f "nftables.conf" ]; then
        cp "nftables.conf" /etc/nftables.conf
        systemctl enable --now nftables
        nft -f /etc/nftables.conf
    fi

    # Hardening (Common)
    if [ -f "99-hardening.conf" ]; then
        cp "99-hardening.conf" /etc/sysctl.d/99-hardening.conf
        sysctl --system
    fi
}

setup_manager() {
    log "Configuring Manager Node..."
    if $DRY_RUN; then return; fi

    # Install Ansible/Fabric for orchestration (using pip in venv)
    if [ ! -d "$NEXUS_HOME/venv" ]; then
        python3 -m venv "$NEXUS_HOME/venv"
        "$NEXUS_HOME/venv/bin/pip" install fabric pyyaml
    fi

    # Copy Nexus Tools
    cp nexus.py "$NEXUS_HOME/"
    cp inventory.yml "$NEXUS_HOME/" 2>/dev/null || true
    chmod +x "$NEXUS_HOME/nexus.py"
    
    ln -sf "$NEXUS_HOME/nexus.py" /usr/local/bin/nexus

    log "Manager setup complete. Run 'nexus help' to start."
}

setup_worker() {
    log "Configuring Worker Node..."
    if $DRY_RUN; then return; fi

    # Workers need the service orchestrator
    cp services.py proc_ipc.py run-services.sh "$NEXUS_HOME/"
    chmod +x "$NEXUS_HOME/run-services.sh"

    # Create Systemd Unit for Nexus Agent (Service Orchestrator)
    cat <<EOF > /etc/systemd/system/nexus-agent.service
[Unit]
Description=Krutrim Nexus Ops Agent
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$NEXUS_HOME
ExecStart=$NEXUS_HOME/run-services.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now nexus-agent
}

main() {
    require_root
    log "Starting Krutrim Nexus Ops Installer (Role: $ROLE)"
    
    setup_base
    
    if [[ "$ROLE" == "manager" ]]; then
        setup_manager
    else
        setup_worker
    fi
    
    log "Installation Complete."
}

main "$@"
