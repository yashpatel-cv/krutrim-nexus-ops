#!/usr/bin/env bash
# setup-mail.sh - Minimalist Mail Server (Postfix + Dovecot)
# Inspired by Luke Smith's emailwiz.
#
# Usage: ./setup-mail.sh [domain]

set -Eeuo pipefail
DOMAIN="${1:-example.com}"

echo "Setting up Mail for $DOMAIN (The Suckless Way)..."

# 1. Install Packages (Non-interactive)
export DEBIAN_FRONTEND=noninteractive
debconf-set-selections <<< "postfix postfix/mailname string $DOMAIN"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
apt-get install -y postfix dovecot-core dovecot-imapd dovecot-lmtpd opendkim opendkim-tools certbot

# 2. Postfix Configuration
postconf -e "myhostname = mail.$DOMAIN"
postconf -e "mydestination = localhost.$DOMAIN, localhost, $DOMAIN"
postconf -e "myorigin = /etc/mailname"
postconf -e "mynetworks_style = host"
postconf -e "home_mailbox = Mail/Inbox/"
postconf -e "smtpd_sasl_type = dovecot"
postconf -e "smtpd_sasl_path = private/auth"
postconf -e "smtpd_sasl_auth_enable = yes"
postconf -e "smtpd_tls_security_level = may"
postconf -e "smtpd_tls_auth_only = yes"

# 3. Dovecot Configuration (Plain text auth file)
# We use system users by default for simplicity (Luke Smith style), 
# but map them to a simple layout.

cat <<EOF > /etc/dovecot/conf.d/10-auth.conf
disable_plaintext_auth = yes
auth_mechanisms = plain login
!include auth-system.conf.ext
EOF

cat <<EOF > /etc/dovecot/conf.d/10-mail.conf
mail_location = maildir:~/Mail/Inbox
EOF

cat <<EOF > /etc/dovecot/conf.d/10-master.conf
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0666
    user = postfix
    group = postfix
  }
}
EOF

# 4. OpenDKIM
mkdir -p "/etc/opendkim/keys/$DOMAIN"
opendkim-genkey -D "/etc/opendkim/keys/$DOMAIN" -d "$DOMAIN" -s default
chown -R opendkim:opendkim /etc/opendkim/keys

cat <<EOF >> /etc/opendkim.conf
Domain $DOMAIN
KeyFile /etc/opendkim/keys/$DOMAIN/default.private
Selector default
EOF

# 5. Restart
systemctl restart postfix dovecot opendkim

echo "Mail setup complete."
echo "DNS Records needed:"
cat "/etc/opendkim/keys/$DOMAIN/default.txt"
