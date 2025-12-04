# Krutrim Nexus Ops

**Minimalist, Push-Based Server Orchestration.**

Krutrim Nexus Ops is a "suckless" style platform for managing a cluster of servers. It uses a **Manager-Worker** architecture where the Manager pushes configuration via SSH, eliminating the need for manual setup on workers.

## Architecture & Mechanics

### How Manager Works
The **Manager** is a control plane node. It holds the "Source of Truth" (scripts, configs, inventory). It uses the `nexus` CLI (a Python wrapper around `ssh` and `scp`) to:
1.  **Bootstrap**: Connect to a fresh worker, install dependencies, and apply hardening.
2.  **Deploy**: Push specific service setup scripts (`setup-mail.sh`, etc.) and execute them.
3.  **Manage**: Create users, sync configs, and check status.

### How Workers Work
Workers are "dumb" execution units. They run standard Linux (Debian/Arch).
*   **Agent**: A lightweight systemd service (`nexus-agent`) that runs `services.py` to supervise application processes.
*   **Connectivity**: They connect to the internet to download packages (`apt`/`pacman`). They accept incoming SSH connections **only** from the Manager (enforced via SSH keys).
*   **Services**: Services like Postfix, Caddy, and Postgres run as standard systemd units.

## Quick Start Guide

### 1. Setup Manager
Run this **once** on your control machine:
```bash
sudo ./install.sh
```
*   Installs `nexus` CLI to `/usr/local/bin`.
*   Generates SSH keys in `~/.ssh/id_rsa`.

### 2. Define Cluster
Edit `/opt/nexus/inventory.yml`:
```yaml
workers:
  - 192.168.1.10  # Worker 1
  - 192.168.1.11  # Worker 2
```

### 3. Bootstrap Workers
```bash
nexus bootstrap
```
*   Connects to each IP.
*   Installs firewall (nftables), hardening (sysctl), and dependencies.
*   **Note**: You must have root SSH access to workers initially (e.g., `ssh-copy-id root@<ip>`).

### 4. Deploy Services
**Mail Server**:
```bash
nexus deploy mail 192.168.1.10 example.com
```
*   Installs Postfix/Dovecot.
*   Configures TLS and DKIM.

**Storage Server**:
```bash
nexus deploy storage 192.168.1.11
```
*   Sets up SFTP and Nginx.

### 5. Create Users
**Mail User**:
```bash
nexus create-user mail 192.168.1.10 john
```
*   Creates a system user `john`.
*   Prompts you to set a password.
*   John can now login via IMAP/SMTP.

**Storage User**:
```bash
nexus create-user storage 192.168.1.11 alice
```
*   Creates SFTP user `alice`.
*   Alice can upload files to `/home/alice/public`.

## Deep Dive Q&A

**Q: How are services connected to the internet?**
A: Services bind to standard ports on the Worker's public IP:
*   **Web**: Ports 80 (HTTP) and 443 (HTTPS).
*   **Mail**: Ports 25 (SMTP), 587 (Submission), 993 (IMAP).
*   **Storage**: Port 22 (SFTP) and 80/443 (HTTP View).
*   **Firewall**: `nftables` is configured to allow these ports only if the service is deployed.

**Q: How do I access them?**
*   **Web**: Visit `https://<worker-ip>` or domain.
*   **Mail**: Use a client like Thunderbird.
    *   **IMAP**: `<worker-ip>`, Port 993, SSL/TLS.
    *   **SMTP**: `<worker-ip>`, Port 587, STARTTLS.
    *   **Username**: `john` (created via `nexus create-user`).
*   **Storage**:
    *   **Upload**: `sftp alice@<worker-ip>`
    *   **View**: `http://<worker-ip>/~alice/` (if configured) or root URL.

**Q: Will they be installed/enabled/started automatically?**
A: **Yes.** The `setup-*.sh` scripts run `apt-get install`, configure the service, and run `systemctl enable --now <service>`.

**Q: Does the script ask questions?**
A: **No.** The scripts are non-interactive.
*   `apt-get` runs with `DEBIAN_FRONTEND=noninteractive`.
*   Postfix is configured via `debconf-set-selections`.
*   The only interaction is setting a password when you run `nexus create-user`.

**Q: Is `nexus` a package?**
A: No, it's a custom Python script installed to `/usr/local/bin/nexus` by `install.sh`. It acts like a CLI tool.

**Q: How do I see emails?**
A: Since this is a minimalist setup, we don't install a heavy Webmail (like Roundcube) by default. You view emails by connecting a standard Mail Client (Thunderbird, Apple Mail, Outlook) to the server using the credentials you created.

**Q: Can I still SSH in after hardening?**
A: **Yes.** The `nftables.conf` explicitly allows Port 22. However, root login might be restricted depending on your base OS config. We recommend using SSH keys.

**Q: Do you use static data?**
A: No hardcoded passwords.
*   **Passwords**: You set them interactively via `nexus create-user`.
*   **Keys**: SSH keys are generated on the fly. DKIM keys are generated during mail setup.

**Q: Are necessary packages installed?**
A: **Yes.** `bootstrap_worker.sh` installs all prerequisites (Python, rsync, WireGuard, etc.) before anything else runs.
