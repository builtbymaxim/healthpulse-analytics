"""API routes package."""

from app.api import auth, health, metrics, predictions, users, workouts, nutrition, exercises, sleep

__all__ = [
    "auth",
    "health",
    "metrics",
    "predictions",
    "users",
    "workouts",
    "nutrition",
    "exercises",
    "sleep",
]
