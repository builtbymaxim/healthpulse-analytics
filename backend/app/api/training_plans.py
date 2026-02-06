"""Training plans API endpoints."""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from datetime import date, datetime, timedelta
from uuid import UUID
from typing import Optional

from app.auth import get_current_user, CurrentUser
from app.database import get_supabase_client

router = APIRouter()


# Request Models
class ActivatePlanRequest(BaseModel):
    """Request to activate a training plan."""
    template_id: UUID
    schedule: dict[str, str]  # day_of_week -> workout_name


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


# Response Models
class TodayWorkoutResponse(BaseModel):
    """Today's planned workout."""
    has_plan: bool
    is_rest_day: bool
    workout_name: str | None = None
    workout_focus: str | None = None
    exercises: list[dict] | None = None
    estimated_minutes: int | None = None
    day_of_week: int  # 1=Monday, 7=Sunday
    plan_name: str | None = None


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
    workout_name = schedule.get(str(day_of_week))

    if not workout_name:
        # Rest day
        return TodayWorkoutResponse(
            has_plan=True,
            is_rest_day=True,
            day_of_week=day_of_week,
            plan_name=plan.get("name"),
        )

    # Find the workout details from the template
    workout_details = None
    if template and template.get("workouts"):
        for workout in template["workouts"]:
            if workout.get("name") == workout_name:
                workout_details = workout
                break

    return TodayWorkoutResponse(
        has_plan=True,
        is_rest_day=False,
        workout_name=workout_name,
        workout_focus=workout_details.get("focus") if workout_details else None,
        exercises=workout_details.get("exercises") if workout_details else None,
        estimated_minutes=workout_details.get("estimatedMinutes") if workout_details else 60,
        day_of_week=day_of_week,
        plan_name=plan.get("name"),
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
    template = plan.get("plan_templates", {})

    return TrainingPlanSummary(
        id=plan["id"],
        name=plan["name"],
        description=plan.get("description"),
        days_per_week=template.get("days_per_week", len(plan.get("schedule", {}))),
        schedule=plan.get("schedule", {}),
        is_active=plan.get("is_active", True),
    )


@router.get("/templates")
async def get_plan_templates(
    modality: str | None = None,
    days_per_week: int | None = None,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get available plan templates."""
    supabase = get_supabase_client()

    query = supabase.table("plan_templates").select("*")

    if modality:
        query = query.eq("modality", modality)
    if days_per_week:
        query = query.eq("days_per_week", days_per_week)

    result = query.execute()
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
    result = (
        supabase.table("user_training_plans")
        .update(update_data)
        .eq("id", str(plan_id))
        .eq("user_id", str(current_user.id))
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to update plan")

    return {"success": True, "plan": result.data[0]}


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
    template = plan.get("plan_templates", {})

    # Merge template workouts with any customizations
    workouts = template.get("workouts", []) if template else []
    customizations = plan.get("customizations", {}) or {}

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
        "schedule": plan.get("schedule", {}),
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

    for exercise in exercises:
        exercise_name = exercise.get("name", "")
        sets = exercise.get("sets", [])

        if not sets:
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
                .eq("exercise_name", exercise_name)
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
                    "exercise_name": exercise_name,
                    "record_type": pr_type,
                    "value": weight,
                    "previous_value": previous_value,
                    "achieved_at": datetime.now().isoformat(),
                    "workout_session_id": session_id,
                }

                # Delete existing if any, then insert new
                supabase.table("personal_records").delete().eq(
                    "user_id", str(user_id)
                ).eq("exercise_name", exercise_name).eq("record_type", pr_type).execute()

                supabase.table("personal_records").insert(pr_data).execute()

                prs_achieved.append({
                    "exercise_name": exercise_name,
                    "record_type": pr_type,
                    "value": weight,
                    "previous_value": previous_value,
                })

    return prs_achieved
