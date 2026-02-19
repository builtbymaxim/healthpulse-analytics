"""Simple circuit breaker for external service calls."""

import logging
import time

logger = logging.getLogger(__name__)

# States: "closed" (normal) → "open" (reject calls) → "half_open" (probe allowed)


class CircuitBreaker:
    """
    Prevents hammering a failing external service.

    After `failure_threshold` consecutive failures the circuit opens and all
    calls are short-circuited for `cooldown_seconds`. A single probe is then
    allowed (half-open state); on success the circuit closes, on failure it
    reopens for another cooldown period.
    """

    def __init__(
        self,
        name: str,
        failure_threshold: int = 5,
        cooldown_seconds: float = 60.0,
    ) -> None:
        self.name = name
        self.failure_threshold = failure_threshold
        self.cooldown_seconds = cooldown_seconds
        self._failure_count = 0
        self._last_failure_time: float = 0.0
        self._state = "closed"

    @property
    def is_open(self) -> bool:
        """Return True if calls should be rejected right now."""
        if self._state == "open":
            elapsed = time.monotonic() - self._last_failure_time
            if elapsed >= self.cooldown_seconds:
                logger.info("Circuit '%s' entering half-open state", self.name)
                self._state = "half_open"
                return False
            return True
        return False

    @property
    def state(self) -> str:
        return self._state

    def record_success(self) -> None:
        if self._state != "closed":
            logger.info("Circuit '%s' closed after successful probe", self.name)
        self._failure_count = 0
        self._state = "closed"

    def record_failure(self) -> None:
        self._failure_count += 1
        self._last_failure_time = time.monotonic()
        if self._failure_count >= self.failure_threshold:
            if self._state != "open":
                logger.warning(
                    "Circuit '%s' OPEN after %d consecutive failures",
                    self.name, self._failure_count,
                )
            self._state = "open"
