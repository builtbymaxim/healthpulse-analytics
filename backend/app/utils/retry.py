"""Retry utilities with exponential backoff."""

import logging
import time
from functools import wraps
from typing import Callable, Type

logger = logging.getLogger(__name__)


def retry_with_backoff(
    max_attempts: int = 3,
    base_delay: float = 1.0,
    max_delay: float = 10.0,
    exceptions: tuple[Type[Exception], ...] = (Exception,),
) -> Callable:
    """Decorator that retries a sync function with exponential backoff."""
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            last_exc: Exception | None = None
            for attempt in range(max_attempts):
                try:
                    return func(*args, **kwargs)
                except exceptions as e:
                    last_exc = e
                    if attempt < max_attempts - 1:
                        delay = min(base_delay * (2 ** attempt), max_delay)
                        logger.warning(
                            "Retry %d/%d for %s after %.1fs: %s",
                            attempt + 1, max_attempts, func.__name__, delay, e,
                        )
                        time.sleep(delay)
            raise last_exc  # type: ignore[misc]
        return wrapper
    return decorator


def call_with_retry(
    func: Callable,
    *args,
    max_attempts: int = 3,
    base_delay: float = 1.0,
    max_delay: float = 10.0,
    exceptions: tuple[Type[Exception], ...] = (Exception,),
    **kwargs,
):
    """Call a callable with retry/backoff — for inline use without decorating."""
    last_exc: Exception | None = None
    for attempt in range(max_attempts):
        try:
            return func(*args, **kwargs)
        except exceptions as e:
            last_exc = e
            if attempt < max_attempts - 1:
                delay = min(base_delay * (2 ** attempt), max_delay)
                logger.warning(
                    "Retry %d/%d after %.1fs: %s", attempt + 1, max_attempts, delay, e,
                )
                time.sleep(delay)
    raise last_exc  # type: ignore[misc]
