"""
Krutrim Nexus Ops Dashboard - FastAPI Backend
Main application entry point
"""

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, JSONResponse
from fastapi.exceptions import RequestValidationError
import logging
import asyncio
import json
import sys
from pathlib import Path
from typing import List
from datetime import datetime

# Import configuration first
try:
    from config import settings, validate_environment
except ImportError as e:
    print(f"FATAL: Failed to import configuration: {e}")
    print("Ensure config.py exists and all dependencies are installed")
    sys.exit(1)

from api import managers_router, workers_router, analytics_router, health_router
from services import ConsulService, MetricsService

# Configure logging from settings
logging.basicConfig(
    level=getattr(logging, settings.log_level),
    format=settings.log_format
)
logger = logging.getLogger(__name__)

# Validate environment before starting
is_valid, errors = validate_environment()
if not is_valid:
    logger.error("Environment validation failed:")
    for error in errors:
        logger.error(f"  - {error}")
    logger.error("Please fix the errors above before starting the dashboard")
    sys.exit(1)

logger.info("Environment validation passed")

# Create FastAPI app with configuration
app = FastAPI(
    title=settings.app_name,
    description="High Availability Manager-Worker Orchestration Platform",
    version=settings.app_version,
    docs_url="/api/docs" if settings.debug else None,  # Disable in production
    redoc_url="/api/redoc" if settings.debug else None,
    debug=settings.debug
)

# CORS middleware from settings
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=settings.cors_allow_credentials,
    allow_methods=settings.cors_allow_methods,
    allow_headers=settings.cors_allow_headers,
)

# Global exception handlers
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """Handle validation errors"""
    logger.error(f"Validation error on {request.url}: {exc}")
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={"detail": exc.errors(), "body": exc.body}
    )

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Handle unexpected errors"""
    logger.error(f"Unhandled exception on {request.url}: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "Internal server error"}
    )

# Include API routers
app.include_router(managers_router)
app.include_router(workers_router)
app.include_router(analytics_router)
app.include_router(health_router)

# Mount static files (frontend) with validation
frontend_path = Path(settings.frontend_path)
if not frontend_path.is_absolute():
    # Make relative to backend working directory (systemd WorkingDirectory)
    frontend_path = Path.cwd() / frontend_path
if frontend_path.exists():
    try:
        app.mount("/static", StaticFiles(directory=str(frontend_path)), name="static")
        logger.info(f"Static files mounted from: {frontend_path}")
    except Exception as e:
        logger.error(f"Failed to mount static files: {e}")
else:
    logger.warning(f"Frontend path not found: {frontend_path} - static files not available")

# WebSocket connection manager
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        logger.info(f"WebSocket connected. Total connections: {len(self.active_connections)}")

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)
        logger.info(f"WebSocket disconnected. Total connections: {len(self.active_connections)}")

    async def broadcast(self, message: dict):
        """Broadcast message to all connected clients"""
        disconnected = []
        for connection in self.active_connections:
            try:
                await connection.send_json(message)
            except Exception as e:
                logger.error(f"Failed to send to client: {e}")
                disconnected.append(connection)
        
        # Clean up disconnected clients
        for conn in disconnected:
            if conn in self.active_connections:
                self.active_connections.remove(conn)

manager = ConnectionManager()


@app.get("/api", tags=["Root"])
async def api_root():
    """API root endpoint with info"""
    return {
        "message": f"{settings.app_name}",
        "version": settings.app_version,
        "docs": "/api/docs" if settings.debug else "API documentation disabled"
    }

@app.get("/", response_class=FileResponse)
async def serve_frontend():
    """Serve the frontend dashboard HTML"""
    frontend_dir = Path(settings.frontend_path)
    if not frontend_dir.is_absolute():
        # Make relative to backend working directory (systemd WorkingDirectory)
        frontend_dir = Path.cwd() / frontend_dir
    frontend_html = frontend_dir / "index.html"
    if frontend_html.exists():
        return FileResponse(str(frontend_html))
    return JSONResponse(
        status_code=404,
        content={"error": "Frontend not found", "path": str(frontend_html)}
    )


@app.websocket("/ws/realtime")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for real-time metrics"""
    await manager.connect(websocket)
    
    try:
        consul = ConsulService(
            host=settings.consul_host,
            port=settings.consul_port
        )
        metrics_service = MetricsService(
            history_size=settings.metrics_history_size
        )
    except Exception as e:
        logger.error(f"Failed to initialize services for WebSocket: {e}")
        await websocket.close(code=1011, reason="Service initialization failed")
        return
    
    try:
        while True:
            try:
                # Collect current metrics with error handling
                system_metrics = metrics_service.collect_system_metrics()
                if not system_metrics:
                    logger.warning("Failed to collect system metrics, skipping update")
                    await asyncio.sleep(settings.metrics_collection_interval)
                    continue
                
                # Get cluster status with error handling
                nodes = consul.get_all_nodes()
                services = consul.get_all_services()
                
                # Prepare real-time update
                update = {
                    "type": "metrics_update",
                    "timestamp": system_metrics.get('timestamp', datetime.utcnow()).isoformat() if hasattr(system_metrics.get('timestamp', datetime.utcnow()), 'isoformat') else str(system_metrics.get('timestamp', datetime.utcnow())),
                    "data": {
                        "cpu_usage": system_metrics.get('cpu_usage', 0),
                        "memory_usage": system_metrics.get('memory_usage', 0),
                        "disk_usage": system_metrics.get('disk_usage', 0),
                        "network_in": system_metrics.get('network_in', 0),
                        "network_out": system_metrics.get('network_out', 0),
                        "total_nodes": len(nodes) if nodes else 0,
                        "total_services": len(services) if services else 0
                    }
                }
                
                # Send to this client
                await websocket.send_json(update)
                
            except Exception as e:
                logger.error(f"Error in WebSocket update loop: {e}")
                # Continue loop even if one update fails
            
            # Wait before next update
            await asyncio.sleep(settings.metrics_collection_interval)
            
    except WebSocketDisconnect:
        manager.disconnect(websocket)
        logger.info("Client disconnected from WebSocket")
    except Exception as e:
        logger.error(f"WebSocket error: {e}", exc_info=True)
        manager.disconnect(websocket)


@app.on_event("startup")
async def startup_event():
    """Application startup tasks"""
    logger.info(f"Starting {settings.app_name} v{settings.app_version}")
    logger.info(f"Debug mode: {settings.debug}")
    logger.info(f"Consul: {settings.consul_scheme}://{settings.consul_host}:{settings.consul_port}")
    
    if settings.debug:
        logger.info("API documentation available at /api/docs")
        logger.info("Dashboard available at /")
    
    # Test Consul connectivity
    try:
        consul = ConsulService(host=settings.consul_host, port=settings.consul_port)
        leader = consul.get_leader()
        if leader:
            logger.info(f"Consul connection successful, leader: {leader}")
        else:
            logger.warning("Consul connection established but no leader found")
    except Exception as e:
        logger.error(f"Failed to connect to Consul: {e}")
        logger.error("Dashboard will start but may not function correctly")


@app.on_event("shutdown")
async def shutdown_event():
    """Application shutdown tasks"""
    logger.info("Shutting down Krutrim Nexus Ops Dashboard...")


if __name__ == "__main__":
    import uvicorn
    
    # Add datetime import for websocket
    from datetime import datetime
    
    logger.info(f"Starting uvicorn server on {settings.host}:{settings.port}")
    uvicorn.run(
        app,
        host=settings.host,
        port=settings.port,
        log_level=settings.log_level.lower(),
        access_log=settings.debug
    )
