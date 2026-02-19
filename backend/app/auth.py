"""Authentication middleware and utilities."""

import httpx
import logging

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt, jwk
from pydantic import BaseModel
from uuid import UUID

from app.config import get_settings
from app.utils.circuit_breaker import CircuitBreaker
from app.utils.retry import call_with_retry

logger = logging.getLogger(__name__)

security = HTTPBearer(auto_error=False)

# Cache JWKS keys from Supabase
_jwks_cache: dict | None = None

# Circuit breaker: stop hammering Supabase JWKS if it's repeatedly unavailable
_jwks_cb = CircuitBreaker("jwks", failure_threshold=3, cooldown_seconds=60)


def _get_jwks() -> dict:
    """Fetch and cache JWKS from Supabase for ES256 verification."""
    global _jwks_cache
    if _jwks_cache is not None:
        return _jwks_cache

    if _jwks_cb.is_open:
        logger.warning("JWKS fetch skipped — circuit open; using cached keys if available")
        return _jwks_cache or {"keys": []}

    settings = get_settings()
    jwks_url = f"{settings.supabase_url}/auth/v1/.well-known/jwks.json"
    try:
        resp = call_with_retry(
            httpx.get, jwks_url,
            max_attempts=3,
            base_delay=1.0,
            exceptions=(httpx.HTTPError, httpx.TimeoutException),
            timeout=10,
        )
        resp.raise_for_status()
        _jwks_cache = resp.json()
        _jwks_cb.record_success()
        return _jwks_cache
    except Exception as e:
        _jwks_cb.record_failure()
        logger.warning("Failed to fetch JWKS from Supabase: %s", e)
        return _jwks_cache or {"keys": []}


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
        unverified = jwt.get_unverified_header(token)
        alg = unverified.get("alg", "HS256")

        if alg == "ES256":
            # Verify ES256 tokens using Supabase's public JWKS
            jwks = _get_jwks()
            kid = unverified.get("kid")
            key_data = None
            for k in jwks.get("keys", []):
                if k.get("kid") == kid:
                    key_data = k
                    break

            if key_data is None:
                # Invalidate cache and retry once (key may have rotated)
                global _jwks_cache
                _jwks_cache = None
                jwks = _get_jwks()
                for k in jwks.get("keys", []):
                    if k.get("kid") == kid:
                        key_data = k
                        break

            if key_data is None:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Token signing key not found",
                )

            public_key = jwk.construct(key_data, algorithm="ES256")
            payload = jwt.decode(
                token,
                public_key,
                algorithms=["ES256"],
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

    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
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
