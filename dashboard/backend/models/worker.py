"""
Worker node data models
"""

from pydantic import BaseModel, Field
from typing import Optional, List, Dict
from datetime import datetime
from enum import Enum


class WorkerStatus(str, Enum):
    HEALTHY = "healthy"
    DEGRADED = "degraded"
    FAILED = "failed"
    DRAINING = "draining"
    UNKNOWN = "unknown"


class WorkerPool(str, Enum):
    WEB = "web"
    API = "api"
    DATABASE = "database"
    WORKER = "worker"
    CUSTOM = "custom"


class ServiceInfo(BaseModel):
    """Individual service running on worker"""
    name: str
    status: str
    port: int
    restarts: int = 0
    uptime_seconds: int = 0


class Worker(BaseModel):
    """Worker node model"""
    id: str = Field(..., description="Worker unique identifier")
    hostname: str = Field(..., description="Worker hostname")
    ip_address: str = Field(..., description="Worker IP address")
    pool: WorkerPool = Field(default=WorkerPool.WORKER, description="Worker pool assignment")
    status: WorkerStatus = Field(default=WorkerStatus.UNKNOWN)
    
    # Resource metrics
    cpu_usage: float = Field(default=0.0, ge=0.0, le=100.0, description="CPU usage percentage")
    memory_usage: float = Field(default=0.0, ge=0.0, le=100.0, description="Memory usage percentage")
    disk_usage: float = Field(default=0.0, ge=0.0, le=100.0, description="Disk usage percentage")
    
    # Network metrics
    network_in: float = Field(default=0.0, description="Network input MB/s")
    network_out: float = Field(default=0.0, description="Network output MB/s")
    
    # Operational data
    uptime_seconds: int = Field(default=0, description="Uptime in seconds")
    last_heartbeat: Optional[datetime] = Field(default=None, description="Last heartbeat timestamp")
    
    # Services
    services: List[ServiceInfo] = Field(default_factory=list, description="Running services")
    total_services: int = Field(default=0, description="Total services count")
    healthy_services: int = Field(default=0, description="Healthy services count")
    
    # Health check
    health_check_url: Optional[str] = Field(default=None, description="Health check endpoint")
    last_check_status: Optional[int] = Field(default=None, description="Last HTTP status code")
    
    # Manager assignment
    manager_id: Optional[str] = Field(default=None, description="Assigned manager ID")
    
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        json_schema_extra = {
            "example": {
                "id": "wkr-001",
                "hostname": "worker-web-1",
                "ip_address": "10.0.0.2",
                "pool": "web",
                "status": "healthy",
                "cpu_usage": 15.3,
                "memory_usage": 32.1,
                "disk_usage": 45.7,
                "uptime_seconds": 43200,
                "total_services": 3,
                "healthy_services": 3
            }
        }
