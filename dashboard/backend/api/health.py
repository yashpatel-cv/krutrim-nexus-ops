"""
Health check API endpoints
"""

from fastapi import APIRouter, Depends
import logging
from datetime import datetime

from services import ConsulService

router = APIRouter(prefix="/api/health", tags=["health"])
logger = logging.getLogger(__name__)


def get_consul_service():
    return ConsulService()


@router.get("/")
async def health_check():
    """Basic health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "krutrim-nexus-dashboard"
    }


@router.get("/consul")
async def consul_health(consul: ConsulService = Depends(get_consul_service)):
    """Check Consul connectivity"""
    try:
        leader = consul.get_leader()
        peers = consul.get_peers()
        
        return {
            "status": "healthy" if leader else "unhealthy",
            "leader": leader,
            "peers_count": len(peers),
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        logger.error(f"Consul health check failed: {e}")
        return {
            "status": "unhealthy",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }


@router.get("/cluster")
async def cluster_health(consul: ConsulService = Depends(get_consul_service)):
    """Check overall cluster health"""
    try:
        nodes = consul.get_all_nodes()
        services = consul.get_all_services()
        
        healthy_nodes = sum(1 for node in nodes if consul.is_node_healthy(node['Node']))
        
        return {
            "status": "healthy" if healthy_nodes > 0 else "unhealthy",
            "total_nodes": len(nodes),
            "healthy_nodes": healthy_nodes,
            "total_services": len(services),
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        logger.error(f"Cluster health check failed: {e}")
        return {
            "status": "unhealthy",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }
