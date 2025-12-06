# Troubleshooting Guide

## Common Issues & Solutions

### 1. Dashboard Issues

#### Dashboard Won't Start

**Symptom**: `systemctl status nexus-dashboard` shows failed

**Solutions**:
```bash
# Check logs
sudo journalctl -u nexus-dashboard -n 100

# Common Issue 1: Python dependencies missing
cd /opt/krutrim-nexus-ops/dashboard/backend
source venv/bin/activate
pip install -r requirements.txt
sudo systemctl restart nexus-dashboard

# Common Issue 2: Port 9000 in use
sudo lsof -i :9000
sudo kill <PID>
sudo systemctl restart nexus-dashboard

# Common Issue 3: Wrong working directory
sudo systemctl cat nexus-dashboard
# Verify WorkingDirectory=/opt/krutrim-nexus-ops/dashboard/backend
```

#### Dashboard Shows No Data

**Symptom**: Dashboard loads but shows 0 managers/workers

**Solutions**:
```bash
# 1. Verify Consul is running
consul members
# Should show at least 1 server node

# 2. Test API manually
curl http://localhost:9000/api/health
curl http://localhost:9000/api/health/consul
curl http://localhost:9000/api/managers/

# 3. Check Consul connectivity
consul catalog nodes
consul catalog services

# 4. Restart dashboard
sudo systemctl restart nexus-dashboard
```

#### WebSocket Won't Connect

**Symptom**: "Connect" button doesn't work, footer shows "Disconnected"

**Solutions**:
```bash
# 1. Check firewall
sudo ufw status | grep 9000

# 2. Test WebSocket manually
npm install -g wscat
wscat -c ws://localhost:9000/ws/realtime

# 3. Check browser console (F12)
# Look for WebSocket errors

# 4. Try without SSL
# Use http:// instead of https://

# 5. Check if proxy blocking WebSocket
# Disable any proxies
```

---

### 2. Consul Issues

#### Consul Won't Start

**Symptom**: `systemctl status consul` shows failed

**Solutions**:
```bash
# Check logs
sudo journalctl -u consul -n 100

# Common Issue 1: Permissions
sudo chown -R root:root /var/consul
sudo chmod 755 /var/consul
sudo systemctl restart consul

# Common Issue 2: Config error
sudo consul validate /etc/consul.d/server.json
# OR
sudo consul validate /etc/consul.d/client.json

# Common Issue 3: Port conflict
sudo lsof -i :8500
sudo lsof -i :8301
```

#### No Consul Leader

**Symptom**: `consul members` shows no leader

**Solutions**:
```bash
# Check cluster status
consul operator raft list-peers

# Force leader election (if single node)
consul operator raft list-peers
# If only 1 peer, it should be leader

# Restart Consul
sudo systemctl restart consul
sleep 5
consul members
```

#### Worker Not Registering with Consul

**Symptom**: Worker node doesn't appear in `consul members`

**Solutions**:
```bash
# On worker node:

# 1. Check Consul client config
cat /etc/consul.d/client.json
# Verify "retry_join" has correct manager IP

# 2. Test connectivity to manager
ping 64.181.212.50
telnet 64.181.212.50 8301

# 3. Check firewall
sudo ufw status | grep 8301

# 4. Restart Consul
sudo systemctl restart consul

# 5. Check logs
sudo journalctl -u consul -f
```

---

### 3. Orchestrator Issues

#### Orchestrator Crashes

**Symptom**: `systemctl status nexus-orchestrator` shows failed

**Solutions**:
```bash
# Check logs
sudo journalctl -u nexus-orchestrator -n 100

# Common Issue: Python dependencies
pip3 list | grep consul
pip3 install python-consul --break-system-packages

# Restart
sudo systemctl restart nexus-orchestrator
```

#### Services Not Auto-Restarting

**Symptom**: Worker services die and don't restart

**Solutions**:
```bash
# 1. Check orchestrator is running
sudo systemctl status nexus-orchestrator

# 2. Check services.yml exists
cat /opt/nexus/services.yml

# 3. Verify services.yml syntax
python3 -c "import yaml; yaml.safe_load(open('/opt/nexus/services.yml'))"

# 4. Check orchestrator logs
sudo journalctl -u nexus-orchestrator -f
# Should see restart attempts

# 5. Manually restart orchestrator
sudo systemctl restart nexus-orchestrator
```

---

### 4. Worker Issues

#### Worker Agent Won't Start

**Symptom**: `systemctl status nexus-worker` shows failed

**Solutions**:
```bash
# Check logs
sudo journalctl -u nexus-worker -n 100

# Common Issue 1: Missing files
ls -la /opt/nexus/
# Should have: run-services.sh, services.py, proc_ipc.py

# Common Issue 2: Python venv missing
ls -la /opt/nexus/venv/
# If missing, run:
cd /opt/nexus
python3 -m venv venv
venv/bin/pip install pyyaml

# Common Issue 3: Permissions
sudo chmod +x /opt/nexus/run-services.sh
sudo systemctl restart nexus-worker
```

#### Worker Services Not Running

**Symptom**: Services defined in services.yml don't start

**Solutions**:
```bash
# 1. Check services.yml
cat /opt/nexus/services.yml

# 2. Test manually
cd /opt/nexus
source venv/bin/activate
python3 services.py
# Watch for errors

# 3. Check if ports are available
sudo lsof -i :8080  # or whatever port your service uses

# 4. Check worker logs
sudo journalctl -u nexus-worker -f
```

---

### 5. Network Issues

#### Can't Access Dashboard from Browser

**Symptom**: http://64.181.212.50:9000 times out

**Solutions**:
```bash
# 1. Check if dashboard is listening
sudo lsof -i :9000
# Should show uvicorn process

# 2. Check firewall
sudo ufw status | grep 9000
# Should show: 9000/tcp ALLOW Anywhere

# 3. Open port if needed
sudo ufw allow 9000/tcp
sudo ufw reload

# 4. Test locally first
curl http://localhost:9000/api/health
# Should return {"status": "healthy"}

# 5. Check Oracle Cloud security groups
# In Oracle Cloud Console:
# - Go to your instance
# - Check Security Lists
# - Ensure port 9000 is open (Ingress Rule)
```

#### Consul UI Not Accessible

**Symptom**: http://64.181.212.50:8500 doesn't load

**Solutions**:
```bash
# 1. Check Consul is running
sudo systemctl status consul

# 2. Check if UI is enabled
cat /etc/consul.d/server.json | grep ui_config
# Should have: "ui_config": {"enabled": true}

# 3. Open firewall
sudo ufw allow 8500/tcp
sudo ufw reload

# 4. Test locally
curl http://localhost:8500/ui/
```

---

### 6. Installation Issues

#### install.sh Fails

**Symptom**: Installation script exits with error

**Solutions**:
```bash
# Run with debug mode
bash -x ./install.sh

# Common Issue 1: Not running as root
sudo ./install.sh

# Common Issue 2: Missing dependencies
# On Debian/Ubuntu:
sudo apt update
sudo apt install -y curl wget python3 python3-pip

# On Arch:
sudo pacman -Sy curl wget python python-pip

# Common Issue 3: Network issues downloading Consul
# Check internet connectivity
ping -c 3 releases.hashicorp.com

# Manual Consul install if needed
wget https://releases.hashicorp.com/consul/1.17.0/consul_1.17.0_linux_arm64.zip
unzip consul_1.17.0_linux_arm64.zip
sudo mv consul /usr/local/bin/
```

#### Cluster Metadata Error

**Symptom**: "Cluster already has a manager on host: X"

**Solutions**:
```bash
# This is intentional - prevents multiple managers

# Option 1: If this IS the manager, remove old metadata
sudo rm /opt/nexus/cluster.yml
sudo ./install.sh

# Option 2: If setting up a worker instead
sudo ./install.sh --role worker

# Option 3: If migrating manager to new host
# On old manager:
sudo systemctl stop nexus-orchestrator
sudo rm /opt/nexus/cluster.yml

# On new manager:
sudo ./install.sh --role manager
```

---

### 7. Performance Issues

#### High CPU Usage

**Symptom**: Dashboard shows >80% CPU constantly

**Solutions**:
```bash
# 1. Check what's using CPU
top -o %CPU

# 2. Check Docker containers
docker stats

# 3. Limit container resources
docker update --cpus="1.0" <container-id>

# 4. Check for runaway processes
ps aux --sort=-%cpu | head -10
```

#### High Memory Usage

**Symptom**: Dashboard shows >90% memory

**Solutions**:
```bash
# 1. Check memory usage
free -h

# 2. Check Docker containers
docker stats

# 3. Restart services to free memory
sudo systemctl restart nexus-worker
sudo systemctl restart nexus-orchestrator

# 4. Add swap if needed
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

---

### 8. API Issues

#### API Returns 500 Errors

**Symptom**: API calls fail with Internal Server Error

**Solutions**:
```bash
# 1. Check dashboard logs
sudo journalctl -u nexus-dashboard -n 100

# 2. Test Consul connectivity
curl http://localhost:8500/v1/catalog/nodes

# 3. Restart dashboard
sudo systemctl restart nexus-dashboard

# 4. Check Python errors
cd /opt/krutrim-nexus-ops/dashboard/backend
source venv/bin/activate
python3 -c "from app import app; print('OK')"
```

#### API Returns Empty Arrays

**Symptom**: `/api/managers/` returns `[]`

**Solutions**:
```bash
# 1. Verify Consul has data
consul catalog nodes
consul catalog services

# 2. Check Consul connectivity in dashboard
curl http://localhost:9000/api/health/consul

# 3. Verify ConsulService is working
cd /opt/krutrim-nexus-ops/dashboard/backend
source venv/bin/activate
python3 -c "from services.consul_service import ConsulService; c = ConsulService(); print(c.get_all_nodes())"
```

---

### 9. Docker Issues

#### Docker Containers Won't Start

**Symptom**: `docker ps` shows no containers

**Solutions**:
```bash
# 1. Check Docker is running
sudo systemctl status docker

# 2. Check Docker logs
sudo journalctl -u docker -n 50

# 3. Test Docker
docker run hello-world

# 4. Check disk space
df -h
# Docker needs space in /var/lib/docker
```

---

### 10. SSL/HTTPS Issues

#### Caddy SSL Fails

**Symptom**: HTTPS doesn't work, certificate errors

**Solutions**:
```bash
# 1. Check Caddy logs
sudo journalctl -u caddy -n 50

# 2. Verify DNS points to server
dig krutrimseva.cbu.net
# Should return 64.181.212.50

# 3. Check ports 80/443 are open
sudo ufw status | grep -E "80|443"

# 4. Test Let's Encrypt manually
curl -I http://krutrimseva.cbu.net/.well-known/acme-challenge/test

# 5. Force certificate renewal
sudo caddy reload --config /etc/caddy/Caddyfile
```

---

## 🆘 Emergency Commands

### Complete System Reset
```bash
# Stop all services
sudo systemctl stop nexus-dashboard
sudo systemctl stop nexus-orchestrator
sudo systemctl stop nexus-worker
sudo systemctl stop consul

# Clear data
sudo rm -rf /var/consul/*
sudo rm -rf /opt/nexus/*

# Reinstall
cd /opt/krutrim-nexus-ops
sudo ./install.sh
```

### View All Logs
```bash
# All Nexus services
sudo journalctl -u 'nexus-*' -f

# Last hour of all logs
sudo journalctl --since "1 hour ago" -u nexus-dashboard -u nexus-orchestrator -u nexus-worker -u consul
```

### Check All Ports
```bash
sudo lsof -i -P -n | grep LISTEN
```

---

## 📞 Getting Help

1. **Check Logs First**: `sudo journalctl -u <service> -n 100`
2. **Test API**: `curl http://localhost:9000/api/health`
3. **Verify Consul**: `consul members`
4. **Check Firewall**: `sudo ufw status`
5. **Review Docs**: See [docs/](docs/) folder

**Repository**: https://github.com/yashpatel-cv/krutrim-nexus-ops  
**Issues**: https://github.com/yashpatel-cv/krutrim-nexus-ops/issues

---

**Most issues are solved by checking logs and restarting services!**
