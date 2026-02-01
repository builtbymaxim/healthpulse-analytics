"""User management endpoints."""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from datetime import datetime, timezone
from uuid import UUID

from app.auth import get_current_user, CurrentUser
from app.database import get_supabase_client

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
    age: int
    height_cm: float
    gender: str
    weight_kg: float
    fitness_goal: str
    activity_level: str
    target_weight_kg: float | None = None
    target_sleep_hours: float | None = None


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
    print(f"PUT /users/me received: {profile.model_dump()}")

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

    print(f"  Fields to update: {update_data}")

    if not update_data:
        # Nothing to update, just return current profile
        print("  No fields to update!")
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


@router.delete("/me")
async def delete_user_account(
    current_user: CurrentUser = Depends(get_current_user),
):
    """Delete current user's account and all data."""
    supabase = get_supabase_client()

    # Delete profile (cascade will delete related data)
    (
        supabase.table("profiles")
        .delete()
        .eq("id", str(current_user.id))
        .execute()
    )

    # Note: This deletes the profile, but the auth.users record
    # needs to be deleted via Supabase Auth Admin API
    # For full deletion, you'd call supabase.auth.admin.delete_user()

    return {"message": "Account data deleted successfully"}


@router.post("/me/onboarding", response_model=UserProfile)
async def complete_onboarding(
    profile: OnboardingProfile,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Complete user onboarding with profile data."""
    supabase = get_supabase_client()

    # Update profile with onboarding data
    update_data = {
        "age": profile.age,
        "height_cm": profile.height_cm,
        "gender": profile.gender,
        "activity_level": profile.activity_level,
        "fitness_goal": profile.fitness_goal,
    }

    result = (
        supabase.table("profiles")
        .update(update_data)
        .eq("id", str(current_user.id))
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=404, detail="Profile not found")

    # Also log the initial weight as a metric
    if profile.weight_kg:
        weight_data = {
            "user_id": str(current_user.id),
            "metric_type": "weight",
            "value": profile.weight_kg,
            "unit": "kg",
            "source": "manual",
            "recorded_at": datetime.now(timezone.utc).isoformat(),
        }
        supabase.table("health_metrics").insert(weight_data).execute()

    # Update settings with target sleep if provided
    if profile.target_sleep_hours:
        settings = result.data[0].get("settings") or {}
        settings["target_sleep_hours"] = profile.target_sleep_hours
        if profile.target_weight_kg:
            settings["target_weight_kg"] = profile.target_weight_kg
        supabase.table("profiles").update({"settings": settings}).eq("id", str(current_user.id)).execute()

    # Re-fetch the updated profile
    updated = (
        supabase.table("profiles")
        .select("*")
        .eq("id", str(current_user.id))
        .execute()
    )

    return updated.data[0] if updated.data else result.data[0]
