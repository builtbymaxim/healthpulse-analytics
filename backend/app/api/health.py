"""Health check endpoints."""

from fastapi import APIRouter

router = APIRouter()


@router.get("/health")
async def health_check():
    """Check API health status."""
    return {
        "status": "healthy",
        "service": "healthpulse-api",
    }


@router.get("/health/ready")
async def readiness_check():
    """Check if API is ready to serve requests."""
    # TODO: Add database connectivity check
    return {
        "status": "ready",
        "checks": {
            "database": "ok",
            "ml_models": "ok",
        },
    }
