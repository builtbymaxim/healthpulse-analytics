"""Authentication endpoints for sign up, sign in, and token management."""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, EmailStr

from app.database import get_supabase_anon

router = APIRouter()


class SignUpRequest(BaseModel):
    """Sign up request."""
    email: EmailStr
    password: str


class SignInRequest(BaseModel):
    """Sign in request."""
    email: EmailStr
    password: str


class AuthResponse(BaseModel):
    """Authentication response with tokens."""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user_id: str
    email: str


class SignUpPendingResponse(BaseModel):
    """Response when email confirmation is required."""
    message: str
    user_id: str | None
    email: str
    requires_confirmation: bool = True


@router.post("/signup", response_model=AuthResponse | SignUpPendingResponse)
async def sign_up(request: SignUpRequest):
    """
    Create a new user account.

    Returns access token that can be used to authenticate API requests.
    """
    supabase = get_supabase_anon()

    try:
        response = supabase.auth.sign_up({
            "email": request.email,
            "password": request.password,
        })

        if response.user is None:
            raise HTTPException(
                status_code=400,
                detail="Sign up failed. Check if email is already registered.",
            )

        # For email confirmation enabled projects, session is None until confirmed
        if response.session is None:
            return {
                "message": "Check your email for confirmation link.",
                "user_id": str(response.user.id) if response.user else None,
                "email": request.email,
                "requires_confirmation": True
            }

        return AuthResponse(
            access_token=response.session.access_token,
            refresh_token=response.session.refresh_token,
            expires_in=response.session.expires_in or 3600,
            user_id=str(response.user.id),
            email=response.user.email or request.email,
        )

    except Exception as e:
        if "already registered" in str(e).lower():
            raise HTTPException(status_code=400, detail="Email already registered")
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/signin", response_model=AuthResponse)
async def sign_in(request: SignInRequest):
    """
    Sign in with email and password.

    Returns access token that can be used to authenticate API requests.
    Copy the access_token and use it in the Authorization header:
    Authorization: Bearer <access_token>
    """
    supabase = get_supabase_anon()

    try:
        response = supabase.auth.sign_in_with_password({
            "email": request.email,
            "password": request.password,
        })

        if response.user is None or response.session is None:
            raise HTTPException(
                status_code=401,
                detail="Invalid email or password",
            )

        return AuthResponse(
            access_token=response.session.access_token,
            refresh_token=response.session.refresh_token,
            expires_in=response.session.expires_in or 3600,
            user_id=str(response.user.id),
            email=response.user.email or request.email,
        )

    except Exception as e:
        if "invalid" in str(e).lower():
            raise HTTPException(status_code=401, detail="Invalid email or password")
        raise HTTPException(status_code=400, detail=str(e))


class RefreshRequest(BaseModel):
    """Refresh token request."""
    refresh_token: str


@router.post("/refresh")
async def refresh_token(request: RefreshRequest):
    """Refresh an expired access token."""
    supabase = get_supabase_anon()

    try:
        response = supabase.auth.refresh_session(request.refresh_token)

        if response.session is None:
            raise HTTPException(status_code=401, detail="Invalid refresh token")

        return AuthResponse(
            access_token=response.session.access_token,
            refresh_token=response.session.refresh_token,
            expires_in=response.session.expires_in or 3600,
            user_id=str(response.user.id) if response.user else "",
            email=response.user.email if response.user else "",
        )

    except Exception as e:
        raise HTTPException(status_code=401, detail=str(e))
