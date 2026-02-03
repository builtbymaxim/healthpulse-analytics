"""Training plans API endpoints."""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from datetime import date
from uuid import UUID

from app.auth import get_current_user, CurrentUser
from app.database import get_supabase_client

router = APIRouter()


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
