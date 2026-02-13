"""Health check endpoints."""

from fastapi import APIRouter

from app.database import get_supabase_client

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
    db_status = "ok"
    try:
        supabase = get_supabase_client()
        supabase.table("profiles").select("id").limit(1).execute()
    except Exception:
        db_status = "error"

    status = "ready" if db_status == "ok" else "degraded"
    return {
        "status": status,
        "checks": {
            "database": db_status,
        },
    }
