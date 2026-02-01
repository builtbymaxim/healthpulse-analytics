"""Exercise library and strength tracking endpoints."""

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from datetime import datetime
from uuid import UUID

from app.auth import get_current_user, CurrentUser
from app.services.exercise_service import get_exercise_service
from app.models.exercises import (
    Exercise,
    ExerciseCategory,
    EquipmentType,
    WorkoutSet,
    WorkoutSetCreate,
    PersonalRecord,
    PRType,
    ExerciseHistory,
    VolumeAnalytics,
    FrequencyAnalytics,
    MuscleGroupStats,
)

router = APIRouter()


# ============================================
# Request/Response Models
# ============================================


class WorkoutSetsRequest(BaseModel):
    """Request to log multiple sets."""
    workout_id: UUID | None = None
    sets: list[WorkoutSetCreate]


class SetCreateRequest(BaseModel):
    """Create a single set."""
    exercise_id: UUID
    set_number: int = Field(gt=0)
    weight_kg: float = Field(ge=0)
    reps: int = Field(gt=0)
    rpe: float | None = Field(default=None, ge=1, le=10)
    is_warmup: bool = False
    notes: str | None = None
    performed_at: datetime | None = None


class PRResponse(BaseModel):
    """Personal record response."""
    id: UUID
    exercise_id: UUID
    exercise_name: str | None
    record_type: str
    value: float
    previous_value: float | None
    achieved_at: datetime
    improvement_pct: float | None = None


# ============================================
# Exercise Library Endpoints
# ============================================


@router.get("/", response_model=list[Exercise])
async def get_exercises(
    category: ExerciseCategory | None = None,
    equipment: EquipmentType | None = None,
    search: str | None = Query(default=None, max_length=100),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get exercises from the library with optional filters."""
    service = get_exercise_service()
    exercises = await service.get_exercises(
        category=category,
        equipment=equipment.value if equipment else None,
        search=search,
    )
    return exercises


@router.get("/{exercise_id}", response_model=Exercise)
async def get_exercise(
    exercise_id: UUID,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get a specific exercise by ID."""
    service = get_exercise_service()
    exercise = await service.get_exercise(exercise_id)
    if not exercise:
        raise HTTPException(status_code=404, detail="Exercise not found")
    return exercise


@router.get("/{exercise_id}/history", response_model=ExerciseHistory)
async def get_exercise_history(
    exercise_id: UUID,
    days: int = Query(default=90, le=365),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get user's history for a specific exercise."""
    service = get_exercise_service()
    history = await service.get_exercise_history(
        user_id=current_user.id,
        exercise_id=exercise_id,
        days=days,
    )
    return history


# ============================================
# Workout Sets Endpoints
# ============================================


@router.post("/sets", response_model=list[WorkoutSet])
async def log_sets(
    request: WorkoutSetsRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Log multiple workout sets at once."""
    if not request.sets:
        raise HTTPException(status_code=400, detail="No sets provided")

    service = get_exercise_service()
    created_sets = await service.log_sets(
        user_id=current_user.id,
        workout_id=request.workout_id,
        sets=request.sets,
    )
    return created_sets


@router.post("/workouts/{workout_id}/sets", response_model=list[WorkoutSet])
async def log_workout_sets(
    workout_id: UUID,
    sets: list[SetCreateRequest],
    current_user: CurrentUser = Depends(get_current_user),
):
    """Log sets for a specific workout."""
    if not sets:
        raise HTTPException(status_code=400, detail="No sets provided")

    service = get_exercise_service()
    set_creates = [
        WorkoutSetCreate(
            exercise_id=s.exercise_id,
            set_number=s.set_number,
            weight_kg=s.weight_kg,
            reps=s.reps,
            rpe=s.rpe,
            is_warmup=s.is_warmup,
            notes=s.notes,
            performed_at=s.performed_at,
        )
        for s in sets
    ]
    created_sets = await service.log_sets(
        user_id=current_user.id,
        workout_id=workout_id,
        sets=set_creates,
    )
    return created_sets


@router.get("/workouts/{workout_id}/sets", response_model=list[WorkoutSet])
async def get_workout_sets(
    workout_id: UUID,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get all sets for a workout."""
    service = get_exercise_service()
    sets = await service.get_workout_sets(
        user_id=current_user.id,
        workout_id=workout_id,
    )
    return sets


# ============================================
# Personal Records Endpoints
# ============================================


@router.get("/personal-records", response_model=list[PRResponse])
async def get_personal_records(
    exercise_id: UUID | None = None,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get user's personal records."""
    service = get_exercise_service()
    records = await service.get_personal_records(
        user_id=current_user.id,
        exercise_id=exercise_id,
    )

    # Convert to response with improvement percentage
    response = []
    for r in records:
        improvement = None
        if r.previous_value and r.previous_value > 0:
            improvement = round((r.value - r.previous_value) / r.previous_value * 100, 1)

        response.append(PRResponse(
            id=r.id,
            exercise_id=r.exercise_id,
            exercise_name=r.exercise_name,
            record_type=r.record_type.value if isinstance(r.record_type, PRType) else r.record_type,
            value=r.value,
            previous_value=r.previous_value,
            achieved_at=r.achieved_at,
            improvement_pct=improvement,
        ))

    return response


@router.get("/personal-records/{exercise_id}", response_model=list[PRResponse])
async def get_exercise_prs(
    exercise_id: UUID,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get personal records for a specific exercise."""
    return await get_personal_records(exercise_id=exercise_id, current_user=current_user)


# ============================================
# Analytics Endpoints
# ============================================


@router.get("/analytics/volume", response_model=VolumeAnalytics)
async def get_volume_analytics(
    period: str = Query(default="week", pattern="^(week|month)$"),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get volume analytics for the specified period."""
    service = get_exercise_service()
    analytics = await service.get_volume_analytics(
        user_id=current_user.id,
        period=period,
    )
    return analytics


@router.get("/analytics/frequency", response_model=FrequencyAnalytics)
async def get_frequency_analytics(
    period: str = Query(default="week", pattern="^(week|month)$"),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get training frequency analytics."""
    service = get_exercise_service()
    analytics = await service.get_frequency_analytics(
        user_id=current_user.id,
        period=period,
    )
    return analytics


@router.get("/analytics/muscle-groups", response_model=list[MuscleGroupStats])
async def get_muscle_group_stats(
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get stats for each muscle group over the last 7 days."""
    service = get_exercise_service()
    stats = await service.get_muscle_group_stats(user_id=current_user.id)
    return stats
