"""Workout tracking endpoints."""

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from datetime import datetime, date, timedelta
from uuid import UUID
from enum import Enum

from app.auth import get_current_user, CurrentUser
from app.database import get_supabase_client

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
    OTHER = "other"


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


# Endpoints
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

    data = {
        "user_id": str(current_user.id),
        "workout_type": workout.workout_type.value,
        "start_time": workout.started_at.isoformat(),  # DB column is start_time
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
