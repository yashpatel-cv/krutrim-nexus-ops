# Krutrim Nexus Ops - API Reference

## Base URL
```
http://<manager-ip>:9000
```

## Authentication
Currently no authentication required. JWT auth can be enabled in production.

## Endpoints

### Managers

#### GET /api/managers/
List all manager nodes.

**Response:**
```json
[
  {
    "id": "mgr-001",
    "hostname": "krutrim-db-0",
    "ip_address": "64.181.212.50",
    "role": "primary",
    "status": "healthy",
    "cpu_usage": 23.5,
    "memory_usage": 45.2,
    "disk_usage": 62.8,
    "uptime_seconds": 86400,
    "consul_leader": true,
    "managed_workers": 5,
    "healthy_workers": 5
  }
]
```

#### GET /api/managers/{id}
Get specific manager details.

#### POST /api/managers/{id}/restart
Restart manager orchestrator service.

### Workers

#### GET /api/workers/
List all worker nodes.

**Query Parameters:**
- `pool`: Filter by worker pool (web, api, database, worker, custom)
- `status`: Filter by status (healthy, degraded, failed, draining)

#### GET /api/workers/{id}
Get specific worker details.

#### POST /api/workers/{id}/restart
Restart worker agent service.

#### POST /api/workers/{id}/drain
Drain worker (stop accepting new work).

### Analytics

#### GET /api/analytics/overview
Get system overview metrics.

#### GET /api/analytics/performance
Get performance metrics with time series data.

**Query Parameters:**
- `duration_hours`: Duration in hours (1-168, default: 24)

#### GET /api/analytics/timeseries/{metric_type}
Get time series data for specific metric.

**Metric Types:** cpu, memory, network

### Health

#### GET /api/health/
Basic health check.

#### GET /api/health/consul
Check Consul connectivity.

#### GET /api/health/cluster
Check overall cluster health.

### WebSocket

#### WS /ws/realtime
Real-time metrics streaming.

**Message Format:**
```json
{
  "type": "metrics_update",
  "timestamp": "2025-12-06T08:00:00Z",
  "data": {
    "cpu_usage": 23.5,
    "memory_usage": 45.2,
    "disk_usage": 62.8,
    "network_in": 10.5,
    "network_out": 8.3,
    "total_nodes": 6,
    "total_services": 15
  }
}
```

## Interactive API Documentation

Visit `/api/docs` for Swagger UI interactive documentation.
Visit `/api/redoc` for ReDoc documentation.
