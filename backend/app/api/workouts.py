"""Workout tracking endpoints."""

import logging

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from datetime import datetime, date, timedelta
from uuid import UUID
from enum import Enum

from app.auth import get_current_user, CurrentUser
from app.database import get_supabase_client

logger = logging.getLogger(__name__)

router = APIRouter()


class WorkoutType(str, Enum):
    """Types of workouts (must match database enum)."""
    RUNNING = "running"
    CYCLING = "cycling"
    SWIMMING = "swimming"
    WALKING = "walking"
    HIKING = "hiking"
    ROWING = "rowing"
    WEIGHT_TRAINING = "weight_training"
    BODYWEIGHT = "bodyweight"
    CROSSFIT = "crossfit"
    YOGA = "yoga"
    PILATES = "pilates"
    STRETCHING = "stretching"
    HIIT = "hiit"
    # Sports
    SOCCER = "soccer"
    BASKETBALL = "basketball"
    TENNIS = "tennis"
    MARTIAL_ARTS = "martial_arts"
    DANCING = "dancing"
    BADMINTON = "badminton"
    VOLLEYBALL = "volleyball"
    OTHER = "other"


# MET (Metabolic Equivalent of Task) values per workout type
_MET_VALUES: dict[str, float] = {
    "running": 9.8,
    "cycling": 7.5,
    "swimming": 6.0,
    "walking": 3.5,
    "hiking": 6.0,
    "rowing": 7.0,
    "weight_training": 5.0,
    "bodyweight": 5.0,
    "crossfit": 8.0,
    "yoga": 2.5,
    "pilates": 3.0,
    "stretching": 2.0,
    "hiit": 8.0,
    "soccer": 7.0,
    "basketball": 6.5,
    "tennis": 7.3,
    "martial_arts": 10.3,
    "dancing": 5.0,
    "badminton": 5.5,
    "volleyball": 4.0,
    "other": 5.0,
}

_INTENSITY_MET_FALLBACK: dict[str, float] = {
    "light": 3.0,
    "moderate": 5.0,
    "hard": 7.0,
    "very_hard": 9.0,
}


class IntensityLevel(str, Enum):
    """Workout intensity levels."""
    LIGHT = "light"
    MODERATE = "moderate"
    HARD = "hard"
    VERY_HARD = "very_hard"


# Request/Response Models
class WorkoutCreate(BaseModel):
    """Create a new workout."""
    workout_type: WorkoutType
    started_at: datetime = Field(alias="start_time")  # Accept both start_time and started_at
    duration_minutes: int = Field(gt=0)
    intensity: IntensityLevel = IntensityLevel.MODERATE
    calories_burned: int | None = None
    distance_km: float | None = None
    avg_heart_rate: int | None = None
    max_heart_rate: int | None = None
    notes: str | None = None
    exercises: list[dict] | None = None  # For strength workouts
    # Training plan fields
    plan_id: UUID | None = None
    planned_workout_name: str | None = None
    overall_rating: int | None = Field(default=None, ge=1, le=5)

    model_config = {"populate_by_name": True, "extra": "ignore"}


class WorkoutResponse(BaseModel):
    """Workout response."""
    id: UUID
    user_id: UUID
    workout_type: str
    start_time: datetime  # Database column name
    duration_minutes: int
    intensity: str | None
    calories_burned: int | None
    distance_km: float | None
    avg_heart_rate: int | None
    max_heart_rate: int | None
    training_load: float | None
    notes: str | None
    exercises: list[dict] | None
    # Training plan fields
    plan_id: UUID | None = None
    planned_workout_name: str | None = None
    overall_rating: int | None = None
    created_at: datetime


class WeeklyWorkoutSummary(BaseModel):
    """Weekly workout summary."""
    week_start: date
    total_workouts: int
    total_duration_minutes: int
    total_calories: int
    workouts_by_type: dict[str, int]
    avg_intensity: float
    training_load_total: float


def calculate_training_load(
    duration_minutes: int,
    intensity: str,
    avg_heart_rate: int | None,
) -> float:
    """Calculate training load based on duration and intensity."""
    intensity_multiplier = {
        "light": 1.0,
        "moderate": 1.5,
        "hard": 2.0,
        "very_hard": 2.5,
    }
    multiplier = intensity_multiplier.get(intensity, 1.5)

    # Base calculation: duration * intensity
    load = duration_minutes * multiplier

    # Adjust for heart rate if available
    if avg_heart_rate:
        hr_factor = avg_heart_rate / 140  # Normalize around typical workout HR
        load *= hr_factor

    return round(load, 1)


# Unified Workout Entry (for merged history feed)
class UnifiedWorkoutEntry(BaseModel):
    """A workout from any source (freeform or plan session)."""
    id: UUID
    source: str  # "freeform" or "plan"
    workout_type: str
    start_time: datetime
    duration_minutes: int | None
    calories_burned: int | None = None
    notes: str | None = None
    # Plan-specific fields
    plan_id: UUID | None = None
    planned_workout_name: str | None = None
    overall_rating: int | None = None
    intensity: str | None = None


# Endpoints

@router.get("/unified", response_model=list[UnifiedWorkoutEntry])
async def get_unified_workouts(
    current_user: CurrentUser = Depends(get_current_user),
    days: int = Query(default=30, le=365),
    limit: int = Query(default=20, le=100),
    offset: int = 0,
):
    """Get unified workout history from both freeform workouts and plan sessions."""
    supabase = get_supabase_client()
    from_date = (datetime.now() - timedelta(days=days)).isoformat()
    user_id = str(current_user.id)

    # Fetch freeform workouts (limit to what we'll need after merge)
    fetch_limit = limit + offset
    freeform_result = (
        supabase.table("workouts")
        .select("id, workout_type, start_time, duration_minutes, calories_burned, notes, intensity, plan_id, planned_workout_name, overall_rating")
        .eq("user_id", user_id)
        .gte("start_time", from_date)
        .order("start_time", desc=True)
        .limit(fetch_limit)
        .execute()
    )

    # Fetch plan sessions
    session_result = (
        supabase.table("workout_sessions")
        .select("id, started_at, duration_minutes, planned_workout_name, plan_id, overall_rating, notes")
        .eq("user_id", user_id)
        .gte("started_at", from_date)
        .order("started_at", desc=True)
        .limit(fetch_limit)
        .execute()
    )

    # Merge into unified format
    entries: list[dict] = []

    for w in (freeform_result.data or []):
        entries.append({
            "id": w["id"],
            "source": "freeform",
            "workout_type": w["workout_type"],
            "start_time": w["start_time"],
            "duration_minutes": w.get("duration_minutes"),
            "calories_burned": w.get("calories_burned"),
            "notes": w.get("notes"),
            "plan_id": w.get("plan_id"),
            "planned_workout_name": w.get("planned_workout_name"),
            "overall_rating": w.get("overall_rating"),
            "intensity": w.get("intensity"),
        })

    for s in (session_result.data or []):
        entries.append({
            "id": s["id"],
            "source": "plan",
            "workout_type": "strength",
            "start_time": s["started_at"],
            "duration_minutes": s.get("duration_minutes"),
            "calories_burned": None,
            "notes": s.get("notes"),
            "plan_id": s.get("plan_id"),
            "planned_workout_name": s.get("planned_workout_name"),
            "overall_rating": s.get("overall_rating"),
            "intensity": None,
        })

    # Sort by start_time descending, apply offset + limit
    entries.sort(key=lambda e: e["start_time"], reverse=True)
    entries = entries[offset:offset + limit]

    return entries


@router.post("", response_model=WorkoutResponse)
async def create_workout(
    workout: WorkoutCreate,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Log a new workout."""
    supabase = get_supabase_client()

    # Calculate training load
    training_load = calculate_training_load(
        workout.duration_minutes,
        workout.intensity.value,
        workout.avg_heart_rate,
    )

    logger.info(
        "Creating workout for user %s: type=%s duration=%dmin intensity=%s",
        current_user.id, workout.workout_type.value,
        workout.duration_minutes, workout.intensity.value,
    )
    # Auto-estimate calories via MET when not provided
    calories_burned = workout.calories_burned
    if calories_burned is None:
        met = _MET_VALUES.get(workout.workout_type.value,
                              _INTENSITY_MET_FALLBACK.get(workout.intensity.value, 5.0))
        weight_kg = 70.0  # default fallback
        try:
            profile = supabase.table("health_metrics").select("value") \
                .eq("user_id", str(current_user.id)) \
                .eq("metric_type", "weight") \
                .order("timestamp", desc=True) \
                .limit(1).execute()
            if profile.data:
                weight_kg = float(profile.data[0]["value"])
        except Exception:
            pass
        calories_burned = round(met * weight_kg * (workout.duration_minutes / 60.0))

    data = {
        "user_id": str(current_user.id),
        "workout_type": workout.workout_type.value,
        "start_time": workout.started_at.isoformat(),  # DB column is start_time
        "duration_minutes": workout.duration_minutes,
        "intensity": workout.intensity.value,
        "calories_burned": calories_burned,
        "distance_km": workout.distance_km,
        "avg_heart_rate": workout.avg_heart_rate,
        "max_heart_rate": workout.max_heart_rate,
        "training_load": training_load,
        "notes": workout.notes,
        "exercises": workout.exercises,
        # Training plan fields
        "plan_id": str(workout.plan_id) if workout.plan_id else None,
        "planned_workout_name": workout.planned_workout_name,
        "overall_rating": workout.overall_rating,
    }

    result = supabase.table("workouts").insert(data).execute()

    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to create workout")

    return result.data[0]


@router.get("", response_model=list[WorkoutResponse])
async def get_workouts(
    current_user: CurrentUser = Depends(get_current_user),
    workout_type: WorkoutType | None = None,
    days: int | None = Query(default=None, le=365, description="Get workouts from the last N days"),
    start_date: date | None = None,
    end_date: date | None = None,
    limit: int = Query(default=50, le=200),
    offset: int = 0,
):
    """Get workouts with optional filters."""
    supabase = get_supabase_client()

    query = (
        supabase.table("workouts")
        .select("*")
        .eq("user_id", str(current_user.id))
        .order("start_time", desc=True)
        .limit(limit)
        .offset(offset)
    )

    if workout_type:
        query = query.eq("workout_type", workout_type.value)

    # If days parameter is provided, convert to date range
    if days is not None:
        start_date = date.today() - timedelta(days=days)
        end_date = date.today()

    if start_date:
        query = query.gte("start_time", f"{start_date}T00:00:00Z")

    if end_date:
        query = query.lte("start_time", f"{end_date}T23:59:59Z")

    result = query.execute()
    return result.data or []


@router.get("/weekly", response_model=list[WeeklyWorkoutSummary])
async def get_weekly_summaries(
    current_user: CurrentUser = Depends(get_current_user),
    weeks: int = Query(default=4, le=52),
):
    """Get weekly workout summaries."""
    supabase = get_supabase_client()

    # Get workouts for the past N weeks
    start_date = date.today() - timedelta(weeks=weeks)

    result = (
        supabase.table("workouts")
        .select("*")
        .eq("user_id", str(current_user.id))
        .gte("start_time", f"{start_date}T00:00:00Z")
        .order("start_time", desc=True)
        .execute()
    )

    workouts = result.data or []

    # Group by week and calculate summaries
    weekly_data: dict[date, list] = {}
    for w in workouts:
        workout_date = datetime.fromisoformat(w["start_time"].replace("Z", "+00:00")).date()
        # Get Monday of that week
        week_start = workout_date - timedelta(days=workout_date.weekday())
        if week_start not in weekly_data:
            weekly_data[week_start] = []
        weekly_data[week_start].append(w)

    # Build summaries
    summaries = []
    for week_start, week_workouts in sorted(weekly_data.items(), reverse=True):
        workouts_by_type: dict[str, int] = {}
        total_duration = 0
        total_calories = 0
        total_load = 0.0
        intensity_values = []

        intensity_map = {"light": 1, "moderate": 2, "hard": 3, "very_hard": 4}

        for w in week_workouts:
            wtype = w["workout_type"]
            workouts_by_type[wtype] = workouts_by_type.get(wtype, 0) + 1
            total_duration += w["duration_minutes"]
            total_calories += w.get("calories_burned") or 0
            total_load += w.get("training_load") or 0
            intensity_values.append(intensity_map.get(w["intensity"], 2))

        avg_intensity = sum(intensity_values) / len(intensity_values) if intensity_values else 0

        summaries.append(
            WeeklyWorkoutSummary(
                week_start=week_start,
                total_workouts=len(week_workouts),
                total_duration_minutes=total_duration,
                total_calories=total_calories,
                workouts_by_type=workouts_by_type,
                avg_intensity=round(avg_intensity, 1),
                training_load_total=round(total_load, 1),
            )
        )

    return summaries


@router.get("/calendar")
async def get_workout_calendar(
    month: str = Query(description="Month in YYYY-MM format, e.g. 2026-03"),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get per-day workout summary for a calendar month."""
    try:
        year, mon = map(int, month.split("-"))
        first_day = date(year, mon, 1)
    except (ValueError, TypeError):
        raise HTTPException(status_code=422, detail="month must be in YYYY-MM format")

    if mon == 12:
        last_day = date(year + 1, 1, 1) - timedelta(days=1)
    else:
        last_day = date(year, mon + 1, 1) - timedelta(days=1)

    start_iso = f"{first_day}T00:00:00"
    end_iso = f"{last_day}T23:59:59"
    user_id = str(current_user.id)
    supabase = get_supabase_client()

    freeform_result = (
        supabase.table("workouts")
        .select("start_time, overall_rating")
        .eq("user_id", user_id)
        .gte("start_time", start_iso)
        .lte("start_time", end_iso)
        .execute()
    )

    session_result = (
        supabase.table("workout_sessions")
        .select("started_at, overall_rating")
        .eq("user_id", user_id)
        .gte("started_at", start_iso)
        .lte("started_at", end_iso)
        .execute()
    )

    pr_result = (
        supabase.table("personal_records")
        .select("achieved_at")
        .eq("user_id", user_id)
        .gte("achieved_at", start_iso)
        .lte("achieved_at", end_iso)
        .execute()
    )

    days: dict[str, dict] = {}

    def _day(d: str) -> dict:
        if d not in days:
            days[d] = {"date": d, "workout_count": 0, "has_pr": False, "best_rating": None}
        return days[d]

    for w in (freeform_result.data or []):
        entry = _day(w["start_time"][:10])
        entry["workout_count"] += 1
        r = w.get("overall_rating")
        if r and (entry["best_rating"] is None or r > entry["best_rating"]):
            entry["best_rating"] = r

    for s in (session_result.data or []):
        entry = _day(s["started_at"][:10])
        entry["workout_count"] += 1
        r = s.get("overall_rating")
        if r and (entry["best_rating"] is None or r > entry["best_rating"]):
            entry["best_rating"] = r

    for pr in (pr_result.data or []):
        _day(pr["achieved_at"][:10])["has_pr"] = True

    return sorted(days.values(), key=lambda x: x["date"])


@router.get("/{workout_id}", response_model=WorkoutResponse)
async def get_workout(
    workout_id: UUID,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get a specific workout."""
    supabase = get_supabase_client()

    result = (
        supabase.table("workouts")
        .select("*")
        .eq("id", str(workout_id))
        .eq("user_id", str(current_user.id))
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=404, detail="Workout not found")

    return result.data[0]


@router.put("/{workout_id}", response_model=WorkoutResponse)
async def update_workout(
    workout_id: UUID,
    workout: WorkoutCreate,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Update a workout."""
    supabase = get_supabase_client()

    # Recalculate training load
    training_load = calculate_training_load(
        workout.duration_minutes,
        workout.intensity.value,
        workout.avg_heart_rate,
    )

    data = {
        "workout_type": workout.workout_type.value,
        "start_time": workout.started_at.isoformat(),
        "duration_minutes": workout.duration_minutes,
        "intensity": workout.intensity.value,
        "calories_burned": workout.calories_burned,
        "distance_km": workout.distance_km,
        "avg_heart_rate": workout.avg_heart_rate,
        "max_heart_rate": workout.max_heart_rate,
        "training_load": training_load,
        "notes": workout.notes,
        "exercises": workout.exercises,
        # Training plan fields
        "plan_id": str(workout.plan_id) if workout.plan_id else None,
        "planned_workout_name": workout.planned_workout_name,
        "overall_rating": workout.overall_rating,
    }

    result = (
        supabase.table("workouts")
        .update(data)
        .eq("id", str(workout_id))
        .eq("user_id", str(current_user.id))
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=404, detail="Workout not found")

    return result.data[0]


@router.delete("/{workout_id}")
async def delete_workout(
    workout_id: UUID,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Delete a workout."""
    supabase = get_supabase_client()

    logger.info("Deleting workout %s for user %s", workout_id, current_user.id)
    result = (
        supabase.table("workouts")
        .delete()
        .eq("id", str(workout_id))
        .eq("user_id", str(current_user.id))
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=404, detail="Workout not found")

    return {"message": "Workout deleted successfully"}
