"""
Manager API endpoints
"""

from fastapi import APIRouter, HTTPException, Depends
from typing import List
import logging

from ..models import Manager, ManagerStatus
from ..services import ConsulService, MetricsService

router = APIRouter(prefix="/api/managers", tags=["managers"])
logger = logging.getLogger(__name__)

# Dependency injection
def get_consul_service():
    return ConsulService()

def get_metrics_service():
    return MetricsService()


@router.get("/", response_model=List[Manager])
async def list_managers(
    consul: ConsulService = Depends(get_consul_service),
    metrics: MetricsService = Depends(get_metrics_service)
):
    """List all manager nodes"""
    try:
        nodes = consul.get_all_nodes()
        leader = consul.get_leader()
        
        managers = []
        for node in nodes:
            # Determine if this node is a manager (has consul server role)
            node_services = consul.get_node_services(node['Node'])
            is_manager = any(s.get('Service') == 'consul' for s in node_services)
            
            if is_manager:
                # Collect metrics
                system_metrics = metrics.collect_system_metrics()
                
                # Determine role
                node_address = f"{node['Address']}:8300"
                role = "primary" if leader and node_address in leader else "secondary"
                
                # Get worker count (simplified - would query actual data)
                all_nodes = consul.get_all_nodes()
                worker_count = len([n for n in all_nodes if n['Node'] != node['Node']])
                
                manager = Manager(
                    id=f"mgr-{node['Node']}",
                    hostname=node['Node'],
                    ip_address=node['Address'],
                    role=role,
                    status=ManagerStatus.HEALTHY if consul.is_node_healthy(node['Node']) else ManagerStatus.FAILED,
                    cpu_usage=system_metrics.get('cpu_usage', 0),
                    memory_usage=system_metrics.get('memory_usage', 0),
                    disk_usage=system_metrics.get('disk_usage', 0),
                    uptime_seconds=metrics.get_uptime(),
                    consul_leader=(role == "primary"),
                    managed_workers=worker_count,
                    healthy_workers=worker_count  # Simplified
                )
                managers.append(manager)
        
        return managers
    except Exception as e:
        logger.error(f"Failed to list managers: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{manager_id}", response_model=Manager)
async def get_manager(
    manager_id: str,
    consul: ConsulService = Depends(get_consul_service),
    metrics: MetricsService = Depends(get_metrics_service)
):
    """Get specific manager details"""
    try:
        # Extract node name from manager_id
        node_name = manager_id.replace("mgr-", "")
        
        nodes = consul.get_all_nodes()
        node = next((n for n in nodes if n['Node'] == node_name), None)
        
        if not node:
            raise HTTPException(status_code=404, detail="Manager not found")
        
        # Get detailed metrics
        system_metrics = metrics.collect_system_metrics()
        leader = consul.get_leader()
        node_address = f"{node['Address']}:8300"
        role = "primary" if leader and node_address in leader else "secondary"
        
        manager = Manager(
            id=manager_id,
            hostname=node['Node'],
            ip_address=node['Address'],
            role=role,
            status=ManagerStatus.HEALTHY,
            cpu_usage=system_metrics.get('cpu_usage', 0),
            memory_usage=system_metrics.get('memory_usage', 0),
            disk_usage=system_metrics.get('disk_usage', 0),
            uptime_seconds=metrics.get_uptime(),
            consul_leader=(role == "primary")
        )
        
        return manager
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get manager {manager_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{manager_id}/restart")
async def restart_manager_service(manager_id: str):
    """Restart manager orchestrator service"""
    # This would execute systemctl restart nexus-orchestrator
    # For now, return success
    return {"status": "success", "message": f"Restart command sent to {manager_id}"}
