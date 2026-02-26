"""Account management endpoints — email/password changes."""

import logging

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, EmailStr, Field

from app.auth import get_current_user, CurrentUser
from app.database import get_supabase_anon, get_supabase_admin
from app.rate_limit import limiter

logger = logging.getLogger(__name__)
router = APIRouter()


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str = Field(min_length=8)


class ChangeEmailRequest(BaseModel):
    new_email: EmailStr
    current_password: str


class MessageResponse(BaseModel):
    message: str


@router.post("/change-password", response_model=MessageResponse)
@limiter.limit("3/minute")
async def change_password(
    request: Request,
    body: ChangePasswordRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Change the authenticated user's password."""
    # Verify current password
    supabase_anon = get_supabase_anon()
    try:
        supabase_anon.auth.sign_in_with_password({
            "email": current_user.email,
            "password": body.current_password,
        })
    except Exception:
        raise HTTPException(status_code=401, detail="Current password is incorrect")

    # Update password via admin
    try:
        supabase_admin = get_supabase_admin()
        supabase_admin.auth.admin.update_user_by_id(
            str(current_user.id),
            {"password": body.new_password},
        )
        logger.info("Password changed for user %s", current_user.id)
        return MessageResponse(message="Password updated successfully")
    except Exception as e:
        logger.error("Password change failed for %s: %s", current_user.id, e)
        raise HTTPException(status_code=500, detail="Failed to update password")


@router.post("/change-email", response_model=MessageResponse)
@limiter.limit("3/minute")
async def change_email(
    request: Request,
    body: ChangeEmailRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Change the authenticated user's email address."""
    # Verify current password
    supabase_anon = get_supabase_anon()
    try:
        supabase_anon.auth.sign_in_with_password({
            "email": current_user.email,
            "password": body.current_password,
        })
    except Exception:
        raise HTTPException(status_code=401, detail="Current password is incorrect")

    # Update email via admin
    try:
        supabase_admin = get_supabase_admin()
        supabase_admin.auth.admin.update_user_by_id(
            str(current_user.id),
            {"email": body.new_email},
        )
        logger.info("Email change requested for user %s → %s", current_user.id, body.new_email)
        return MessageResponse(message="Confirmation email sent to your new address")
    except Exception as e:
        logger.error("Email change failed for %s: %s", current_user.id, e)
        raise HTTPException(status_code=500, detail="Failed to update email")
