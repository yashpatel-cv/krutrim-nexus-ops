# Dashboard User Guide

## Accessing the Dashboard

After installation, access the dashboard at:
```
http://64.181.212.50:9000
```

Or via domain:
```
https://krutrimseva.cbu.net/dashboard
```

## Dashboard Sections

### 1. Header
- **Logo**: [KRUTRIM]NEXUS-OPS branding
- **Progress Counter**: Shows active workers (e.g., "5/18 Workers")
- **Refresh Button**: Manual data refresh
- **Connect Button**: Toggle real-time WebSocket connection

### 2. Filter Bar
**filter_by_status:**
- ALL: Show all nodes
- HEALTHY: Only healthy nodes
- DEGRADED: Nodes with issues
- FAILED: Failed nodes

**filter_by_type:**
- ALL: All node types
- MANAGER: Manager nodes only
- WORKER: Worker nodes only
- LOADBALANCER: Load balancer nodes

### 3. Overview Panel
Four key metrics cards:
- **Managers**: Count and health status
- **Workers**: Active worker count
- **Services**: Running services count
- **Cluster Health**: Overall system status

### 4. Manager Grid
Cards showing each manager with:
- Hostname and role (PRIMARY/SECONDARY)
- Status badge (color-coded)
- CPU, Memory, Disk usage with progress bars
- Worker count and uptime
- Action buttons (Details, Restart)

### 5. Worker Grid
Cards showing each worker with:
- Hostname and pool assignment
- Status badge
- Resource usage metrics
- Service count
- Action buttons (Details, Restart)

### 6. Analytics Charts
Three time-series charts (24h view):
- **CPU Utilization**: Cluster-wide CPU usage
- **Memory Usage**: Memory consumption trend
- **Network Throughput**: Network I/O

### 7. Logs Terminal
Real-time system logs with:
- Color-coded log levels (INFO/WARN/ERROR)
- Timestamps
- Auto-scroll
- Clear button

## Real-Time Updates

Click **Connect** button to enable WebSocket updates:
- Metrics update every 5 seconds
- No page refresh needed
- Connection status shown in footer

## Keyboard Shortcuts

- `R`: Refresh dashboard
- `C`: Toggle real-time connection
- `L`: Clear logs

## Color Coding

- **Green (#00ff41)**: Healthy, active, normal
- **Yellow (#ffff00)**: Warning, degraded
- **Red (#ff0055)**: Error, failed, critical
- **Cyan (#00ffff)**: Manager nodes, special status

## Troubleshooting

**Dashboard not loading:**
1. Check if service is running: `systemctl status nexus-dashboard`
2. Check port 9000 is open: `ufw status`
3. View logs: `journalctl -u nexus-dashboard -f`

**No data showing:**
1. Verify Consul is running: `consul members`
2. Check API health: `curl http://localhost:9000/api/health`
3. Ensure workers are registered with Consul

**WebSocket not connecting:**
1. Check firewall allows WebSocket connections
2. Verify no proxy blocking WebSocket upgrade
3. Try HTTP instead of HTTPS if SSL issues
