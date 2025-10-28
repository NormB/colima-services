"""
Main FastAPI Application (API-First Implementation)

Auto-generated from OpenAPI specification.
This implementation is generated from the OpenAPI spec and enhanced
with business logic to match the code-first implementation.
"""

from fastapi import FastAPI, Request
from fastapi.responses import Response
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
import logging
import time
import uuid

from app.routers import (
    health_checks,
    vault_examples,
    database_examples,
    cache_examples,
    messaging_examples,
    redis_cluster
)
from app.config import settings
from app.middleware.exception_handlers import register_exception_handlers

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Prometheus metrics
http_requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

http_request_duration_seconds = Histogram(
    'http_request_duration_seconds',
    'HTTP request latency',
    ['method', 'endpoint']
)

http_requests_in_progress = Gauge(
    'http_requests_in_progress',
    'HTTP requests in progress',
    ['method', 'endpoint']
)

app_info = Gauge(
    'app_info',
    'Application information',
    ['version', 'name']
)

# Initialize rate limiter
limiter = Limiter(key_func=get_remote_address)

# Create FastAPI app
app = FastAPI(
    title="Colima Services - Reference API (API-First)",
    version="1.0.0",
    description="API-First implementation generated from OpenAPI specification",
    docs_url="/docs",
    redoc_url="/redoc",
)

# Configure CORS
CORS_ORIGINS = [
    "http://localhost:3000",
    "http://localhost:8000",
    "http://localhost:8001",
    "http://127.0.0.1:3000",
    "http://127.0.0.1:8000",
    "http://127.0.0.1:8001",
]

if settings.DEBUG:
    CORS_ORIGINS = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=not settings.DEBUG,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization", "X-Request-ID", "X-API-Key"],
    expose_headers=["X-Request-ID", "X-RateLimit-Limit", "X-RateLimit-Remaining"],
    max_age=600,
)

# Add rate limiter to app state
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Register custom exception handlers
register_exception_handlers(app)


@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    """Middleware to collect metrics and add request tracking"""
    request_id = str(uuid.uuid4())
    request.state.request_id = request_id

    method = request.method
    path = request.url.path

    # Track in-progress requests
    http_requests_in_progress.labels(method=method, endpoint=path).inc()

    start_time = time.time()

    try:
        response = await call_next(request)
        duration = time.time() - start_time

        # Record metrics
        http_requests_total.labels(
            method=method,
            endpoint=path,
            status=response.status_code
        ).inc()

        http_request_duration_seconds.labels(
            method=method,
            endpoint=path
        ).observe(duration)

        # Add headers
        response.headers["X-Request-ID"] = request_id
        response.headers["X-Response-Time"] = f"{duration:.3f}s"

        return response

    finally:
        http_requests_in_progress.labels(method=method, endpoint=path).dec()


# Include routers
app.include_router(health_checks.router)
app.include_router(vault_examples.router)
app.include_router(database_examples.router)
app.include_router(cache_examples.router)
app.include_router(messaging_examples.router)
app.include_router(redis_cluster.router)


@app.on_event("startup")
async def startup_event():
    """Application startup event handler."""
    logger.info("Starting API-First FastAPI application...")
    logger.info(f"Debug mode: {settings.DEBUG}")
    logger.info(f"Vault address: {settings.VAULT_ADDR}")

    # Set app info metric
    app_info.labels(version="1.0.0", name="api-first").set(1)


@app.on_event("shutdown")
async def shutdown_event():
    """Application shutdown event handler."""
    logger.info("Shutting down API-First FastAPI application...")


@app.get("/")
@limiter.limit("100/minute")
async def root(request: Request):
    """Root endpoint with API information.

    Rate Limit: 100 requests per minute per IP
    """
    return {
        "name": "Colima Services Reference API",
        "version": "1.0.0",
        "description": "Reference implementation for infrastructure integration",
        "docs": "/docs",
        "health": "/health/all",
        "metrics": "/metrics",
        "security": {
            "cors": {
                "enabled": True,
                "allowed_origins": "localhost:3000, localhost:8000, localhost:8080",
                "allowed_methods": "GET, POST, PUT, DELETE, PATCH, OPTIONS",
                "credentials": True,
                "max_age": "600s"
            },
            "rate_limiting": {
                "general_endpoints": "100/minute",
                "metrics_endpoint": "1000/minute",
                "health_checks": "200/minute"
            },
            "request_validation": {
                "max_request_size": "10MB",
                "allowed_content_types": [
                    "application/json",
                    "application/x-www-form-urlencoded",
                    "multipart/form-data",
                    "text/plain"
                ]
            },
            "circuit_breakers": {
                "enabled": True,
                "services": [
                    "vault",
                    "postgres",
                    "mysql",
                    "mongodb",
                    "redis",
                    "rabbitmq"
                ],
                "failure_threshold": 5,
                "reset_timeout": "60s"
            }
        },
        "redis_cluster": {
            "nodes": "/redis/cluster/nodes",
            "slots": "/redis/cluster/slots",
            "info": "/redis/cluster/info",
            "node_info": "/redis/nodes/{node_name}/info"
        },
        "examples": {
            "vault": "/examples/vault",
            "databases": "/examples/database",
            "cache": "/examples/cache",
            "messaging": "/examples/messaging"
        },
        "note": "This is a reference implementation, not production code"
    }


@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST
    )
