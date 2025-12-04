# Krutrim Nexus Ops (Minimalist Edition)

## Overview
A "suckless" style server orchestration platform. No heavy agents, no complex databases by default. Just simple scripts, flat files, and standard Unix tools.

## Architecture
- **Manager**: Controls workers via SSH loops (`nexus.py`).
- **Workers**: Dumb nodes running systemd services.
- **Services**:
    - **Mail**: Postfix + Dovecot (Flat file auth).
    - **Storage**: SFTP + Nginx Autoindex.
    - **Web**: Caddy (Load Balancer).
    - **DB**: PostgreSQL.

## Quick Start
1.  **Install Manager**: `sudo ./install.sh --role manager`
2.  **Install Workers**: `sudo ./install.sh --role worker`
3.  **Edit Inventory**: `/opt/nexus/inventory.yml`
4.  **Sync**: `nexus sync`

## Service Scripts
- `setup-mail.sh`: Sets up a full mail server.
- `setup-storage.sh`: Sets up a secure SFTP/HTTP file server.
- `setup-lb.sh`: Sets up a Caddy load balancer.
- `setup-db.sh`: Sets up PostgreSQL.
