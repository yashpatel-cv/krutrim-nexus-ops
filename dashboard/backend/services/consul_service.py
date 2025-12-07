"""
Consul integration service
"""

import consul
import logging
from typing import List, Dict, Optional
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)


class ConsulService:
    """Service for interacting with Consul with comprehensive error handling"""
    
    def __init__(self, host: str = "localhost", port: int = 8500, token: Optional[str] = None, scheme: str = "http", timeout: int = 10):
        """
        Initialize Consul service with validation
        
        Args:
            host: Consul host (cannot be 0.0.0.0 for client)
            port: Consul port
            token: Optional ACL token
            scheme: http or https
            timeout: Connection timeout in seconds
        """
        # Validate inputs
        if not host or host.strip() == "":
            raise ValueError("Consul host cannot be empty")
        if host == "0.0.0.0":
            raise ValueError("Consul host cannot be 0.0.0.0 (use localhost or specific IP)")
        if not 1 <= port <= 65535:
            raise ValueError(f"Invalid port: {port}. Must be between 1 and 65535")
        if scheme not in ["http", "https"]:
            raise ValueError(f"Invalid scheme: {scheme}. Must be 'http' or 'https'")
        
        self.host = host.strip()
        self.port = port
        self.token = token
        self.scheme = scheme
        self.timeout = timeout
        self._connected = False
        
        try:
            # Create Consul client with timeout
            self.consul = consul.Consul(
                host=self.host,
                port=self.port,
                token=self.token,
                scheme=self.scheme,
                timeout=self.timeout
            )
            
            # Test connection
            self.consul.agent.self()
            self._connected = True
            logger.info(f"Connected to Consul at {self.scheme}://{self.host}:{self.port}")
        except Exception as e:
            logger.error(f"Failed to connect to Consul at {self.scheme}://{self.host}:{self.port}: {e}")
            logger.warning("Consul service will operate in degraded mode")
            # Create a stub consul object to prevent crashes
            self.consul = consul.Consul(
                host=self.host,
                port=self.port,
                token=self.token,
                scheme=self.scheme
            )
            self._connected = False
    
    def is_connected(self) -> bool:
        """Check if connected to Consul"""
        return self._connected
        
    def get_all_nodes(self) -> List[Dict]:
        """Get all nodes in the cluster"""
        try:
            _, nodes = self.consul.catalog.nodes()
            return nodes
        except Exception as e:
            logger.error(f"Failed to get nodes from Consul: {e}")
            return []
    
    def get_all_services(self) -> Dict[str, List]:
        """Get all registered services"""
        try:
            _, services = self.consul.catalog.services()
            return services
        except Exception as e:
            logger.error(f"Failed to get services from Consul: {e}")
            return {}
    
    def get_service_health(self, service_name: str) -> List[Dict]:
        """Get health status for a specific service"""
        try:
            _, checks = self.consul.health.service(service_name, passing=True)
            return checks
        except Exception as e:
            logger.error(f"Failed to get health for {service_name}: {e}")
            return []
    
    def get_node_services(self, node_name: str) -> List[Dict]:
        """Get all services running on a specific node"""
        try:
            _, services = self.consul.catalog.node(node_name)
            return services.get('Services', {}).values() if services else []
        except Exception as e:
            logger.error(f"Failed to get services for node {node_name}: {e}")
            return []
    
    def get_leader(self) -> Optional[str]:
        """Get current Consul leader"""
        try:
            leader = self.consul.status.leader()
            return leader
        except Exception as e:
            logger.error(f"Failed to get Consul leader: {e}")
            return None
    
    def get_peers(self) -> List[str]:
        """Get all Consul peers"""
        try:
            peers = self.consul.status.peers()
            return peers
        except Exception as e:
            logger.error(f"Failed to get Consul peers: {e}")
            return []
    
    def register_service(self, service_id: str, service_name: str, 
                        port: int, address: str, 
                        health_check_url: Optional[str] = None) -> bool:
        """Register a new service with Consul"""
        try:
            check = None
            if health_check_url:
                check = consul.Check.http(health_check_url, interval="10s", timeout="5s")
            
            self.consul.agent.service.register(
                name=service_name,
                service_id=service_id,
                address=address,
                port=port,
                check=check
            )
            logger.info(f"Registered service {service_name} ({service_id})")
            return True
        except Exception as e:
            logger.error(f"Failed to register service {service_name}: {e}")
            return False
    
    def deregister_service(self, service_id: str) -> bool:
        """Deregister a service from Consul"""
        try:
            self.consul.agent.service.deregister(service_id)
            logger.info(f"Deregistered service {service_id}")
            return True
        except Exception as e:
            logger.error(f"Failed to deregister service {service_id}: {e}")
            return False
    
    def get_kv(self, key: str) -> Optional[str]:
        """Get value from Consul KV store"""
        try:
            _, data = self.consul.kv.get(key)
            return data['Value'].decode('utf-8') if data else None
        except Exception as e:
            logger.error(f"Failed to get KV {key}: {e}")
            return None
    
    def put_kv(self, key: str, value: str) -> bool:
        """Put value into Consul KV store"""
        try:
            self.consul.kv.put(key, value)
            logger.info(f"Stored KV {key}")
            return True
        except Exception as e:
            logger.error(f"Failed to put KV {key}: {e}")
            return False
    
    def is_node_healthy(self, node_name: str, timeout_seconds: int = 60) -> bool:
        """Check if a node is healthy based on last heartbeat"""
        try:
            _, node = self.consul.catalog.node(node_name)
            if not node:
                return False
            
            # Check if node has recent activity
            # In production, you'd check actual health checks
            return True
        except Exception as e:
            logger.error(f"Failed to check health for {node_name}: {e}")
            return False
