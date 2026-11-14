
import logging
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from prometheus_client import (
    Counter,
    Histogram,
    generate_latest,
    CONTENT_TYPE_LATEST,
)
from starlette.responses import Response

from app.config import settings
from app.logging_config import setup_logging


# Configure structured JSON logging
setup_logging(settings.LOG_LEVEL)

logger = logging.getLogger("cloud-native-service")


# Prometheus Metrics
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total number of HTTP requests",
    ["method", "path", "status_code"],
)

ERROR_COUNT = Counter(
    "http_errors_total",
    "Total number of HTTP errors",
    ["method", "path", "status_code"],
)

REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method", "path"],
)


# Application lifecycle
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info(
        "Application started",
        extra={"environment": settings.ENVIRONMENT},
    )

    yield

    logger.info(
        "Application shutting down gracefully",
        extra={"environment": settings.ENVIRONMENT},
    )


# Initialize FastAPI
app = FastAPI(
    title="Cloud Native Service",
    description="Production-ready DevOps assessment web service",
    version=settings.APP_VERSION,
    lifespan=lifespan,
)


# Request monitoring middleware
@app.middleware("http")
async def monitor_requests(request: Request, call_next):

    start_time = time.perf_counter()

    try:
        response = await call_next(request)
        status_code = response.status_code

    except Exception:
        status_code = 500

        logger.exception(
            "Unhandled application exception",
            extra={
                "method": request.method,
                "path": request.url.path,
                "environment": settings.ENVIRONMENT,
            },
        )

        raise

    duration = time.perf_counter() - start_time

    # Exclude metrics endpoint to avoid self-monitoring noise
    if request.url.path != "/metrics":

        route = request.scope.get("route")
        path = getattr(route, "path", "unmatched")

        REQUEST_COUNT.labels(
            method=request.method,
            path=path,
            status_code=str(status_code),
        ).inc()

        REQUEST_LATENCY.labels(
            method=request.method,
            path=path,
        ).observe(duration)

        if status_code >= 400:
            ERROR_COUNT.labels(
                method=request.method,
                path=path,
                status_code=str(status_code),
            ).inc()

        logger.info(
            "HTTP request completed",
            extra={
                "method": request.method,
                "path": path,
                "status_code": status_code,
                "duration_ms": round(duration * 1000, 2),
                "environment": settings.ENVIRONMENT,
            },
        )

    return response


# Endpoint 1: Application information
@app.get("/")
async def root():

    return {
        "message": "Hello from DevOps Task!",
        "status": "running",
        "version": settings.APP_VERSION,
    }


# Endpoint 2: Health check
@app.get("/health")
async def health_check():

    return {
        "status": "healthy",
        "environment": settings.ENVIRONMENT,
    }


# Endpoint 3: Prometheus metrics
@app.get("/metrics")
async def metrics():

    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST,
    )
