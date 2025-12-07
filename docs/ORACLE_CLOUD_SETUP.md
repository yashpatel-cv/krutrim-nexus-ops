# Oracle Cloud ARM64 Setup Guide

## Your Environment

**Instance Details**:
- **Type**: Oracle Cloud VM.Standard.A1.Flex (ARM64)
- **Public IP**: 64.181.212.50
- **Private IP**: 10.0.0.59
- **Domain**: krutrimseva.cbu.net
- **OS**: Oracle Linux
- **Architecture**: ARM64 (aarch64)

---

## Pre-Installation Checklist

### 1. Network Configuration ✅

**VCN Security List** (Already Configured):
```
Ingress Rules:
- Port 22 (SSH): 0.0.0.0/0
- Port 80 (HTTP): 0.0.0.0/0
- Port 443 (HTTPS): 0.0.0.0/0
- Port 8500 (Consul UI): 0.0.0.0/0  # Add this
- Port 9000 (Dashboard): 0.0.0.0/0  # Add this
```

**To add Consul and Dashboard ports**:
1. Go to Oracle Cloud Console
2. Navigate to: Networking → Virtual Cloud Networks → Your VCN
3. Click on your subnet's Security List
4. Add Ingress Rules:
   - Source: `0.0.0.0/0`
   - Destination Port: `8500` (Consul UI)
   - Protocol: TCP
5. Add another rule:
   - Source: `0.0.0.0/0`
   - Destination Port: `9000` (Dashboard)
   - Protocol: TCP

### 2. Firewall Configuration

**Oracle Linux doesn't use ufw**. Check if firewalld is active:

```bash
# Check firewall status
sudo systemctl status firewalld

# If active, add rules
sudo firewall-cmd --permanent --add-port=8500/tcp
sudo firewall-cmd --permanent --add-port=9000/tcp
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --reload

# Or disable firewall (simpler for testing)
sudo systemctl stop firewalld
sudo systemctl disable firewalld
```

### 3. Domain Configuration

Your domain `krutrimseva.cbu.net` should point to `64.181.212.50`.

**Verify DNS**:
```bash
# Check DNS resolution
nslookup krutrimseva.cbu.net
dig krutrimseva.cbu.net

# Should return: 64.181.212.50
```

**If DNS not working yet**: It can take up to 48 hours for DNS propagation. You can use the IP address directly in the meantime.

---

## Installation Steps

### Step 1: Clone Repository

```bash
cd /opt
sudo git clone https://github.com/yashpatel-cv/krutrim-nexus-ops.git
cd krutrim-nexus-ops
```

### Step 2: Run Installation

```bash
sudo ./install.sh
```

### Step 3: Answer Prompts

The installer will ask you to confirm/input:

#### **Server IP Configuration**:
```
Detected Public IP: 64.181.212.50
Detected Private IP: 10.0.0.59

For cloud instances (Oracle, AWS, etc), use your PUBLIC IP for Consul bind_addr.
Enter server IP to use (press Enter for public IP 64.181.212.50):
```
**Press Enter** to use your public IP `64.181.212.50`

#### **Domain Configuration**:
```
Detected domain: local.domain
Enter domain name (press Enter for 'local.domain', or input custom):
```
**Type**: `krutrimseva.cbu.net` and press Enter

#### **Final Confirmation**:
```
=== Final Installation Configuration ===
System:
  Architecture: arm64 (aarch64)
  OS: Oracle Linux

Network:
  Server IP (bind_addr): 64.181.212.50
  Domain: krutrimseva.cbu.net
  Public IP (for reference): 64.181.212.50
  Private IP (for reference): 10.0.0.59

Installation:
  Consul Version: 1.17.0
  Installation Path: /opt/nexus

These values will be used for Consul bind_addr, dashboard endpoints, etc.
Proceed with installation? [Y/n]:
```
**Type**: `Y` and press Enter

#### **Role Selection**:
```
Select installation type:
  1) Manager only
  2) Worker only
  3) Both (Manager + Worker)
Choose [1-3]:
```
**Type**: `3` and press Enter

#### **Dashboard Installation**:
```
Install dashboard? (Y/n):
```
**Type**: `Y` and press Enter

### Step 4: Wait for Installation

The script will:
1. ✅ Validate environment (root, OS, disk, memory, network)
2. ✅ Install system packages (architecture-aware)
3. ✅ Download Consul ARM64 binary
4. ✅ Configure Consul with your public IP
5. ✅ Set up orchestrator and worker services
6. ✅ Install dashboard (FastAPI + frontend)
7. ✅ Start all services

---

## Post-Installation Verification

### 1. Check All Services

```bash
# Check Consul
sudo systemctl status consul
consul members

# Check Orchestrator
sudo systemctl status nexus-orchestrator

# Check Worker
sudo systemctl status nexus-worker

# Check Dashboard
sudo systemctl status nexus-dashboard
```

All should show **active (running)** in green.

### 2. Access Web Interfaces

**Consul UI**:
- URL: http://64.181.212.50:8500
- Or: http://krutrimseva.cbu.net:8500

**Dashboard**:
- URL: http://64.181.212.50:9000
- Or: http://krutrimseva.cbu.net:9000

**Expected Output**: You should see the Consul UI and Krutrim Nexus Dashboard

### 3. Test from External Machine

From your local machine:
```bash
curl http://64.181.212.50:8500/v1/status/leader
# Should return: "64.181.212.50:8300"

curl http://64.181.212.50:9000/api/health
# Should return: {"status": "ok", ...}
```

---

## Troubleshooting

### Issue: Can't access Consul UI from browser

**Check**:
1. Service running: `sudo systemctl status consul`
2. Port open in Oracle Cloud Security List
3. No firewall blocking: `sudo systemctl status firewalld`
4. Consul bound to public IP: `sudo journalctl -u consul -n 50`

**Fix**:
```bash
# Check Consul config
cat /etc/consul.d/consul.json | grep bind_addr
# Should show: "bind_addr": "64.181.212.50"

# If wrong, run fix script
sudo /opt/krutrim-nexus-ops/fix-services.sh
# Enter your public IP when prompted: 64.181.212.50
```

### Issue: Can't access Dashboard

**Check**:
```bash
# Dashboard logs
sudo journalctl -u nexus-dashboard -n 50

# Test locally
curl http://localhost:9000/api/health
```

**Fix**:
```bash
# Restart dashboard
sudo systemctl restart nexus-dashboard

# Check if port 9000 is in use
sudo netstat -tulpn | grep 9000
```

### Issue: Services fail to start

**Check logs**:
```bash
# All service logs
sudo journalctl -u consul -u nexus-orchestrator -u nexus-worker -u nexus-dashboard -n 100
```

**Common fixes**:
```bash
# Re-run installation
cd /opt/krutrim-nexus-ops
git pull origin main
sudo ./install.sh

# Or use fix script
sudo ./fix-services.sh
```

---

## Expected Access Points

After successful installation:

| Service | URL | Description |
|---------|-----|-------------|
| **Consul UI** | http://64.181.212.50:8500 | Service discovery dashboard |
| **Dashboard** | http://64.181.212.50:9000 | Krutrim Nexus management UI |
| **API Docs** | http://64.181.212.50:9000/api/docs | API documentation (if debug enabled) |
| **API Health** | http://64.181.212.50:9000/api/health | Health check endpoint |

**Using Domain**:
- http://krutrimseva.cbu.net:8500 (Consul)
- http://krutrimseva.cbu.net:9000 (Dashboard)

---

## Configuration Files

After installation, configurations are stored in:

```
/opt/nexus/
├── consul/
│   └── consul.json          # Consul config (bind_addr: 64.181.212.50)
├── dashboard/
│   └── backend/
│       └── .env             # Dashboard config (optional)
└── systemd/
    ├── consul.service
    ├── nexus-orchestrator.service
    ├── nexus-worker.service
    └── nexus-dashboard.service
```

**To customize dashboard**:
```bash
cd /opt/nexus/dashboard/backend
cp .env.example .env
nano .env
```

Edit:
```bash
NEXUS_PUBLIC_URL=http://64.181.212.50:9000
NEXUS_CONSUL_HOST=localhost
NEXUS_CONSUL_BIND_ADDR=64.181.212.50
```

Restart:
```bash
sudo systemctl restart nexus-dashboard
```

---

## Next Steps

1. ✅ Verify all services running
2. ✅ Access Consul UI at http://64.181.212.50:8500
3. ✅ Access Dashboard at http://64.181.212.50:9000
4. Configure workers (if adding separate worker nodes)
5. Set up SSL/TLS with Let's Encrypt (optional)
6. Configure monitoring and alerts

---

## Support

If you encounter issues:

1. Check service logs: `sudo journalctl -u service-name -n 100`
2. Run fix script: `sudo /opt/krutrim-nexus-ops/fix-services.sh`
3. Review documentation: `/opt/krutrim-nexus-ops/docs/`
4. Check troubleshooting guide: `docs/TROUBLESHOOTING.md`

---

**Your Installation Command**:
```bash
cd /opt/krutrim-nexus-ops
sudo ./install.sh
# Public IP: 64.181.212.50 (press Enter)
# Domain: krutrimseva.cbu.net (type this)
# Role: 3 (Both)
# Dashboard: Y
```

**Expected Result**:
```
✓ ALL SERVICES RUNNING SUCCESSFULLY

Access Points:
  - Consul UI: http://64.181.212.50:8500
  - Dashboard: http://64.181.212.50:9000
```
