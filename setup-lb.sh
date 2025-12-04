#!/usr/bin/env bash
# setup-lb.sh - Minimalist Load Balancer (Caddy)
#
# Usage: ./setup-lb.sh

set -Eeuo pipefail

echo "Setting up Caddy Load Balancer..."

# 1. Install Caddy
if ! command -v caddy &>/dev/null; then
    apt-get install -y -qq debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    apt-get update
    apt-get install -y caddy
fi

# 2. Configure Caddyfile (Cluster Mode)
# This assumes you edit /etc/caddy/Caddyfile with real IPs later.
cat <<EOF > /etc/caddy/Caddyfile
{
    email admin@example.com
}

# Load Balancer for Web App
example.com {
    reverse_proxy {
        # Add your worker IPs here
        to 10.0.0.2:80 10.0.0.3:80
        
        lb_policy round_robin
        health_uri /health
        health_interval 10s
    }
}

# Load Balancer for API
api.example.com {
    reverse_proxy {
        to 10.0.0.2:8080 10.0.0.3:8080
    }
}
EOF

systemctl enable --now caddy
systemctl reload caddy

echo "Load Balancer setup complete. Edit /etc/caddy/Caddyfile to add worker IPs."
