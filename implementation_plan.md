# Krutrim Nexus Ops - Minimalist Implementation Plan

## Goal Description
Build a "suckless" server orchestration platform. Prioritize standard Unix tools, flat text files, and simple shell scripts over complex binaries and databases. Inspired by Luke Smith's `emailwiz` and general philosophy.

## Architecture Rationale

### 1. The "Suckless" Cluster
*   **Manager**: Just a machine with SSH keys and a python script (`nexus.py`) that loops over a list of IPs. No "agents" listening on sockets.
*   **Worker**: Standard Linux box. Services run as systemd units. Configuration is done via `rsync` from the Manager.
*   **Communication**: SSH for control, WireGuard for internal traffic.

### 2. Service Stack (Minimalist)
*   **Mail**: Postfix + Dovecot. Auth via `/etc/passwd` or simple `passwd-file`. No MySQL/Postgres for users.
*   **Storage**: SFTP for upload, Nginx with `autoindex on` for download/viewing. Simple, fast, works everywhere.
*   **Web**: Caddy. It's not "suckless" in language (Go), but it's "suckless" in operation (one binary, one config, auto-HTTPS).
*   **DB**: PostgreSQL. Necessary evil for many apps, but kept default.

## Proposed Changes

### Phase 1: Fix & Cleanup
*   Ensure directory is `krutrim-nexus-ops`.
*   Simplify `install.sh` to remove unnecessary checks.

### Phase 2: Minimalist Scripts
#### [MODIFY] [setup-mail.sh](file:///C:/Users/yashp/.gemini/antigravity/brain/0f403ae0-901e-45c0-8bbe-995bd4ca1d3e/setup-mail.sh)
*   Refactor to use `debconf-set-selections` for Postfix (non-interactive) and simple Dovecot config.
*   Remove SQL dependencies.

#### [NEW] [setup-storage.sh](file:///C:/Users/yashp/.gemini/antigravity/brain/0f403ae0-901e-45c0-8bbe-995bd4ca1d3e/setup-storage.sh)
*   Creates a `storage` user.
*   Configures Nginx to serve `/home/storage/public`.
*   Restricts SSH to SFTP-only for that user.

#### [NEW] [setup-lb.sh](file:///C:/Users/yashp/.gemini/antigravity/brain/0f403ae0-901e-45c0-8bbe-995bd4ca1d3e/setup-lb.sh)
*   Installs Caddy.
*   Configures a simple load balancer block.

### Phase 3: The Nexus
#### [MODIFY] [nexus.py](file:///C:/Users/yashp/.gemini/antigravity/brain/0f403ae0-901e-45c0-8bbe-995bd4ca1d3e/nexus.py)
*   Remove `fabric` dependency if possible, or keep it minimal.
*   Focus on `rsync` (push configs) and `ssh` (reload services).

## Verification
*   **Mail**: `swaks --to user@example.com --server localhost`
*   **Storage**: `sftp storage@host` then `curl http://host/file`
