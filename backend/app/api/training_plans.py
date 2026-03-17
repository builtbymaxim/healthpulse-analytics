"""Training plans API endpoints."""

import logging

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from datetime import date, datetime, timedelta
from uuid import UUID
from typing import Optional

from app.auth import get_current_user, CurrentUser
from app.database import get_supabase_client
from app.services.progression_service import get_suggestions

logger = logging.getLogger(__name__)

router = APIRouter()


# Request Models
class ActivatePlanRequest(BaseModel):
    """Request to activate a training plan."""
    template_id: UUID
    schedule: dict[str, str]  # day_of_week -> workout_name


class SuggestionsRequest(BaseModel):
    """Request weight suggestions for a list of exercises."""
    exercise_names: list[str]


class LogWorkoutSessionRequest(BaseModel):
    """Request to log a workout session."""
    plan_id: Optional[UUID] = None
    planned_workout_name: Optional[str] = None
    started_at: datetime
    completed_at: Optional[datetime] = None
    duration_minutes: Optional[int] = None
    exercises: list[dict]  # Array of exercise logs with sets
    overall_rating: Optional[int] = None
    notes: Optional[str] = None


class UpdatePlanRequest(BaseModel):
    """Request to update a training plan."""
    name: Optional[str] = None
    schedule: Optional[dict[str, str | None]] = None  # day_of_week -> workout_name or null
    customizations: Optional[dict] = None  # Exercise swaps, modifications


class CustomPlanExercise(BaseModel):
    """An exercise in a custom training plan day."""
    id: str                        # UUID from GET /exercises
    name: str
    sets: int = 3
    reps: Optional[str] = None     # "8-10", "5", "12"
    notes: Optional[str] = None


class CustomPlanDay(BaseModel):
    """A single training day in a custom plan."""
    day_of_week: int               # ISO: 1=Mon … 7=Sun
    workout_name: str
    focus: Optional[str] = None
    exercises: list[CustomPlanExercise]


class CreateCustomPlanRequest(BaseModel):
    """Request to create a custom training plan from scratch."""
    plan_name: str
    days: list[CustomPlanDay]


# Response Models
class TodayWorkoutResponse(BaseModel):
    """Today's planned workout."""
    has_plan: bool
    is_rest_day: bool
    is_completed: bool = False
    workout_name: str | None = None
    workout_focus: str | None = None
    exercises: list[dict] | None = None
    estimated_minutes: int | None = None
    day_of_week: int  # 1=Monday, 7=Sunday
    plan_name: str | None = None
    plan_id: UUID | None = None


class TrainingPlanSummary(BaseModel):
    """Summary of user's active training plan."""
    id: UUID
    name: str
    description: str | None
    days_per_week: int
    schedule: dict
    is_active: bool


# Endpoints
@router.get("/today", response_model=TodayWorkoutResponse)
async def get_todays_workout(
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get today's planned workout based on user's active training plan."""
    supabase = get_supabase_client()

    # Get day of week (1=Monday, 7=Sunday)
    today = date.today()
    day_of_week = today.isoweekday()

    # Fetch user's active training plan
    plan_result = (
        supabase.table("user_training_plans")
        .select("*, plan_templates(*)")
        .eq("user_id", str(current_user.id))
        .eq("is_active", True)
        .limit(1)
        .execute()
    )

    if not plan_result.data:
        # No active plan
        return TodayWorkoutResponse(
            has_plan=False,
            is_rest_day=True,
            day_of_week=day_of_week,
        )

    plan = plan_result.data[0]
    template = plan.get("plan_templates")
    schedule = plan.get("schedule", {})

    # Check if today is a workout day
    # Custom plans store dicts; template plans store workout name strings
    schedule_entry = schedule.get(str(day_of_week))
    if isinstance(schedule_entry, dict):
        # Custom plan — workout definition lives directly in schedule
        workout_name = schedule_entry.get("name")
        workout_details = schedule_entry
    else:
        workout_name = schedule_entry
        # Template plan — look up workout by name in template workouts list
        workout_details = None
        if template and template.get("workouts"):
            for workout in template["workouts"]:
                if workout.get("name") == workout_name:
                    workout_details = workout
                    break

    plan_id = plan.get("id")

    # Check if workout was already completed today
    tomorrow = today + timedelta(days=1)
    completion_result = (
        supabase.table("workout_sessions")
        .select("id")
        .eq("user_id", str(current_user.id))
        .gte("started_at", today.isoformat() + "T00:00:00")
        .lt("started_at", tomorrow.isoformat() + "T00:00:00")
        .limit(1)
        .execute()
    )
    is_completed = bool(completion_result.data)

    if not workout_name:
        # Rest day
        return TodayWorkoutResponse(
            has_plan=True,
            is_rest_day=True,
            is_completed=is_completed,
            day_of_week=day_of_week,
            plan_name=plan.get("name"),
            plan_id=plan_id,
        )

    return TodayWorkoutResponse(
        has_plan=True,
        is_rest_day=False,
        is_completed=is_completed,
        workout_name=workout_name,
        workout_focus=workout_details.get("focus") if workout_details else None,
        exercises=workout_details.get("exercises") if workout_details else None,
        estimated_minutes=workout_details.get("estimatedMinutes") if workout_details else 60,
        day_of_week=day_of_week,
        plan_name=plan.get("name"),
        plan_id=plan_id,
    )


@router.get("/active", response_model=TrainingPlanSummary | None)
async def get_active_plan(
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get user's active training plan."""
    supabase = get_supabase_client()

    result = (
        supabase.table("user_training_plans")
        .select("id, name, description, schedule, is_active, plan_templates(days_per_week)")
        .eq("user_id", str(current_user.id))
        .eq("is_active", True)
        .limit(1)
        .execute()
    )

    if not result.data:
        return None

    plan = result.data[0]
    template = plan.get("plan_templates") or {}

    # Normalize schedule: custom plans store dicts; extract the name string for the summary
    raw_schedule = plan.get("schedule", {})
    normalized_schedule = {
        k: v["name"] if isinstance(v, dict) else v
        for k, v in raw_schedule.items()
    }

    return TrainingPlanSummary(
        id=plan["id"],
        name=plan["name"],
        description=plan.get("description"),
        days_per_week=template.get("days_per_week", len(normalized_schedule)),
        schedule=normalized_schedule,
        is_active=plan.get("is_active", True),
    )


@router.get("/templates")
async def get_plan_templates(
    modality: str | None = None,
    days_per_week: int | None = None,
    difficulty: str | None = None,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get available plan templates, optionally filtered by difficulty/experience."""
    supabase = get_supabase_client()

    query = supabase.table("plan_templates").select("*")

    if modality:
        query = query.eq("modality", modality)
    if days_per_week:
        query = query.eq("days_per_week", days_per_week)

    # If no explicit difficulty filter, auto-filter by user's experience level
    if difficulty:
        query = query.eq("difficulty", difficulty)
    else:
        profile = supabase.table("profiles").select("settings").eq("id", str(current_user.id)).maybe_single().execute()
        exp_level = (profile.data or {}).get("settings", {}).get("experience_level") if profile.data else None
        if exp_level:
            # Show templates at or below user's level
            level_map = {"beginner": ["beginner"], "intermediate": ["beginner", "intermediate"], "advanced": ["beginner", "intermediate", "advanced"]}
            allowed = level_map.get(exp_level, ["beginner", "intermediate", "advanced"])
            query = query.in_("difficulty", allowed)

    result = query.order("difficulty").order("name").execute()
    return result.data or []


@router.get("/templates/{template_id}")
async def get_template_details(
    template_id: UUID,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get full details of a specific plan template."""
    supabase = get_supabase_client()

    result = (
        supabase.table("plan_templates")
        .select("*")
        .eq("id", str(template_id))
        .limit(1)
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=404, detail="Template not found")

    return result.data[0]


@router.post("/activate")
async def activate_plan(
    request: ActivatePlanRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Activate a training plan from a template."""
    supabase = get_supabase_client()

    # Get the template
    template_result = (
        supabase.table("plan_templates")
        .select("*")
        .eq("id", str(request.template_id))
        .limit(1)
        .execute()
    )

    if not template_result.data:
        raise HTTPException(status_code=404, detail="Template not found")

    template = template_result.data[0]

    logger.info(
        "Activating training plan for user %s: template_id=%s name=%r",
        current_user.id, request.template_id, template.get("name"),
    )
    # Deactivate any existing active plans
    supabase.table("user_training_plans").update(
        {"is_active": False}
    ).eq("user_id", str(current_user.id)).eq("is_active", True).execute()

    # Create new active plan
    plan_data = {
        "user_id": str(current_user.id),
        "template_id": str(request.template_id),
        "name": template["name"],
        "description": template.get("description"),
        "goal_type": template.get("goal_type"),
        "schedule": request.schedule,
        "is_active": True,
    }

    result = supabase.table("user_training_plans").insert(plan_data).execute()

    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to activate plan")

    return {"success": True, "plan_id": result.data[0]["id"]}


@router.delete("/active")
async def deactivate_plan(
    current_user: CurrentUser = Depends(get_current_user),
):
    """Deactivate the current training plan."""
    supabase = get_supabase_client()

    logger.info("Deactivating training plan for user %s", current_user.id)
    supabase.table("user_training_plans").update(
        {"is_active": False}
    ).eq("user_id", str(current_user.id)).eq("is_active", True).execute()

    return {"success": True}


@router.post("/sessions")
async def log_workout_session(
    request: LogWorkoutSessionRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Log a completed workout session with exercises and sets."""
    supabase = get_supabase_client()

    session_data = {
        "user_id": str(current_user.id),
        "plan_id": str(request.plan_id) if request.plan_id else None,
        "planned_workout_name": request.planned_workout_name,
        "started_at": request.started_at.isoformat(),
        "completed_at": request.completed_at.isoformat() if request.completed_at else None,
        "duration_minutes": request.duration_minutes,
        "exercises": request.exercises,
        "overall_rating": request.overall_rating,
        "notes": request.notes,
    }

    logger.info(
        "Logging workout session for user %s: plan_id=%s workout=%r exercises=%d",
        current_user.id, request.plan_id, request.planned_workout_name,
        len(request.exercises),
    )
    result = supabase.table("workout_sessions").insert(session_data).execute()

    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to log workout session")

    session_id = result.data[0]["id"]

    # Check for PRs and update exercise progress
    prs_achieved = await _check_and_update_prs(
        supabase, current_user.id, request.exercises, session_id
    )

    return {
        "success": True,
        "session_id": session_id,
        "prs_achieved": prs_achieved,
    }


@router.get("/sessions")
async def get_workout_sessions(
    days: int = 30,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get recent workout sessions."""
    supabase = get_supabase_client()

    from_date = (datetime.now() - timedelta(days=days)).isoformat()

    result = (
        supabase.table("workout_sessions")
        .select("*")
        .eq("user_id", str(current_user.id))
        .gte("started_at", from_date)
        .order("started_at", desc=True)
        .execute()
    )

    return result.data or []


@router.post("/suggestions")
async def get_exercise_suggestions(
    request: SuggestionsRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get weight suggestions for exercises based on recent workout history."""
    supabase = get_supabase_client()
    suggestions = await get_suggestions(supabase, current_user.id, request.exercise_names)
    return suggestions


@router.post("/custom")
async def create_custom_plan(
    request: CreateCustomPlanRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Create a custom training plan built from scratch (no template)."""
    supabase = get_supabase_client()

    # Build schedule JSONB — richer dict format for custom plans
    schedule: dict = {}
    for day in request.days:
        estimated_minutes = max(30, len(day.exercises) * 8)  # ~8 min per exercise
        schedule[str(day.day_of_week)] = {
            "name": day.workout_name,
            "focus": day.focus,
            "exercises": [
                {
                    "id": ex.id,       # UUID — same shape as template plan exercises
                    "name": ex.name,
                    "sets": ex.sets,
                    "reps": ex.reps,
                    "notes": ex.notes,
                }
                for ex in day.exercises
            ],
            "estimatedMinutes": estimated_minutes,
        }

    logger.info(
        "Creating custom training plan for user %s: name=%r days=%s",
        current_user.id, request.plan_name, list(schedule.keys()),
    )

    # Deactivate any existing active plans
    supabase.table("user_training_plans").update(
        {"is_active": False}
    ).eq("user_id", str(current_user.id)).eq("is_active", True).execute()

    # Insert — template_id intentionally null
    result = supabase.table("user_training_plans").insert({
        "user_id": str(current_user.id),
        "template_id": None,
        "name": request.plan_name,
        "schedule": schedule,
        "is_active": True,
    }).execute()

    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to create custom plan")

    plan = result.data[0]
    return {
        "success": True,
        "plan_id": plan["id"],
        "name": plan["name"],
        "days_per_week": len(request.days),
    }


@router.put("/custom/{plan_id}")
async def update_custom_plan(
    plan_id: UUID,
    request: CreateCustomPlanRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Update an existing custom training plan in-place (preserves plan UUID and history)."""
    supabase = get_supabase_client()

    # Verify the plan belongs to this user
    existing = (
        supabase.table("user_training_plans")
        .select("id")
        .eq("id", str(plan_id))
        .eq("user_id", str(current_user.id))
        .maybe_single()
        .execute()
    )
    if not existing.data:
        raise HTTPException(status_code=404, detail="Plan not found")

    # Rebuild schedule JSONB in the same format as create_custom_plan
    schedule: dict = {}
    for day in request.days:
        estimated_minutes = max(30, len(day.exercises) * 8)
        schedule[str(day.day_of_week)] = {
            "name": day.workout_name,
            "focus": day.focus,
            "exercises": [
                {
                    "id": ex.id,
                    "name": ex.name,
                    "sets": ex.sets,
                    "reps": ex.reps,
                    "notes": ex.notes,
                }
                for ex in day.exercises
            ],
            "estimatedMinutes": estimated_minutes,
        }

    logger.info(
        "Updating custom training plan %s for user %s: name=%r days=%s",
        plan_id, current_user.id, request.plan_name, list(schedule.keys()),
    )

    try:
        supabase.table("user_training_plans") \
            .update({"name": request.plan_name, "schedule": schedule}) \
            .eq("id", str(plan_id)) \
            .execute()
    except Exception as e:
        logger.error("Failed to update custom plan %s: %s", plan_id, e)
        raise HTTPException(status_code=500, detail="Failed to update custom plan")

    return {
        "success": True,
        "plan_id": str(plan_id),
        "name": request.plan_name,
        "days_per_week": len(request.days),
    }


# NOTE: /{plan_id} routes MUST come after all specific routes (/sessions, /progress, etc.)
# to avoid catching path segments like "sessions" as a UUID parameter.

@router.put("/{plan_id}")
async def update_training_plan(
    plan_id: UUID,
    request: UpdatePlanRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Update a user's training plan (schedule, name, customizations)."""
    supabase = get_supabase_client()

    # Verify the plan belongs to the user
    existing = (
        supabase.table("user_training_plans")
        .select("id")
        .eq("id", str(plan_id))
        .eq("user_id", str(current_user.id))
        .limit(1)
        .execute()
    )

    if not existing.data:
        raise HTTPException(status_code=404, detail="Training plan not found")

    # Build update data
    update_data = {"updated_at": datetime.now().isoformat()}

    if request.name is not None:
        update_data["name"] = request.name

    if request.schedule is not None:
        update_data["schedule"] = request.schedule

    if request.customizations is not None:
        update_data["customizations"] = request.customizations

    # Perform update
    try:
        supabase.table("user_training_plans") \
            .update(update_data) \
            .eq("id", str(plan_id)) \
            .eq("user_id", str(current_user.id)) \
            .execute()
    except Exception as e:
        logger.error("Failed to update plan %s: %s", plan_id, e)
        raise HTTPException(status_code=500, detail="Failed to update plan")

    return {"success": True}


@router.get("/{plan_id}")
async def get_training_plan_details(
    plan_id: UUID,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get full details of a user's training plan including template workouts."""
    supabase = get_supabase_client()

    result = (
        supabase.table("user_training_plans")
        .select("*, plan_templates(*)")
        .eq("id", str(plan_id))
        .eq("user_id", str(current_user.id))
        .limit(1)
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=404, detail="Training plan not found")

    plan = result.data[0]
    template = plan.get("plan_templates") or {}

    # Merge template workouts with any customizations
    if template:
        workouts = template.get("workouts", [])
    else:
        # Custom plan: reconstruct ordered workouts list from schedule
        workouts = []
        for day_str, entry in plan.get("schedule", {}).items():
            if isinstance(entry, dict):
                workouts.append({
                    "day": int(day_str),
                    "name": entry.get("name"),
                    "focus": entry.get("focus"),
                    "exercises": entry.get("exercises", []),
                    "estimatedMinutes": entry.get("estimatedMinutes", 60),
                })
        workouts.sort(key=lambda w: w.get("day", 0))
    customizations = plan.get("customizations", {}) or {}

    # Normalise schedule to {day_str: workout_name} so both template and custom
    # plans decode as [String: String] on the iOS side.
    raw_schedule = plan.get("schedule", {}) or {}
    simple_schedule = {
        day: (entry["name"] if isinstance(entry, dict) else entry)
        for day, entry in raw_schedule.items()
    }

    # Apply any exercise customizations
    if customizations.get("exerciseSwaps"):
        swaps = customizations["exerciseSwaps"]
        for workout in workouts:
            for exercise in workout.get("exercises", []):
                orig_name = exercise.get("name", "")
                if orig_name in swaps:
                    exercise["name"] = swaps[orig_name]
                    exercise["swapped_from"] = orig_name

    return {
        "id": plan["id"],
        "name": plan["name"],
        "description": plan.get("description"),
        "schedule": simple_schedule,
        "workouts": workouts,
        "customizations": customizations,
        "is_active": plan.get("is_active", False),
        "template_name": template.get("name") if template else None,
        "days_per_week": template.get("days_per_week") if template else len(plan.get("schedule", {})),
    }


@router.get("/progress/{exercise_name}")
async def get_exercise_progress(
    exercise_name: str,
    days: int = 90,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get progress history for a specific exercise."""
    supabase = get_supabase_client()

    from_date = (datetime.now() - timedelta(days=days)).isoformat()

    # Get workout sessions and extract relevant exercise data
    result = (
        supabase.table("workout_sessions")
        .select("id, started_at, exercises")
        .eq("user_id", str(current_user.id))
        .gte("started_at", from_date)
        .order("started_at", desc=True)
        .execute()
    )

    progress_points = []
    for session in result.data or []:
        for exercise in session.get("exercises", []):
            if exercise.get("name", "").lower() == exercise_name.lower():
                sets = exercise.get("sets", [])
                if sets:
                    # Find best set
                    best_weight = max((s.get("weight", 0) for s in sets), default=0)
                    best_reps = max((s.get("reps", 0) for s in sets), default=0)
                    total_volume = sum(
                        s.get("weight", 0) * s.get("reps", 0) for s in sets
                    )
                    estimated_1rm = best_weight * (1 + best_reps / 30)  # Brzycki formula approx

                    progress_points.append({
                        "date": session["started_at"],
                        "best_weight": best_weight,
                        "best_reps": best_reps,
                        "total_volume": total_volume,
                        "estimated_1rm": round(estimated_1rm, 1),
                        "sets_completed": len(sets),
                    })
                break

    return {
        "exercise_name": exercise_name,
        "progress": progress_points,
    }


async def _check_and_update_prs(
    supabase, user_id: UUID, exercises: list[dict], session_id: str
) -> list[dict]:
    """Check for personal records and update the database."""
    prs_achieved = []

    # Batch-lookup exercise IDs by name from the exercises library
    exercise_names = [e.get("name", "") for e in exercises if e.get("name")]
    if not exercise_names:
        return prs_achieved

    name_to_id = {}
    lookup = (
        supabase.table("exercises")
        .select("id, name")
        .in_("name", exercise_names)
        .execute()
    )
    for row in lookup.data or []:
        name_to_id[row["name"]] = row["id"]

    for exercise in exercises:
        exercise_name = exercise.get("name", "")
        sets = exercise.get("sets", [])

        # Skip exercises not in the library (custom names without an exercise_id)
        exercise_id = name_to_id.get(exercise_name)
        if not exercise_id or not sets:
            continue

        # Find max weight at various rep ranges
        for set_data in sets:
            weight = set_data.get("weight", 0)
            reps = set_data.get("reps", 0)

            if weight <= 0 or reps <= 0:
                continue

            # Determine PR type based on reps
            if reps <= 1:
                pr_type = "1rm"
            elif reps <= 3:
                pr_type = "3rm"
            elif reps <= 5:
                pr_type = "5rm"
            else:
                pr_type = "max_volume"
                weight = weight * reps  # Use volume for higher reps

            # Check if this is a PR
            existing_pr = (
                supabase.table("personal_records")
                .select("*")
                .eq("user_id", str(user_id))
                .eq("exercise_id", str(exercise_id))
                .eq("record_type", pr_type)
                .limit(1)
                .execute()
            )

            is_new_pr = False
            previous_value = None

            if not existing_pr.data:
                # First time doing this exercise
                is_new_pr = True
            elif weight > existing_pr.data[0].get("value", 0):
                is_new_pr = True
                previous_value = existing_pr.data[0].get("value")

            if is_new_pr:
                # Upsert PR
                pr_data = {
                    "user_id": str(user_id),
                    "exercise_id": str(exercise_id),
                    "record_type": pr_type,
                    "value": weight,
                    "previous_value": previous_value,
                    "achieved_at": datetime.now().isoformat(),
                }

                # Atomic upsert on unique constraint
                supabase.table("personal_records").upsert(
                    pr_data,
                    on_conflict="user_id,exercise_id,record_type"
                ).execute()

                prs_achieved.append({
                    "exercise_name": exercise_name,
                    "record_type": pr_type,
                    "value": weight,
                    "previous_value": previous_value,
                })

    return prs_achieved
