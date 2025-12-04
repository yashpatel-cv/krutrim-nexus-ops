# Krutrim Nexus Ops

**Minimalist, Push-Based Server Orchestration.**

Krutrim Nexus Ops is a "suckless" style platform for managing a cluster of servers. It uses a **Manager-Worker** architecture where the Manager pushes configuration via SSH.

## Features
*   **Decentralized**: Services run independently on workers.
*   **Monitoring**: Unified Web Dashboard via Netdata.
*   **Interactive**: Simple setup script.
*   **Secure**: Hardened by default.

## Quick Start

### 1. Setup Manager
Run the interactive installer on your control node:
```bash
sudo ./install.sh
```
*Select "1) Manager" when prompted.*

### 2. Connect Workers
Edit `/opt/nexus/inventory.yml`:
```yaml
workers:
  - 192.168.1.10
  - 192.168.1.11
```

### 3. Bootstrap Cluster
```bash
nexus bootstrap
```

### 4. Enable Monitoring (Dashboard)
```bash
nexus monitor
```
*   Installs Netdata on Manager and all Workers.
*   Streams metrics to the Manager.
*   **Access Dashboard**: `http://<manager-ip>:19999`

### 5. Deploy Services (High Availability)
To achieve decentralization and HA, deploy the same service to multiple workers and put them behind a Load Balancer.

**Step A: Deploy App to Multiple Nodes**
```bash
nexus deploy web 192.168.1.10
nexus deploy web 192.168.1.11
```

**Step B: Configure Load Balancer**
Deploy the LB to a stable node (or multiple nodes with DNS Round Robin):
```bash
nexus deploy lb 192.168.1.10
```
*Edit `/etc/caddy/Caddyfile` on the LB to include both worker IPs.*

## Deep Dive Q&A

**Q: How do I see analytics?**
A: Run `nexus monitor`. This sets up a real-time dashboard at `http://<manager-ip>:19999` where you can see CPU, RAM, and Network stats for the entire cluster.

**Q: Is it decentralized?**
A: **Yes.**
*   **Manager Failure**: If the Manager goes offline, all Workers and Services **continue running**. You just can't push new updates until it's back.
*   **Worker Failure**: If a Worker goes offline, only the services on that specific worker stop. Use the HA strategy (Load Balancer + Multiple Workers) to prevent downtime.

**Q: Does the script ask questions?**
A: **Yes.** `install.sh` is now interactive. It asks you if you want to setup a Manager or Worker, guiding you through the process.

**Q: How do I create users?**
```bash
nexus create-user mail 192.168.1.10 john
nexus create-user storage 192.168.1.11 alice
```
