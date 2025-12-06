"""
Manager node data models
"""

from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum


class ManagerStatus(str, Enum):
    HEALTHY = "healthy"
    DEGRADED = "degraded"
    FAILED = "failed"
    UNKNOWN = "unknown"


class Manager(BaseModel):
    """Manager node model"""
    id: str = Field(..., description="Manager unique identifier")
    hostname: str = Field(..., description="Manager hostname")
    ip_address: str = Field(..., description="Manager IP address")
    role: str = Field(default="primary", description="Manager role (primary/secondary)")
    status: ManagerStatus = Field(default=ManagerStatus.UNKNOWN)
    
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
    consul_leader: bool = Field(default=False, description="Is Consul leader")
    
    # Worker management
    managed_workers: int = Field(default=0, description="Number of managed workers")
    healthy_workers: int = Field(default=0, description="Number of healthy workers")
    
    # Service counts
    total_services: int = Field(default=0, description="Total services managed")
    running_services: int = Field(default=0, description="Running services count")
    
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        json_schema_extra = {
            "example": {
                "id": "mgr-001",
                "hostname": "krutrim-db-0",
                "ip_address": "64.181.212.50",
                "role": "primary",
                "status": "healthy",
                "cpu_usage": 23.5,
                "memory_usage": 45.2,
                "disk_usage": 62.8,
                "uptime_seconds": 86400,
                "consul_leader": True,
                "managed_workers": 5,
                "healthy_workers": 5
            }
        }
