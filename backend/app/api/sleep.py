"""Sleep tracking and analysis endpoints."""

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field
from datetime import date

from app.auth import get_current_user, CurrentUser
from app.services.sleep_service import (
    get_sleep_service,
    SleepSummary,
    SleepEntry,
    SleepAnalytics,
)

router = APIRouter()


# Request Models
class SleepLogRequest(BaseModel):
    """Request to log sleep data."""
    duration_hours: float = Field(gt=0, le=24)
    quality: float | None = Field(default=None, ge=0, le=100)
    deep_sleep_hours: float | None = Field(default=None, ge=0)
    rem_sleep_hours: float | None = Field(default=None, ge=0)
    logged_for: date | None = None


# Endpoints
@router.get("/summary", response_model=SleepSummary | None)
async def get_sleep_summary(
    target_date: date | None = None,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get sleep summary for a specific date (defaults to today). Returns null if no sleep data exists."""
    service = get_sleep_service()
    return await service.get_sleep_summary(
        user_id=current_user.id,
        target_date=target_date,
    )


@router.get("/history", response_model=list[SleepEntry])
async def get_sleep_history(
    days: int = Query(default=7, le=90),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get sleep history for the past N days."""
    service = get_sleep_service()
    return await service.get_sleep_history(
        user_id=current_user.id,
        days=days,
    )


@router.get("/analytics", response_model=SleepAnalytics)
async def get_sleep_analytics(
    days: int = Query(default=30, le=365),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get comprehensive sleep analytics."""
    service = get_sleep_service()
    return await service.get_sleep_analytics(
        user_id=current_user.id,
        days=days,
    )


@router.post("/log")
async def log_sleep(
    request: SleepLogRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Log sleep data manually."""
    service = get_sleep_service()
    return await service.log_sleep(
        user_id=current_user.id,
        duration_hours=request.duration_hours,
        quality=request.quality,
        deep_sleep_hours=request.deep_sleep_hours,
        rem_sleep_hours=request.rem_sleep_hours,
        logged_for=request.logged_for,
    )
