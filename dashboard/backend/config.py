"""
Configuration management for Krutrim Nexus Ops Dashboard
Centralized configuration with environment variable support and validation
"""

import os
import logging
from typing import Optional
from pydantic import Field, field_validator
from pydantic_settings import BaseSettings

logger = logging.getLogger(__name__)


class Settings(BaseSettings):
    """Application settings with validation and defaults"""
    
    # Application
    app_name: str = Field(default="Krutrim Nexus Ops Dashboard", description="Application name")
    app_version: str = Field(default="1.0.0", description="Application version")
    debug: bool = Field(default=False, description="Debug mode")
    
    # Server
    host: str = Field(default="0.0.0.0", description="Server bind address")
    port: int = Field(default=9000, ge=1024, le=65535, description="Server port")
    public_url: Optional[str] = Field(default=None, description="Public URL (e.g., http://64.181.212.50:9000)")
    
    # Consul
    consul_host: str = Field(default="localhost", description="Consul host")
    consul_port: int = Field(default=8500, ge=1, le=65535, description="Consul port")
    consul_bind_addr: Optional[str] = Field(default=None, description="Consul bind address (for reference)")
    consul_scheme: str = Field(default="http", pattern="^(http|https)$", description="Consul scheme")
    consul_token: Optional[str] = Field(default=None, description="Consul ACL token")
    consul_datacenter: str = Field(default="krutrim-dc1", description="Consul datacenter")
    consul_timeout: int = Field(default=10, ge=1, le=60, description="Consul timeout seconds")
    
    # Metrics
    metrics_history_size: int = Field(default=288, ge=10, le=1000, description="Metrics history size (24h at 5min intervals)")
    metrics_collection_interval: int = Field(default=5, ge=1, le=60, description="Metrics collection interval seconds")
    
    # Logging
    log_level: str = Field(default="INFO", pattern="^(DEBUG|INFO|WARNING|ERROR|CRITICAL)$")
    log_format: str = Field(default="[%(asctime)s] [%(name)s] [%(levelname)s] %(message)s")
    
    # CORS
    cors_origins: list[str] = Field(default=["*"], description="CORS allowed origins")
    cors_allow_credentials: bool = Field(default=True)
    cors_allow_methods: list[str] = Field(default=["*"])
    cors_allow_headers: list[str] = Field(default=["*"])
    
    # WebSocket
    websocket_heartbeat_interval: int = Field(default=30, ge=10, le=300, description="WebSocket heartbeat interval")
    
    # API Rate Limiting
    rate_limit_enabled: bool = Field(default=True, description="Enable rate limiting")
    rate_limit_requests: int = Field(default=100, ge=1, description="Max requests per minute")
    
    # Security
    secret_key: str = Field(default="change-this-in-production-use-env-var", min_length=32)
    
    # Paths
    frontend_path: str = Field(default="../frontend", description="Frontend static files path (relative to backend dir)")
    
    @field_validator("consul_host")
    @classmethod
    def validate_consul_host(cls, v: str) -> str:
        """Validate Consul host"""
        if not v or v.strip() == "":
            raise ValueError("Consul host cannot be empty")
        # Allow localhost for local Consul, but warn about 0.0.0.0
        if v == "0.0.0.0":
            logger.warning("Consul host is 0.0.0.0 - this may not work for remote connections")
        return v.strip()
    
    @field_validator("secret_key")
    @classmethod
    def validate_secret_key(cls, v: str) -> str:
        """Validate secret key"""
        if v == "change-this-in-production-use-env-var":
            logger.warning("Using default secret key - set SECRET_KEY environment variable for production!")
        return v
    
    @field_validator("cors_origins")
    @classmethod
    def validate_cors_origins(cls, v: list[str]) -> list[str]:
        """Validate CORS origins"""
        if "*" in v:
            logger.warning("CORS allows all origins - restrict in production!")
        return v
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False
        # Map environment variables with prefix
        env_prefix = "NEXUS_"


# Singleton settings instance
_settings: Optional[Settings] = None


def get_settings() -> Settings:
    """Get settings singleton instance"""
    global _settings
    if _settings is None:
        try:
            _settings = Settings()
            logger.info(f"Configuration loaded: {_settings.app_name} v{_settings.app_version}")
            logger.info(f"Consul endpoint: {_settings.consul_scheme}://{_settings.consul_host}:{_settings.consul_port}")
            logger.info(f"Dashboard will run on: http://{_settings.host}:{_settings.port}")
        except Exception as e:
            logger.error(f"Failed to load configuration: {e}")
            # Use defaults but log the error
            _settings = Settings()
    return _settings


def validate_environment() -> tuple[bool, list[str]]:
    """
    Validate environment before starting application
    Returns: (is_valid, list_of_errors)
    """
    errors = []
    
    try:
        settings = get_settings()
        
        # Validate Consul connectivity
        import socket
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(2)
            result = sock.connect_ex((settings.consul_host, settings.consul_port))
            sock.close()
            if result != 0:
                errors.append(f"Cannot connect to Consul at {settings.consul_host}:{settings.consul_port}")
        except Exception as e:
            errors.append(f"Consul connectivity check failed: {e}")
        
        # Validate port availability
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            sock.bind(('', settings.port))
            sock.close()
        except OSError as e:
            if e.errno == 98:  # Address already in use
                errors.append(f"Port {settings.port} is already in use")
            else:
                errors.append(f"Port {settings.port} validation failed: {e}")
        
        # Validate required Python modules
        required_modules = [
            'fastapi', 'uvicorn', 'consul', 'pydantic', 'pydantic_settings',
            'psutil', 'websockets'
        ]
        for module in required_modules:
            try:
                __import__(module.replace('-', '_'))
            except ImportError:
                errors.append(f"Required Python module not found: {module}")
        
        # Validate paths
        from pathlib import Path
        frontend_path = Path(__file__).parent.parent / settings.frontend_path
        if not frontend_path.exists():
            errors.append(f"Frontend path not found: {frontend_path}")
        
    except Exception as e:
        errors.append(f"Environment validation failed: {e}")
    
    return (len(errors) == 0, errors)


# Export for easy importing
settings = get_settings()
