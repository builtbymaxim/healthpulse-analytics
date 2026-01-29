"""User management endpoints."""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from datetime import datetime
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
    created_at: datetime
    settings: dict | None = None


class UserSettings(BaseModel):
    """User settings update request."""
    display_name: str | None = None
    units: str = "metric"  # metric or imperial
    timezone: str = "UTC"
    notifications_enabled: bool = True
    daily_goals: dict | None = None


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


@router.put("/me/settings", response_model=UserProfile)
async def update_user_settings(
    settings: UserSettings,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Update current user's settings."""
    supabase = get_supabase_client()

    # Build settings JSON
    settings_data = {
        "units": settings.units,
        "timezone": settings.timezone,
        "notifications_enabled": settings.notifications_enabled,
        "daily_goals": settings.daily_goals or {
            "steps": 10000,
            "active_calories": 500,
            "sleep_hours": 8,
            "water_liters": 2.5,
        },
    }

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
