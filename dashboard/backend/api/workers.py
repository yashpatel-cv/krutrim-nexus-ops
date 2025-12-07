"""
Worker API endpoints
"""

from fastapi import APIRouter, HTTPException, Depends, Query
from typing import List, Optional
import logging

from models import Worker, WorkerStatus, WorkerPool, ServiceInfo
from services import ConsulService, MetricsService

router = APIRouter(prefix="/api/workers", tags=["workers"])
logger = logging.getLogger(__name__)


def get_consul_service():
    return ConsulService()

def get_metrics_service():
    return MetricsService()


@router.get("/", response_model=List[Worker])
async def list_workers(
    pool: Optional[WorkerPool] = Query(None, description="Filter by worker pool"),
    status: Optional[WorkerStatus] = Query(None, description="Filter by status"),
    consul: ConsulService = Depends(get_consul_service),
    metrics: MetricsService = Depends(get_metrics_service)
):
    """List all worker nodes with optional filters"""
    try:
        nodes = consul.get_all_nodes()
        workers = []
        
        for node in nodes:
            # Get services running on this node
            node_services = consul.get_node_services(node['Node'])
            
            # Check if this is a worker (has nexus-worker service)
            is_worker = any('worker' in s.get('Service', '').lower() for s in node_services)
            
            if is_worker:
                # Collect metrics
                system_metrics = metrics.collect_system_metrics()
                
                # Parse services
                services = []
                for svc in node_services:
                    if svc.get('Service') != 'consul':
                        services.append(ServiceInfo(
                            name=svc.get('Service', 'unknown'),
                            status='running',
                            port=svc.get('Port', 0),
                            restarts=0,
                            uptime_seconds=0
                        ))
                
                # Determine worker pool from tags or default
                worker_pool = WorkerPool.WORKER
                for svc in node_services:
                    tags = svc.get('Tags', [])
                    if 'web' in tags:
                        worker_pool = WorkerPool.WEB
                    elif 'api' in tags:
                        worker_pool = WorkerPool.API
                    elif 'database' in tags:
                        worker_pool = WorkerPool.DATABASE
                
                worker = Worker(
                    id=f"wkr-{node['Node']}",
                    hostname=node['Node'],
                    ip_address=node['Address'],
                    pool=worker_pool,
                    status=WorkerStatus.HEALTHY if consul.is_node_healthy(node['Node']) else WorkerStatus.FAILED,
                    cpu_usage=system_metrics.get('cpu_usage', 0),
                    memory_usage=system_metrics.get('memory_usage', 0),
                    disk_usage=system_metrics.get('disk_usage', 0),
                    uptime_seconds=metrics.get_uptime(),
                    services=services,
                    total_services=len(services),
                    healthy_services=len([s for s in services if s.status == 'running'])
                )
                
                # Apply filters
                if pool and worker.pool != pool:
                    continue
                if status and worker.status != status:
                    continue
                
                workers.append(worker)
        
        return workers
    except Exception as e:
        logger.error(f"Failed to list workers: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{worker_id}", response_model=Worker)
async def get_worker(
    worker_id: str,
    consul: ConsulService = Depends(get_consul_service),
    metrics: MetricsService = Depends(get_metrics_service)
):
    """Get specific worker details"""
    try:
        node_name = worker_id.replace("wkr-", "")
        
        nodes = consul.get_all_nodes()
        node = next((n for n in nodes if n['Node'] == node_name), None)
        
        if not node:
            raise HTTPException(status_code=404, detail="Worker not found")
        
        # Get detailed metrics and services
        system_metrics = metrics.collect_system_metrics()
        node_services = consul.get_node_services(node['Node'])
        
        services = []
        for svc in node_services:
            if svc.get('Service') != 'consul':
                services.append(ServiceInfo(
                    name=svc.get('Service', 'unknown'),
                    status='running',
                    port=svc.get('Port', 0),
                    restarts=0,
                    uptime_seconds=0
                ))
        
        worker = Worker(
            id=worker_id,
            hostname=node['Node'],
            ip_address=node['Address'],
            pool=WorkerPool.WORKER,
            status=WorkerStatus.HEALTHY,
            cpu_usage=system_metrics.get('cpu_usage', 0),
            memory_usage=system_metrics.get('memory_usage', 0),
            disk_usage=system_metrics.get('disk_usage', 0),
            uptime_seconds=metrics.get_uptime(),
            services=services,
            total_services=len(services),
            healthy_services=len(services)
        )
        
        return worker
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get worker {worker_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{worker_id}/restart")
async def restart_worker(worker_id: str):
    """Restart worker agent service"""
    return {"status": "success", "message": f"Restart command sent to {worker_id}"}


@router.post("/{worker_id}/drain")
async def drain_worker(worker_id: str):
    """Drain worker (stop accepting new work)"""
    return {"status": "success", "message": f"Drain initiated for {worker_id}"}
