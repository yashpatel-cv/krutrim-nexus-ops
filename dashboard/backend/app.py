"""
Krutrim Nexus Ops Dashboard - FastAPI Backend
Main application entry point
"""

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import logging
import asyncio
import json
from pathlib import Path
from typing import List

from .api import managers_router, workers_router, analytics_router, health_router
from .services import ConsulService, MetricsService

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] [%(name)s] [%(levelname)s] %(message)s'
)
logger = logging.getLogger(__name__)

# Create FastAPI app
app = FastAPI(
    title="Krutrim Nexus Ops Dashboard",
    description="High Availability Manager-Worker Orchestration Platform",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API routers
app.include_router(managers_router)
app.include_router(workers_router)
app.include_router(analytics_router)
app.include_router(health_router)

# Mount static files (frontend)
frontend_path = Path(__file__).parent.parent / "frontend"
if frontend_path.exists():
    app.mount("/static", StaticFiles(directory=str(frontend_path)), name="static")

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


@app.get("/")
async def root():
    """Serve the dashboard frontend"""
    index_path = frontend_path / "index.html"
    if index_path.exists():
        return FileResponse(index_path)
    return {"message": "Krutrim Nexus Ops Dashboard API", "docs": "/api/docs"}


@app.websocket("/ws/realtime")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for real-time metrics"""
    await manager.connect(websocket)
    
    consul = ConsulService()
    metrics_service = MetricsService()
    
    try:
        while True:
            # Collect current metrics
            system_metrics = metrics_service.collect_system_metrics()
            
            # Get cluster status
            nodes = consul.get_all_nodes()
            services = consul.get_all_services()
            
            # Prepare real-time update
            update = {
                "type": "metrics_update",
                "timestamp": system_metrics['timestamp'].isoformat(),
                "data": {
                    "cpu_usage": system_metrics['cpu_usage'],
                    "memory_usage": system_metrics['memory_usage'],
                    "disk_usage": system_metrics['disk_usage'],
                    "network_in": system_metrics['network_in'],
                    "network_out": system_metrics['network_out'],
                    "total_nodes": len(nodes),
                    "total_services": len(services)
                }
            }
            
            # Send to this client
            await websocket.send_json(update)
            
            # Wait 5 seconds before next update
            await asyncio.sleep(5)
            
    except WebSocketDisconnect:
        manager.disconnect(websocket)
        logger.info("Client disconnected from WebSocket")
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        manager.disconnect(websocket)


@app.on_event("startup")
async def startup_event():
    """Application startup tasks"""
    logger.info("Starting Krutrim Nexus Ops Dashboard...")
    logger.info("API documentation available at /api/docs")
    logger.info("Dashboard available at /")


@app.on_event("shutdown")
async def shutdown_event():
    """Application shutdown tasks"""
    logger.info("Shutting down Krutrim Nexus Ops Dashboard...")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=9000, log_level="info")
