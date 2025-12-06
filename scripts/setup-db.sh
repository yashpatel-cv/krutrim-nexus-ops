#!/usr/bin/env bash
# setup-db.sh - PostgreSQL Setup

set -Eeuo pipefail

echo "Setting up PostgreSQL..."

apt-get install -y postgresql postgresql-contrib

# Listen on all interfaces (Firewall handles security)
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/*/main/postgresql.conf

# Allow password auth from local network (adjust subnet as needed)
echo "host    all             all             10.0.0.0/8            scram-sha-256" >> /etc/postgresql/*/main/pg_hba.conf

systemctl restart postgresql
echo "PostgreSQL setup complete."
