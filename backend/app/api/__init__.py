"""API routes package."""

from app.api import auth, health, metrics, predictions, users, workouts

__all__ = ["auth", "health", "metrics", "predictions", "users", "workouts"]
