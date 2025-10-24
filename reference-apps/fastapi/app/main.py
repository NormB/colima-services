"""
FastAPI Reference Application for Colima Services Infrastructure

This application demonstrates how to integrate with the infrastructure services:
- HashiCorp Vault for secrets management
- PostgreSQL, MySQL, MongoDB for data storage
- Redis cluster for caching
- RabbitMQ for messaging

This is a REFERENCE IMPLEMENTATION for learning and testing.
Not intended for production use.
"""

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, Response
import logging
import sys
import time
import uuid
from pythonjsonlogger import jsonlogger

from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST

from app.routers import health, vault_demo, database_demo, cache_demo, messaging_demo, redis_cluster
from app.config import settings

# Configure structured JSON logging
logHandler = logging.StreamHandler(sys.stdout)
formatter = jsonlogger.JsonFormatter(
    '%(asctime)s %(name)s %(levelname)s %(message)s %(request_id)s %(method)s %(path)s %(status_code)s %(duration_ms)s'
)
logHandler.setFormatter(formatter)
logger = logging.getLogger(__name__)
logger.addHandler(logHandler)
logger.setLevel(logging.INFO)

# Disable default basicConfig
logging.getLogger().handlers.clear()
logging.getLogger().addHandler(logHandler)

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

# Create FastAPI application
app = FastAPI(
    title="Colima Services - Reference API",
    description="Reference implementation showing infrastructure integration patterns",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)


@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    """Middleware to collect metrics and add request tracking"""
    # Generate request ID for correlation
    request_id = str(uuid.uuid4())
    request.state.request_id = request_id

    # Extract endpoint path template (e.g., /users/{id} instead of /users/123)
    endpoint = request.url.path
    method = request.method

    # Track in-progress requests
    http_requests_in_progress.labels(method=method, endpoint=endpoint).inc()

    # Time the request
    start_time = time.time()

    try:
        # Process request
        response = await call_next(request)

        # Calculate duration
        duration = time.time() - start_time

        # Record metrics
        http_requests_total.labels(
            method=method,
            endpoint=endpoint,
            status=response.status_code
        ).inc()

        http_request_duration_seconds.labels(
            method=method,
            endpoint=endpoint
        ).observe(duration)

        # Log request with structured data
        logger.info(
            "HTTP request completed",
            extra={
                "request_id": request_id,
                "method": method,
                "path": endpoint,
                "status_code": response.status_code,
                "duration_ms": round(duration * 1000, 2)
            }
        )

        # Add request ID to response headers
        response.headers["X-Request-ID"] = request_id

        return response

    except Exception as e:
        # Record error metrics
        duration = time.time() - start_time
        http_requests_total.labels(
            method=method,
            endpoint=endpoint,
            status=500
        ).inc()

        # Log error with structured data
        logger.error(
            f"Request failed: {str(e)}",
            extra={
                "request_id": request_id,
                "method": method,
                "path": endpoint,
                "status_code": 500,
                "duration_ms": round(duration * 1000, 2)
            },
            exc_info=True
        )
        raise

    finally:
        # Decrement in-progress counter
        http_requests_in_progress.labels(method=method, endpoint=endpoint).dec()


# Include routers
app.include_router(health.router, prefix="/health", tags=["Health Checks"])
app.include_router(redis_cluster.router, prefix="/redis", tags=["Redis Cluster"])
app.include_router(vault_demo.router, prefix="/examples/vault", tags=["Vault Examples"])
app.include_router(database_demo.router, prefix="/examples/database", tags=["Database Examples"])
app.include_router(cache_demo.router, prefix="/examples/cache", tags=["Cache Examples"])
app.include_router(messaging_demo.router, prefix="/examples/messaging", tags=["Messaging Examples"])


@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "name": "Colima Services Reference API",
        "version": "1.0.0",
        "description": "Reference implementation for infrastructure integration",
        "docs": "/docs",
        "health": "/health/all",
        "metrics": "/metrics",
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
            "messaging": "/examples/messaging",
        },
        "note": "This is a reference implementation, not production code"
    }


@app.on_event("startup")
async def startup_event():
    """Initialize services on startup"""
    # Set application info metric
    app_info.labels(version="1.0.0", name="colima-reference-api").set(1)

    logger.info(
        "Starting Colima Services Reference API",
        extra={
            "vault_address": settings.VAULT_ADDR,
            "version": "1.0.0"
        }
    )
    logger.info("Application ready")


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    logger.info("Shutting down Colima Services Reference API")


@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """Global exception handler for better error responses"""
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal server error",
            "detail": str(exc) if settings.DEBUG else "An error occurred"
        }
    )
