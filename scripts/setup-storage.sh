#!/usr/bin/env bash
# setup-storage.sh - Minimalist Storage (SFTP + Nginx Autoindex)
#
# Usage: ./setup-storage.sh [username]
#
# Features:
# - Creates a restricted SFTP user.
# - Nginx serves the 'public' folder via HTTP (Autoindex).
# - No databases, no complex apps.

set -Eeuo pipefail
USER="${1:-storage}"
WEB_ROOT="/home/$USER/public"

echo "Setting up Storage for user: $USER..."

# 1. Create User
if ! id "$USER" &>/dev/null; then
    useradd -m -s /usr/sbin/nologin "$USER"
    echo "User $USER created. Set password manually with 'passwd $USER'."
fi

# 2. Setup Directories
mkdir -p "$WEB_ROOT"
chown "$USER:$USER" "$WEB_ROOT"
chmod 755 "/home/$USER" # Needed for Nginx to traverse
chmod 755 "$WEB_ROOT"

# 3. Configure SSHD for SFTP Chroot (Optional but recommended)
# We append to sshd_config if not present
if ! grep -q "Match User $USER" /etc/ssh/sshd_config; then
    cat <<EOF >> /etc/ssh/sshd_config

Match User $USER
    ForceCommand internal-sftp
    PasswordAuthentication yes
    ChrootDirectory /home/$USER
    PermitTunnel no
    AllowAgentForwarding no
    AllowTcpForwarding no
    X11Forwarding no
EOF
    # Fix permissions for Chroot (root must own /home/$USER)
    chown root:root "/home/$USER"
    chmod 755 "/home/$USER"
    # Re-create public dir ownership
    chown "$USER:$USER" "$WEB_ROOT"
    
    systemctl restart ssh
    echo "SSHD configured for SFTP chroot."
fi

# 4. Install & Configure Nginx
apt-get install -y nginx

cat <<EOF > /etc/nginx/sites-available/storage
server {
    listen 80;
    server_name _;
    
    root $WEB_ROOT;
    
    location / {
        autoindex on;
        autoindex_exact_size off;
        autoindex_format html;
        autoindex_localtime on;
    }
}
EOF

ln -sf /etc/nginx/sites-available/storage /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

echo "Storage setup complete."
echo "SFTP: sftp $USER@<host>"
echo "HTTP: http://<host>/"
