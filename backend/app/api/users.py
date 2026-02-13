"""User management endpoints."""

import logging
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from datetime import datetime, timezone
from uuid import UUID

from app.auth import get_current_user, CurrentUser
from app.database import get_supabase_client
from app.services.nutrition_calculator import get_nutrition_calculator

logger = logging.getLogger(__name__)

router = APIRouter()


# Request/Response Models
class UserProfile(BaseModel):
    """User profile response."""
    id: UUID
    email: str
    display_name: str | None = None
    avatar_url: str | None = None
    age: int | None = None
    height_cm: float | None = None
    gender: str | None = None
    activity_level: str | None = None
    fitness_goal: str | None = None
    created_at: datetime
    settings: dict | None = None


class OnboardingProfile(BaseModel):
    """Onboarding profile data from iOS app."""
    display_name: str | None = None
    age: int
    height_cm: float
    gender: str
    weight_kg: float
    fitness_goal: str
    activity_level: str
    target_weight_kg: float | None = None
    target_sleep_hours: float | None = None
    # Training preferences
    training_modality: str | None = None
    equipment: list[str] | None = None
    days_per_week: int | None = None
    preferred_days: list[int] | None = None
    # Social
    social_opt_in: bool | None = None


class UserSettings(BaseModel):
    """User settings update request."""
    display_name: str | None = None
    units: str = "metric"  # metric or imperial
    timezone: str = "UTC"
    notifications_enabled: bool = True
    daily_goals: dict | None = None
    # Baseline settings
    hrv_baseline: float | None = None
    rhr_baseline: float | None = None
    target_sleep_hours: float | None = None
    daily_step_goal: int | None = None
    # Social
    social_opt_in: bool | None = None


class UserProfileUpdate(BaseModel):
    """User profile update request."""
    display_name: str | None = None
    age: int | None = None
    height_cm: float | None = None
    gender: str | None = None
    activity_level: str | None = None
    fitness_goal: str | None = None


# Endpoints
@router.get("/me", response_model=UserProfile)
async def get_my_profile(
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get current authenticated user's profile."""
    supabase = get_supabase_client()

    result = (
        supabase.table("profiles")
        .select("*")
        .eq("id", str(current_user.id))
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=404, detail="Profile not found")

    return result.data[0]


@router.put("/me", response_model=UserProfile)
async def update_my_profile(
    profile: UserProfileUpdate,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Update current authenticated user's profile."""
    logger.debug("PUT /users/me received: %s", profile.model_dump())

    supabase = get_supabase_client()

    # Build update data from non-None fields
    update_data = {}
    if profile.display_name is not None:
        update_data["display_name"] = profile.display_name
    if profile.age is not None:
        update_data["age"] = profile.age
    if profile.height_cm is not None:
        update_data["height_cm"] = profile.height_cm
    if profile.gender is not None:
        update_data["gender"] = profile.gender
    if profile.activity_level is not None:
        update_data["activity_level"] = profile.activity_level
    if profile.fitness_goal is not None:
        update_data["fitness_goal"] = profile.fitness_goal

    logger.debug("Fields to update: %s", update_data)

    if not update_data:
        # Nothing to update, just return current profile
        logger.debug("No fields to update")
        result = (
            supabase.table("profiles")
            .select("*")
            .eq("id", str(current_user.id))
            .execute()
        )
        if not result.data:
            raise HTTPException(status_code=404, detail="Profile not found")
        return result.data[0]

    result = (
        supabase.table("profiles")
        .update(update_data)
        .eq("id", str(current_user.id))
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=404, detail="Profile not found")

    return result.data[0]


@router.put("/me/settings", response_model=UserProfile)
async def update_user_settings(
    settings: UserSettings,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Update current user's settings."""
    supabase = get_supabase_client()

    # Get current settings to merge with updates
    current_result = (
        supabase.table("profiles")
        .select("settings")
        .eq("id", str(current_user.id))
        .single()
        .execute()
    )
    current_settings = current_result.data.get("settings") or {} if current_result.data else {}

    # Build settings JSON, preserving existing values
    settings_data = {
        "units": settings.units,
        "timezone": settings.timezone,
        "notifications_enabled": settings.notifications_enabled,
        "daily_goals": settings.daily_goals or current_settings.get("daily_goals") or {
            "steps": 10000,
            "active_calories": 500,
            "sleep_hours": 8,
            "water_liters": 2.5,
        },
    }

    # Add baseline settings if provided
    if settings.hrv_baseline is not None:
        settings_data["hrv_baseline"] = settings.hrv_baseline
    elif "hrv_baseline" in current_settings:
        settings_data["hrv_baseline"] = current_settings["hrv_baseline"]

    if settings.rhr_baseline is not None:
        settings_data["rhr_baseline"] = settings.rhr_baseline
    elif "rhr_baseline" in current_settings:
        settings_data["rhr_baseline"] = current_settings["rhr_baseline"]

    if settings.target_sleep_hours is not None:
        settings_data["target_sleep_hours"] = settings.target_sleep_hours
    elif "target_sleep_hours" in current_settings:
        settings_data["target_sleep_hours"] = current_settings["target_sleep_hours"]

    if settings.daily_step_goal is not None:
        settings_data["daily_step_goal"] = settings.daily_step_goal
    elif "daily_step_goal" in current_settings:
        settings_data["daily_step_goal"] = current_settings["daily_step_goal"]

    if settings.social_opt_in is not None:
        settings_data["social_opt_in"] = settings.social_opt_in
    elif "social_opt_in" in current_settings:
        settings_data["social_opt_in"] = current_settings["social_opt_in"]

    update_data = {"settings": settings_data}

    if settings.display_name is not None:
        update_data["display_name"] = settings.display_name

    result = (
        supabase.table("profiles")
        .update(update_data)
        .eq("id", str(current_user.id))
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=404, detail="Profile not found")

    return result.data[0]


@router.get("/me/export")
async def export_user_data(
    current_user: CurrentUser = Depends(get_current_user),
):
    """Export all user data as JSON (GDPR Article 20 — data portability)."""
    supabase = get_supabase_client()
    uid = str(current_user.id)

    # All user-data tables to export
    user_tables = [
        "profiles", "health_metrics", "workouts", "workout_sessions",
        "workout_sets", "personal_records", "exercise_progress",
        "daily_scores", "predictions", "insights",
        "nutrition_goals", "food_entries",
        "user_training_plans", "user_weekly_meal_plans", "user_weekly_plan_items",
    ]

    export = {}
    for table in user_tables:
        try:
            result = supabase.table(table).select("*").eq("user_id", uid).execute()
            export[table] = result.data or []
        except Exception:
            export[table] = []

    # Partnerships: user can be inviter or invitee
    try:
        as_inviter = supabase.table("partnerships").select("*").eq("inviter_id", uid).execute()
        as_invitee = supabase.table("partnerships").select("*").eq("invitee_id", uid).execute()
        export["partnerships"] = (as_inviter.data or []) + (as_invitee.data or [])
    except Exception:
        export["partnerships"] = []

    # Invite codes created by user
    try:
        codes = supabase.table("invite_codes").select("*").eq("created_by", uid).execute()
        export["invite_codes"] = codes.data or []
    except Exception:
        export["invite_codes"] = []

    export["exported_at"] = datetime.now(timezone.utc).isoformat()

    return JSONResponse(
        content=export,
        headers={"Content-Disposition": 'attachment; filename="healthpulse-export.json"'},
    )


@router.delete("/me")
async def delete_user_account(
    current_user: CurrentUser = Depends(get_current_user),
):
    """Delete current user's account and all data (GDPR Article 17 — right to erasure)."""
    supabase = get_supabase_client()
    uid = str(current_user.id)

    # Delete profile (cascade will delete all related user data)
    (
        supabase.table("profiles")
        .delete()
        .eq("id", uid)
        .execute()
    )

    # Also delete the auth.users record so the account is fully removed
    try:
        supabase.auth.admin.delete_user(uid)
    except Exception as e:
        # Log but don't fail — user data is already deleted
        logger.warning("Could not delete auth record for %s: %s", uid, e)

    return {"message": "Account and all data deleted successfully"}


@router.post("/me/onboarding", response_model=UserProfile)
async def complete_onboarding(
    profile: OnboardingProfile,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Complete user onboarding with profile data."""
    supabase = get_supabase_client()

    logger.info("Onboarding for user %s", current_user.id)

    try:
        # Update profile with onboarding data
        update_data = {
            "age": profile.age,
            "height_cm": profile.height_cm,
            "gender": profile.gender,
            "activity_level": profile.activity_level,
            "fitness_goal": profile.fitness_goal,
        }
        if profile.display_name:
            update_data["display_name"] = profile.display_name

        logger.debug("Updating profile: %s", update_data)
        result = (
            supabase.table("profiles")
            .update(update_data)
            .eq("id", str(current_user.id))
            .execute()
        )

        if not result.data:
            raise HTTPException(status_code=404, detail="Profile not found")

        logger.debug("Profile updated successfully")

        # Also log the initial weight as a metric
        if profile.weight_kg:
            weight_data = {
                "user_id": str(current_user.id),
                "metric_type": "weight",
                "value": profile.weight_kg,
                "unit": "kg",
                "source": "manual",
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }
            logger.debug("Logging weight: %s", weight_data)
            supabase.table("health_metrics").insert(weight_data).execute()
            logger.debug("Weight logged successfully")

        # Update settings with target sleep and training preferences
        settings = result.data[0].get("settings") or {}
        if profile.target_sleep_hours:
            settings["target_sleep_hours"] = profile.target_sleep_hours
        if profile.target_weight_kg:
            settings["target_weight_kg"] = profile.target_weight_kg
        # Add training preferences to settings
        if profile.training_modality:
            settings["training_modality"] = profile.training_modality
        if profile.equipment:
            settings["equipment"] = profile.equipment
        if profile.days_per_week:
            settings["days_per_week"] = profile.days_per_week
        if profile.preferred_days:
            settings["preferred_days"] = profile.preferred_days
        if profile.social_opt_in is not None:
            settings["social_opt_in"] = profile.social_opt_in

        supabase.table("profiles").update({"settings": settings}).eq("id", str(current_user.id)).execute()
        logger.debug("Settings updated with training preferences")

        # Calculate and create nutrition goal
        calculator = get_nutrition_calculator()
        targets = calculator.calculate_targets(
            weight_kg=profile.weight_kg,
            height_cm=profile.height_cm,
            age=profile.age,
            gender=profile.gender,
            activity_level=profile.activity_level,
            goal_type=profile.fitness_goal,
        )
        logger.debug("Calculated targets: BMR=%s, TDEE=%s, Calories=%s", targets.bmr, targets.tdee, targets.calorie_target)

        # Upsert nutrition goal (delete existing first, then insert)
        supabase.table("nutrition_goals").delete().eq("user_id", str(current_user.id)).execute()
        nutrition_goal = {
            "user_id": str(current_user.id),
            "goal_type": profile.fitness_goal,
            "bmr": targets.bmr,
            "tdee": targets.tdee,
            "calorie_target": targets.calorie_target,
            "protein_target_g": targets.protein_g,
            "carbs_target_g": targets.carbs_g,
            "fat_target_g": targets.fat_g,
            "adjust_for_activity": True,
        }
        supabase.table("nutrition_goals").insert(nutrition_goal).execute()
        logger.debug("Nutrition goal created with %s kcal target", targets.calorie_target)

        # Create training plan if training preferences were provided
        if profile.training_modality and profile.days_per_week:
            try:
                # Find a matching plan template
                template_result = (
                    supabase.table("plan_templates")
                    .select("*")
                    .eq("modality", profile.training_modality)
                    .eq("days_per_week", profile.days_per_week)
                    .limit(1)
                    .execute()
                )

                if template_result.data:
                    template = template_result.data[0]
                    # Build schedule from preferred days
                    schedule = {}
                    workouts = template.get("workouts", [])
                    if profile.preferred_days and workouts:
                        for i, day in enumerate(sorted(profile.preferred_days)):
                            if i < len(workouts):
                                schedule[str(day)] = workouts[i].get("name", f"Workout {i+1}")

                    training_plan = {
                        "user_id": str(current_user.id),
                        "template_id": template["id"],
                        "name": template["name"],
                        "description": template.get("description"),
                        "goal_type": profile.fitness_goal,
                        "schedule": schedule,
                        "is_active": True,
                    }
                    supabase.table("user_training_plans").insert(training_plan).execute()
                    logger.debug("Training plan '%s' created", template["name"])
                else:
                    logger.debug("No matching template found for %s/%s days", profile.training_modality, profile.days_per_week)
            except Exception as plan_error:
                logger.warning("Could not create training plan: %s", plan_error)
                # Don't fail onboarding if plan creation fails

        # Re-fetch the updated profile
        updated = (
            supabase.table("profiles")
            .select("*")
            .eq("id", str(current_user.id))
            .execute()
        )

        logger.info("Onboarding complete for user %s", current_user.id)
        return updated.data[0] if updated.data else result.data[0]

    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Onboarding error")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to save onboarding data: {str(e)}"
        )
