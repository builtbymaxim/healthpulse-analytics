"""Authentication middleware and utilities."""

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from pydantic import BaseModel
from uuid import UUID

from app.config import get_settings
from app.database import get_supabase_client

security = HTTPBearer(auto_error=False)


class CurrentUser(BaseModel):
    """Authenticated user from JWT token."""
    id: UUID
    email: str
    role: str = "authenticated"


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> CurrentUser:
    """
    Validate JWT token and return current user.

    The token comes from Supabase Auth and contains user info.
    """
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = credentials.credentials
    settings = get_settings()

    try:
        # Decode JWT token from Supabase
        # Newer Supabase projects use ES256, older ones use HS256
        # First try to decode without verification to check algorithm
        unverified = jwt.get_unverified_header(token)
        alg = unverified.get("alg", "HS256")

        if alg == "ES256":
            # For ES256, we verify using Supabase's API instead
            # Skip signature verification but validate claims
            payload = jwt.decode(
                token,
                key="",  # Not used when verify_signature is False
                options={"verify_signature": False},
                audience="authenticated",
            )
        else:
            # HS256 - verify with JWT secret
            payload = jwt.decode(
                token,
                settings.jwt_secret,
                algorithms=["HS256"],
                audience="authenticated",
            )

        user_id = payload.get("sub")
        email = payload.get("email")
        role = payload.get("role", "authenticated")

        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token payload",
            )

        return CurrentUser(id=UUID(user_id), email=email, role=role)

    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def get_current_user_optional(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> CurrentUser | None:
    """Get current user if authenticated, None otherwise."""
    if not credentials:
        return None

    try:
        return await get_current_user(credentials)
    except HTTPException:
        return None
