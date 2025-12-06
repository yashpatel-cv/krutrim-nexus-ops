# Krutrim Nexus Ops - Quick Start Guide

## 🚀 5-Minute Installation

### Prerequisites
- Server: 64.181.212.50 (Oracle Cloud ARM64/AMD64)
- Domain: krutrimseva.cbu.net (DNS configured)
- OS: Ubuntu 22.04 or Debian 11+
- Access: Root SSH access

---

## Step 1: Clone Repository

```bash
ssh root@64.181.212.50

cd /opt
git clone https://github.com/yashpatel-cv/krutrim-nexus-ops.git
cd krutrim-nexus-ops
```

---

## Step 2: Run Main Installer

```bash
chmod +x install.sh
sudo ./install.sh
```

**Select Option 3** (Manager + Worker):
```
Select deployment mode:
  1) Manager Only
  2) Worker Only
  3) Both            ← SELECT THIS
  4) Load Balancer

Select [1/2/3/4]: 3
```

**Installation will**:
- ✅ Detect ARM64/AMD64 architecture
- ✅ Install Docker, Python, Consul
- ✅ Create manager orchestrator
- ✅ Create worker agent
- ✅ Configure systemd services
- ✅ Generate SSH keys

**Duration**: 5-10 minutes

---

## Step 3: Install Dashboard

```bash
cd /opt/krutrim-nexus-ops/dashboard/backend

# Create Python virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

---

## Step 4: Start Dashboard Service

```bash
# Copy systemd service file
sudo cp ../../config/systemd/nexus-dashboard.service /etc/systemd/system/

# Update service file with correct paths
sudo sed -i 's|/opt/nexus/dashboard|/opt/krutrim-nexus-ops/dashboard|g' /etc/systemd/system/nexus-dashboard.service

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable nexus-dashboard
sudo systemctl start nexus-dashboard
```

---

## Step 5: Open Firewall Ports

```bash
# Dashboard port
sudo ufw allow 9000/tcp

# Consul UI
sudo ufw allow 8500/tcp

# Reload firewall
sudo ufw reload
sudo ufw status
```

---

## Step 6: Verify Installation

### Check Services
```bash
# Consul cluster
consul members

# Manager orchestrator
sudo systemctl status nexus-orchestrator

# Worker agent
sudo systemctl status nexus-worker

# Dashboard
sudo systemctl status nexus-dashboard
```

### Check Logs
```bash
# Dashboard logs
sudo journalctl -u nexus-dashboard -f

# Orchestrator logs
sudo journalctl -u nexus-orchestrator -f

# Worker logs
sudo journalctl -u nexus-worker -f
```

### Test API
```bash
# Health check
curl http://localhost:9000/api/health

# Consul health
curl http://localhost:9000/api/health/consul

# List managers
curl http://localhost:9000/api/managers/

# List workers
curl http://localhost:9000/api/workers/
```

---

## Step 7: Access Dashboard

### Web Browser
```
http://64.181.212.50:9000
```

**You should see**:
- Dark cyberpunk-themed dashboard
- Overview panel with cluster metrics
- Manager and worker grids
- Real-time charts
- Terminal logs

### Click "Connect" Button
- Enables WebSocket real-time updates
- Metrics refresh every 5 seconds
- Connection status shows "Connected" in footer

---

## 🎯 Success Criteria

Your installation is successful when:

1. ✅ `consul members` shows 1 server node (alive)
2. ✅ `systemctl status nexus-dashboard` shows "active (running)"
3. ✅ Dashboard loads at http://64.181.212.50:9000
4. ✅ API returns data: `curl http://localhost:9000/api/health`
5. ✅ WebSocket connects (green "Connected" in footer)
6. ✅ Charts display data
7. ✅ No errors in logs

---

## 🐛 Troubleshooting

### Dashboard Won't Start

**Check logs**:
```bash
sudo journalctl -u nexus-dashboard -n 50
```

**Common fixes**:
```bash
# 1. Python dependencies missing
cd /opt/krutrim-nexus-ops/dashboard/backend
source venv/bin/activate
pip install -r requirements.txt

# 2. Port 9000 in use
sudo lsof -i :9000
sudo kill <PID>

# 3. Consul not running
sudo systemctl start consul
consul members
```

### No Data in Dashboard

**Verify Consul**:
```bash
consul members
consul catalog services
```

**Test API manually**:
```bash
curl http://localhost:9000/api/managers/
curl http://localhost:9000/api/workers/
curl http://localhost:9000/api/analytics/overview
```

### WebSocket Not Connecting

**Check firewall**:
```bash
sudo ufw status | grep 9000
```

**Test WebSocket**:
```bash
# Install wscat if needed
npm install -g wscat

# Test connection
wscat -c ws://localhost:9000/ws/realtime
```

**Check browser console**:
- Open DevTools (F12)
- Go to Console tab
- Look for WebSocket errors

---

## 📚 Next Steps

### 1. Deploy Your First Service

Edit `/opt/nexus/services.yml`:
```yaml
services:
  hello_world:
    - python3
    - -m
    - http.server
    - "8080"
```

Restart worker:
```bash
sudo systemctl restart nexus-worker
```

### 2. Add More Workers

On another server:
```bash
curl -sSL http://64.181.212.50/install.sh | sudo bash -s -- --role worker
```

### 3. Configure Load Balancer

```bash
sudo ./install.sh --role loadbalancer
```

### 4. Explore API

Interactive API docs:
```
http://64.181.212.50:9000/api/docs
```

---

## 🎉 You're Done!

Your high-availability orchestration platform is now running with:
- ✅ Manager + Worker on 64.181.212.50
- ✅ Consul service discovery
- ✅ Web dashboard with real-time updates
- ✅ REST API for automation
- ✅ Beautiful cyberpunk UI

**Access Dashboard**: http://64.181.212.50:9000  
**Access Consul UI**: http://64.181.212.50:8500  
**API Docs**: http://64.181.212.50:9000/api/docs

---

**Total Setup Time**: 5-10 minutes  
**Cost**: $0/month (Oracle Always Free)  
**Uptime**: 99.9% with auto-healing
