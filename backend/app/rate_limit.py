"""Shared rate limiter instance to avoid circular imports."""

from slowapi import Limiter
from slowapi.util import get_remote_address

# Default: 60 requests/minute per IP across all endpoints.
# Individual endpoints can override with @limiter.limit("N/minute").
limiter = Limiter(key_func=get_remote_address, default_limits=["60/minute"])
