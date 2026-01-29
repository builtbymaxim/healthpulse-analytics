"""Health metrics endpoints."""

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from datetime import datetime, date, timezone
from uuid import UUID
from enum import Enum

from app.auth import get_current_user, CurrentUser
from app.database import get_supabase_client

router = APIRouter()


class MetricType(str, Enum):
    """Types of health metrics that can be tracked."""
    # Activity
    STEPS = "steps"
    ACTIVE_CALORIES = "active_calories"
    DISTANCE = "distance"

    # Body
    WEIGHT = "weight"
    BODY_FAT = "body_fat"

    # Vitals
    HEART_RATE = "heart_rate"
    RESTING_HR = "resting_hr"
    HRV = "hrv"

    # Sleep
    SLEEP_DURATION = "sleep_duration"
    SLEEP_QUALITY = "sleep_quality"
    DEEP_SLEEP = "deep_sleep"
    REM_SLEEP = "rem_sleep"

    # Nutrition
    CALORIES_IN = "calories_in"
    PROTEIN = "protein"
    CARBS = "carbs"
    FAT = "fat"
    WATER = "water"

    # Subjective
    ENERGY_LEVEL = "energy_level"
    MOOD = "mood"
    STRESS = "stress"
    SORENESS = "soreness"


class MetricSource(str, Enum):
    """Source of the metric data."""
    MANUAL = "manual"
    APPLE_HEALTH = "apple_health"
    GARMIN = "garmin"
    FITBIT = "fitbit"
    WHOOP = "whoop"
    OURA = "oura"


# Request/Response Models
class MetricCreate(BaseModel):
    """Create a new metric entry."""
    metric_type: MetricType
    value: float
    unit: str | None = None
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    source: MetricSource = MetricSource.MANUAL
    notes: str | None = None


class MetricResponse(BaseModel):
    """Metric entry response."""
    id: UUID
    user_id: UUID
    metric_type: str
    value: float
    unit: str | None
    timestamp: datetime
    source: str
    notes: str | None
    created_at: datetime


class MetricsBatch(BaseModel):
    """Batch of metrics for bulk import."""
    metrics: list[MetricCreate]


class DailyMetricsSummary(BaseModel):
    """Daily summary of all metrics."""
    date: date
    steps: int | None = None
    active_calories: int | None = None
    sleep_duration: float | None = None
    sleep_quality: float | None = None
    resting_hr: int | None = None
    hrv: float | None = None
    weight: float | None = None
    energy_level: int | None = None
    mood: int | None = None
    stress: int | None = None
    wellness_score: float | None = None


# Endpoints
@router.post("/", response_model=MetricResponse)
async def create_metric(
    metric: MetricCreate,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Log a new health metric."""
    supabase = get_supabase_client()

    data = {
        "user_id": str(current_user.id),
        "metric_type": metric.metric_type.value,
        "value": metric.value,
        "unit": metric.unit,
        "timestamp": metric.timestamp.isoformat(),
        "source": metric.source.value,
        "notes": metric.notes,
    }

    result = supabase.table("health_metrics").insert(data).execute()

    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to create metric")

    return result.data[0]


@router.post("/batch", response_model=list[MetricResponse])
async def create_metrics_batch(
    batch: MetricsBatch,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Bulk import metrics (for HealthKit sync)."""
    supabase = get_supabase_client()

    data = [
        {
            "user_id": str(current_user.id),
            "metric_type": m.metric_type.value,
            "value": m.value,
            "unit": m.unit,
            "timestamp": m.timestamp.isoformat(),
            "source": m.source.value,
            "notes": m.notes,
        }
        for m in batch.metrics
    ]

    result = supabase.table("health_metrics").insert(data).execute()

    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to create metrics")

    return result.data


@router.get("/", response_model=list[MetricResponse])
async def get_metrics(
    current_user: CurrentUser = Depends(get_current_user),
    metric_type: MetricType | None = None,
    start_date: date | None = None,
    end_date: date | None = None,
    source: MetricSource | None = None,
    limit: int = Query(default=100, le=1000),
    offset: int = 0,
):
    """Get metrics with optional filters."""
    supabase = get_supabase_client()

    query = (
        supabase.table("health_metrics")
        .select("*")
        .eq("user_id", str(current_user.id))
        .order("timestamp", desc=True)
        .limit(limit)
        .offset(offset)
    )

    if metric_type:
        query = query.eq("metric_type", metric_type.value)

    if source:
        query = query.eq("source", source.value)

    if start_date:
        query = query.gte("timestamp", f"{start_date}T00:00:00Z")

    if end_date:
        query = query.lte("timestamp", f"{end_date}T23:59:59Z")

    result = query.execute()
    return result.data or []


@router.get("/daily", response_model=list[DailyMetricsSummary])
async def get_daily_summaries(
    current_user: CurrentUser = Depends(get_current_user),
    start_date: date | None = None,
    end_date: date | None = None,
):
    """Get daily metric summaries from daily_scores table."""
    supabase = get_supabase_client()

    query = (
        supabase.table("daily_scores")
        .select("*")
        .eq("user_id", str(current_user.id))
        .order("date", desc=True)
    )

    if start_date:
        query = query.gte("date", str(start_date))

    if end_date:
        query = query.lte("date", str(end_date))

    result = query.execute()

    # Map database fields to response model
    summaries = []
    for row in result.data or []:
        summaries.append(
            DailyMetricsSummary(
                date=row["date"],
                steps=row.get("total_steps"),
                active_calories=row.get("total_active_calories"),
                sleep_duration=row.get("total_sleep_minutes", 0) / 60 if row.get("total_sleep_minutes") else None,
                sleep_quality=row.get("avg_sleep_quality"),
                resting_hr=row.get("avg_resting_hr"),
                hrv=row.get("avg_hrv"),
                energy_level=row.get("energy_level"),
                mood=row.get("mood"),
                stress=row.get("stress_level"),
                wellness_score=row.get("wellness_score"),
            )
        )

    return summaries


@router.get("/today", response_model=DailyMetricsSummary)
async def get_today_summary(
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get today's metric summary with wellness score."""
    supabase = get_supabase_client()
    today = date.today()

    result = (
        supabase.table("daily_scores")
        .select("*")
        .eq("user_id", str(current_user.id))
        .eq("date", str(today))
        .execute()
    )

    if result.data:
        row = result.data[0]
        return DailyMetricsSummary(
            date=row["date"],
            steps=row.get("total_steps"),
            active_calories=row.get("total_active_calories"),
            sleep_duration=row.get("total_sleep_minutes", 0) / 60 if row.get("total_sleep_minutes") else None,
            sleep_quality=row.get("avg_sleep_quality"),
            resting_hr=row.get("avg_resting_hr"),
            hrv=row.get("avg_hrv"),
            energy_level=row.get("energy_level"),
            mood=row.get("mood"),
            stress=row.get("stress_level"),
            wellness_score=row.get("wellness_score"),
        )

    # Return empty summary for today if no data
    return DailyMetricsSummary(date=today)


@router.delete("/{metric_id}")
async def delete_metric(
    metric_id: UUID,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Delete a metric entry."""
    supabase = get_supabase_client()

    # Delete only if owned by current user
    result = (
        supabase.table("health_metrics")
        .delete()
        .eq("id", str(metric_id))
        .eq("user_id", str(current_user.id))
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=404, detail="Metric not found")

    return {"message": "Metric deleted successfully"}
