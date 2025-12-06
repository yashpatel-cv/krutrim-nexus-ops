"""
Metrics and analytics data models
"""

from pydantic import BaseModel, Field
from typing import List, Dict, Optional
from datetime import datetime


class SystemMetrics(BaseModel):
    """System-wide metrics"""
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    
    # Cluster overview
    total_managers: int = Field(default=0)
    healthy_managers: int = Field(default=0)
    total_workers: int = Field(default=0)
    healthy_workers: int = Field(default=0)
    total_services: int = Field(default=0)
    running_services: int = Field(default=0)
    
    # Aggregate resource usage
    avg_cpu_usage: float = Field(default=0.0, ge=0.0, le=100.0)
    avg_memory_usage: float = Field(default=0.0, ge=0.0, le=100.0)
    avg_disk_usage: float = Field(default=0.0, ge=0.0, le=100.0)
    
    # Network totals
    total_network_in: float = Field(default=0.0, description="Total network input MB/s")
    total_network_out: float = Field(default=0.0, description="Total network output MB/s")
    
    # Health status
    cluster_health: str = Field(default="unknown", description="Overall cluster health")
    alerts_count: int = Field(default=0, description="Active alerts count")


class ServiceMetrics(BaseModel):
    """Individual service metrics"""
    service_name: str
    worker_id: str
    status: str
    
    # Performance
    request_count: int = Field(default=0)
    error_count: int = Field(default=0)
    avg_response_time_ms: float = Field(default=0.0)
    
    # Resource usage
    cpu_usage: float = Field(default=0.0)
    memory_mb: float = Field(default=0.0)
    
    # Operational
    uptime_seconds: int = Field(default=0)
    restart_count: int = Field(default=0)
    last_restart: Optional[datetime] = None
    
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class TimeSeriesDataPoint(BaseModel):
    """Single data point in time series"""
    timestamp: datetime
    value: float


class Metrics(BaseModel):
    """Complete metrics response"""
    system: SystemMetrics
    services: List[ServiceMetrics] = Field(default_factory=list)
    
    # Time series data (last 24h)
    cpu_history: List[TimeSeriesDataPoint] = Field(default_factory=list)
    memory_history: List[TimeSeriesDataPoint] = Field(default_factory=list)
    network_history: List[TimeSeriesDataPoint] = Field(default_factory=list)
    
    generated_at: datetime = Field(default_factory=datetime.utcnow)
