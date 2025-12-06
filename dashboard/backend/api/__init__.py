"""
API endpoints for Krutrim Nexus Ops Dashboard
"""

from .managers import router as managers_router
from .workers import router as workers_router
from .analytics import router as analytics_router
from .health import router as health_router

__all__ = ['managers_router', 'workers_router', 'analytics_router', 'health_router']
