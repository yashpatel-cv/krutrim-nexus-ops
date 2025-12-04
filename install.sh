#!/usr/bin/env bash
# install.sh - Krutrim Nexus Ops Setup
#
# Usage: sudo ./install.sh
# Interactive setup for Manager or Worker.

set -Eeuo pipefail
NEXUS_HOME="/opt/nexus"

# --- Colors ---
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}>>> Krutrim Nexus Ops Installer <<<${NC}"

# --- Interactive Role Selection ---
ROLE=""
if [ -z "${1:-}" ]; then
    echo "Which role should this server play?"
    echo "1) Manager (Control Plane - Run this once)"
    echo "2) Worker (Execution Node)"
    read -p "Select [1/2]: " choice
    case "$choice" in
        1) ROLE="manager" ;;
        2) ROLE="worker" ;;
        *) echo "Invalid choice."; exit 1 ;;
    esac
else
    # Support flags if user changes mind later
    if [[ "$1" == "--role" && -n "${2:-}" ]]; then
        ROLE="$2"
    fi
fi

# --- Manager Setup ---
setup_manager() {
    echo -e "${GREEN}>>> Setting up Manager...${NC}"
    
    # Deps
    if [ -f /etc/debian_version ]; then
        apt-get update -y && apt-get install -y python3-yaml python3-pip git rsync
    elif [ -f /etc/arch-release ]; then
        pacman -Sy --noconfirm python-yaml python-pip git rsync
    fi

    # Files
    mkdir -p "$NEXUS_HOME"
    cp nexus.py inventory.yml services.yml "$NEXUS_HOME/"
    cp bootstrap_worker.sh "$NEXUS_HOME/"
    cp run-services.sh services.py proc_ipc.py "$NEXUS_HOME/"
    cp *.conf "$NEXUS_HOME/"
    cp setup-*.sh "$NEXUS_HOME/"

    chmod +x "$NEXUS_HOME/nexus.py"
    ln -sf "$NEXUS_HOME/nexus.py" /usr/local/bin/nexus

    # SSH Key
    if [ ! -f ~/.ssh/id_rsa ]; then
        echo ">>> Generating SSH Key..."
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
    fi

    echo -e "${GREEN}>>> Manager Setup Complete!${NC}"
    echo "1. Add worker IPs to: $NEXUS_HOME/inventory.yml"
    echo "2. Run: nexus bootstrap"
}

# --- Worker Setup ---
setup_worker() {
    echo -e "${GREEN}>>> Worker Setup Information${NC}"
    echo "In the Krutrim Nexus Ops architecture, Workers are best managed remotely."
    echo ""
    echo "Please go to your **Manager** node and run:"
    echo "  nexus bootstrap"
    echo ""
    echo "This will automatically connect to this machine (ensure SSH is open) and set it up."
    echo "If you absolutely must setup manually, you can run:"
    echo "  sudo ./bootstrap_worker.sh"
    echo "(But ensure you copy the necessary config files first!)"
}

# --- Execution ---
if [[ "$ROLE" == "manager" ]]; then
    setup_manager
elif [[ "$ROLE" == "worker" ]]; then
    setup_worker
else
    echo "Unknown role."
    exit 1
fi
