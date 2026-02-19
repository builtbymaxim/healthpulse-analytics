"""Health check endpoints."""

import asyncio
import logging
import time

from fastapi import APIRouter

from app.database import get_supabase_client

logger = logging.getLogger(__name__)
router = APIRouter()

# Cache readiness result for 10s to avoid hammering the DB on every probe
_readiness_cache: dict = {"result": None, "timestamp": 0.0}
_CACHE_TTL = 10.0


@router.get("/health")
async def health_check():
    """Check API health status."""
    return {
        "status": "healthy",
        "service": "healthpulse-api",
    }


@router.get("/health/ready")
async def readiness_check():
    """Check if API is ready to serve requests (DB + external services)."""
    now = time.monotonic()
    cached = _readiness_cache["result"]
    if cached and (now - _readiness_cache["timestamp"]) < _CACHE_TTL:
        return cached

    # --- Database check (5s timeout) ---
    db_status = "ok"
    try:
        await asyncio.wait_for(
            asyncio.to_thread(
                lambda: get_supabase_client().table("profiles").select("id").limit(1).execute()
            ),
            timeout=5.0,
        )
    except asyncio.TimeoutError:
        db_status = "timeout"
        logger.warning("Readiness DB check timed out")
    except Exception as e:
        db_status = "error"
        logger.warning("Readiness DB check failed: %s", e)

    # --- External services check: JWKS endpoint reachability (3s timeout) ---
    ext_status = "ok"
    try:
        from app.auth import _get_jwks
        result = await asyncio.wait_for(asyncio.to_thread(_get_jwks), timeout=3.0)
        if not result.get("keys"):
            ext_status = "degraded"
    except asyncio.TimeoutError:
        ext_status = "timeout"
        logger.warning("Readiness JWKS check timed out")
    except Exception as e:
        ext_status = "degraded"
        logger.warning("Readiness JWKS check failed: %s", e)

    all_ok = db_status == "ok" and ext_status == "ok"
    result = {
        "status": "ready" if all_ok else "degraded",
        "checks": {
            "database": db_status,
            "external_services": ext_status,
        },
    }

    _readiness_cache["result"] = result
    _readiness_cache["timestamp"] = now
    return result
