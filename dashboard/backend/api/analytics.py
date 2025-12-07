"""
Analytics and metrics API endpoints
"""

from fastapi import APIRouter, HTTPException, Depends, Query
from typing import List
import logging

from models import Metrics, SystemMetrics, TimeSeriesDataPoint
from services import ConsulService, MetricsService

router = APIRouter(prefix="/api/analytics", tags=["analytics"])
logger = logging.getLogger(__name__)


def get_consul_service():
    return ConsulService()

def get_metrics_service():
    return MetricsService()


@router.get("/overview", response_model=SystemMetrics)
async def get_overview(
    consul: ConsulService = Depends(get_consul_service),
    metrics: MetricsService = Depends(get_metrics_service)
):
    """Get system overview metrics"""
    try:
        # Get all nodes
        nodes = consul.get_all_nodes()
        
        # Separate managers and workers
        managers = []
        workers = []
        
        for node in nodes:
            node_services = consul.get_node_services(node['Node'])
            is_manager = any(s.get('Service') == 'consul' for s in node_services)
            
            node_data = {
                'status': 'healthy' if consul.is_node_healthy(node['Node']) else 'failed',
                'cpu_usage': 0,  # Would get from actual metrics
                'memory_usage': 0,
                'disk_usage': 0
            }
            
            if is_manager:
                managers.append(node_data)
            else:
                workers.append(node_data)
        
        # Aggregate metrics
        system_metrics = metrics.aggregate_cluster_metrics(managers, workers)
        
        return system_metrics
    except Exception as e:
        logger.error(f"Failed to get overview: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/performance", response_model=Metrics)
async def get_performance_metrics(
    duration_hours: int = Query(24, ge=1, le=168, description="Duration in hours"),
    consul: ConsulService = Depends(get_consul_service),
    metrics: MetricsService = Depends(get_metrics_service)
):
    """Get performance metrics with time series data"""
    try:
        # Get current system metrics
        nodes = consul.get_all_nodes()
        managers = []
        workers = []
        
        for node in nodes:
            node_services = consul.get_node_services(node['Node'])
            is_manager = any(s.get('Service') == 'consul' for s in node_services)
            
            node_data = {'status': 'healthy'}
            if is_manager:
                managers.append(node_data)
            else:
                workers.append(node_data)
        
        system_metrics = metrics.aggregate_cluster_metrics(managers, workers)
        
        # Get time series data
        cpu_history = metrics.get_time_series_data('cpu', duration_hours)
        memory_history = metrics.get_time_series_data('memory', duration_hours)
        network_history = metrics.get_time_series_data('network', duration_hours)
        
        return Metrics(
            system=system_metrics,
            services=[],
            cpu_history=cpu_history,
            memory_history=memory_history,
            network_history=network_history
        )
    except Exception as e:
        logger.error(f"Failed to get performance metrics: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/timeseries/{metric_type}")
async def get_timeseries(
    metric_type: str,
    duration_hours: int = Query(24, ge=1, le=168),
    metrics: MetricsService = Depends(get_metrics_service)
):
    """Get time series data for a specific metric"""
    try:
        if metric_type not in ['cpu', 'memory', 'network']:
            raise HTTPException(status_code=400, detail="Invalid metric type")
        
        data = metrics.get_time_series_data(metric_type, duration_hours)
        return {"metric": metric_type, "data": data}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get timeseries for {metric_type}: {e}")
        raise HTTPException(status_code=500, detail=str(e))
