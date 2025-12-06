#!/usr/bin/env bash
# setup-monitoring.sh - Netdata Installation
# Usage: ./setup-monitoring.sh [parent_ip]

set -Eeuo pipefail
PARENT_IP="${1:-}"

echo "Setting up Netdata Monitoring..."

# 1. Install Netdata (Official Kickstart)
# We use the stable static build for "suckless" reliability across distros
if ! command -v netdata &>/dev/null; then
    wget -O /tmp/netdata-kickstart.sh https://my-netdata.io/kickstart.sh
    sh /tmp/netdata-kickstart.sh --non-interactive --stable-channel
fi

# 2. Configure Streaming (If Worker)
if [ -n "$PARENT_IP" ]; then
    echo "Configuring as Child Node -> Streaming to $PARENT_IP"
    
    cat <<EOF > /etc/netdata/stream.conf
[stream]
    enabled = yes
    destination = $PARENT_IP:19999
    api key = 11111111-2222-3333-4444-555555555555
EOF
    systemctl restart netdata
else
    echo "Configuring as Parent Node (Manager)"
    # Ensure API key exists for children
    cat <<EOF >> /etc/netdata/stream.conf
[11111111-2222-3333-4444-555555555555]
    enabled = yes
EOF
    systemctl restart netdata
fi

echo "Monitoring Setup Complete."
echo "Dashboard: http://<this-ip>:19999"
