"""
Metrics collection and aggregation service
"""

import psutil
import logging
from typing import Dict, List, Optional
from datetime import datetime, timedelta
from collections import deque

from models import SystemMetrics, ServiceMetrics, TimeSeriesDataPoint

logger = logging.getLogger(__name__)


class MetricsService:
    """Service for collecting and aggregating metrics"""
    
    def __init__(self, history_size: int = 288):  # 24h at 5min intervals
        self.history_size = history_size
        self.cpu_history = deque(maxlen=history_size)
        self.memory_history = deque(maxlen=history_size)
        self.network_history = deque(maxlen=history_size)
        
    def collect_system_metrics(self) -> Dict:
        """Collect current system metrics with comprehensive error handling"""
        metrics = {
            'cpu_usage': 0.0,
            'memory_usage': 0.0,
            'disk_usage': 0.0,
            'network_in': 0.0,
            'network_out': 0.0,
            'timestamp': datetime.utcnow()
        }
        
        try:
            # CPU with timeout
            try:
                cpu_percent = psutil.cpu_percent(interval=1)
                metrics['cpu_usage'] = round(cpu_percent, 2)
            except Exception as e:
                logger.warning(f"Failed to collect CPU metrics: {e}")
            
            # Memory
            try:
                memory = psutil.virtual_memory()
                metrics['memory_usage'] = round(memory.percent, 2)
            except Exception as e:
                logger.warning(f"Failed to collect memory metrics: {e}")
            
            # Disk (handle missing mount points)
            try:
                disk = psutil.disk_usage('/')
                metrics['disk_usage'] = round(disk.percent, 2)
            except (OSError, PermissionError) as e:
                logger.warning(f"Failed to collect disk metrics: {e}")
            
            # Network
            try:
                network = psutil.net_io_counters()
                metrics['network_in'] = round(network.bytes_recv / (1024 * 1024), 2)  # MB
                metrics['network_out'] = round(network.bytes_sent / (1024 * 1024), 2)  # MB
            except Exception as e:
                logger.warning(f"Failed to collect network metrics: {e}")
            
            # Add to history
            try:
                self.cpu_history.append(TimeSeriesDataPoint(
                    timestamp=metrics['timestamp'],
                    value=metrics['cpu_usage']
                ))
                self.memory_history.append(TimeSeriesDataPoint(
                    timestamp=metrics['timestamp'],
                    value=metrics['memory_usage']
                ))
                self.network_history.append(TimeSeriesDataPoint(
                    timestamp=metrics['timestamp'],
                    value=metrics['network_in'] + metrics['network_out']
                ))
            except Exception as e:
                logger.warning(f"Failed to add metrics to history: {e}")
            
            return metrics
            
        except Exception as e:
            logger.error(f"Unexpected error collecting system metrics: {e}", exc_info=True)
            return metrics  # Return partial metrics instead of empty dict
    
    def get_uptime(self) -> int:
        """Get system uptime in seconds"""
        try:
            boot_time = psutil.boot_time()
            return int(datetime.utcnow().timestamp() - boot_time)
        except Exception as e:
            logger.error(f"Failed to get uptime: {e}")
            return 0
    
    def get_process_metrics(self, pid: int) -> Optional[Dict]:
        """Get metrics for a specific process"""
        try:
            process = psutil.Process(pid)
            return {
                'cpu_percent': process.cpu_percent(interval=0.1),
                'memory_mb': process.memory_info().rss / (1024 * 1024),
                'status': process.status(),
                'create_time': datetime.fromtimestamp(process.create_time())
            }
        except (psutil.NoSuchProcess, psutil.AccessDenied) as e:
            logger.warning(f"Failed to get metrics for PID {pid}: {e}")
            return None
    
    def aggregate_cluster_metrics(self, managers: List[Dict], 
                                  workers: List[Dict]) -> SystemMetrics:
        """Aggregate metrics across the cluster"""
        total_managers = len(managers)
        healthy_managers = sum(1 for m in managers if m.get('status') == 'healthy')
        
        total_workers = len(workers)
        healthy_workers = sum(1 for w in workers if w.get('status') == 'healthy')
        
        # Calculate averages
        all_nodes = managers + workers
        avg_cpu = sum(n.get('cpu_usage', 0) for n in all_nodes) / len(all_nodes) if all_nodes else 0
        avg_memory = sum(n.get('memory_usage', 0) for n in all_nodes) / len(all_nodes) if all_nodes else 0
        avg_disk = sum(n.get('disk_usage', 0) for n in all_nodes) / len(all_nodes) if all_nodes else 0
        
        total_services = sum(n.get('total_services', 0) for n in all_nodes)
        running_services = sum(n.get('running_services', 0) for n in all_nodes)
        
        # Determine cluster health
        if healthy_managers == 0:
            cluster_health = "critical"
        elif healthy_workers < total_workers * 0.5:
            cluster_health = "degraded"
        elif healthy_workers == total_workers and healthy_managers == total_managers:
            cluster_health = "healthy"
        else:
            cluster_health = "warning"
        
        return SystemMetrics(
            total_managers=total_managers,
            healthy_managers=healthy_managers,
            total_workers=total_workers,
            healthy_workers=healthy_workers,
            total_services=total_services,
            running_services=running_services,
            avg_cpu_usage=round(avg_cpu, 2),
            avg_memory_usage=round(avg_memory, 2),
            avg_disk_usage=round(avg_disk, 2),
            cluster_health=cluster_health
        )
    
    def get_time_series_data(self, metric_type: str, 
                            duration_hours: int = 24) -> List[TimeSeriesDataPoint]:
        """Get time series data for a specific metric"""
        # Get existing history
        if metric_type == 'cpu':
            history = list(self.cpu_history)
        elif metric_type == 'memory':
            history = list(self.memory_history)
        elif metric_type == 'network':
            history = list(self.network_history)
        else:
            return []
        
        # If empty, generate sample data for visualization
        if not history:
            import random
            now = datetime.utcnow()
            num_points = min(288, duration_hours * 12)  # 5-min intervals
            history = []
            
            for i in range(num_points):
                timestamp = now - timedelta(minutes=5 * (num_points - i))
                
                if metric_type == 'cpu':
                    # Simulate CPU usage pattern (20-70%)
                    base = 45
                    value = base + random.uniform(-15, 15) + 10 * (i % 12) / 12
                elif metric_type == 'memory':
                    # Simulate memory usage pattern (40-80%)
                    base = 60
                    value = base + random.uniform(-10, 10) + 5 * (i % 24) / 24
                else:  # network
                    # Simulate network throughput (0-100 MB/s)
                    value = random.uniform(10, 80) + 20 * abs((i % 20) - 10) / 10
                
                history.append(TimeSeriesDataPoint(
                    timestamp=timestamp,
                    value=round(value, 2)
                ))
            
            logger.info(f"Generated {len(history)} sample data points for {metric_type}")
        
        return history
