"""Database models representing Supabase tables."""

from pydantic import BaseModel, EmailStr
from datetime import datetime, date
from uuid import UUID
from enum import Enum


class User(BaseModel):
    """User profile model."""
    id: UUID
    email: EmailStr
    display_name: str | None = None
    avatar_url: str | None = None
    created_at: datetime
    updated_at: datetime | None = None

    # Settings stored as JSON
    settings: dict = {
        "units": "metric",
        "timezone": "UTC",
        "notifications_enabled": True,
        "daily_goals": {
            "steps": 10000,
            "active_calories": 500,
            "sleep_hours": 8,
            "water_liters": 2.5,
        },
    }


class MetricType(str, Enum):
    """All trackable metric types."""
    # Activity
    STEPS = "steps"
    ACTIVE_CALORIES = "active_calories"
    DISTANCE = "distance"

    # Body
    WEIGHT = "weight"
    BODY_FAT = "body_fat"

    # Vitals
    HEART_RATE = "heart_rate"
    RESTING_HR = "resting_hr"
    HRV = "hrv"

    # Sleep
    SLEEP_DURATION = "sleep_duration"
    SLEEP_QUALITY = "sleep_quality"
    DEEP_SLEEP = "deep_sleep"
    REM_SLEEP = "rem_sleep"

    # Nutrition
    CALORIES_IN = "calories_in"
    PROTEIN = "protein"
    CARBS = "carbs"
    FAT = "fat"
    WATER = "water"

    # Subjective
    ENERGY_LEVEL = "energy_level"
    MOOD = "mood"
    STRESS = "stress"
    SORENESS = "soreness"


class MetricSource(str, Enum):
    """Data source for metrics."""
    MANUAL = "manual"
    APPLE_HEALTH = "apple_health"
    GARMIN = "garmin"
    FITBIT = "fitbit"
    WHOOP = "whoop"
    OURA = "oura"


class HealthMetric(BaseModel):
    """Individual health metric entry."""
    id: UUID
    user_id: UUID
    metric_type: MetricType
    value: float
    unit: str | None = None
    timestamp: datetime
    source: MetricSource = MetricSource.MANUAL
    notes: str | None = None
    created_at: datetime


class WorkoutType(str, Enum):
    """Workout categories."""
    RUNNING = "running"
    CYCLING = "cycling"
    SWIMMING = "swimming"
    WALKING = "walking"
    WEIGHT_TRAINING = "weight_training"
    YOGA = "yoga"
    HIIT = "hiit"
    OTHER = "other"


class Workout(BaseModel):
    """Workout session model."""
    id: UUID
    user_id: UUID
    workout_type: WorkoutType
    start_time: datetime
    duration_minutes: int
    intensity: str  # light, moderate, hard, very_hard
    calories_burned: int | None = None
    distance_km: float | None = None
    avg_heart_rate: int | None = None
    max_heart_rate: int | None = None
    training_load: float | None = None  # Calculated
    notes: str | None = None
    exercises: list[dict] | None = None  # For strength workouts
    source: MetricSource = MetricSource.MANUAL
    created_at: datetime


class DailyScore(BaseModel):
    """Daily aggregated scores and metrics."""
    id: UUID
    user_id: UUID
    date: date

    # Aggregated metrics
    total_steps: int | None = None
    total_active_calories: int | None = None
    total_sleep_minutes: int | None = None
    avg_sleep_quality: float | None = None
    avg_resting_hr: int | None = None
    avg_hrv: float | None = None

    # Calculated scores (0-100)
    wellness_score: float | None = None
    recovery_score: float | None = None
    readiness_score: float | None = None
    activity_score: float | None = None
    sleep_score: float | None = None

    # Subjective ratings
    energy_level: int | None = None
    mood: int | None = None
    stress_level: int | None = None
    soreness_level: int | None = None

    created_at: datetime
    updated_at: datetime | None = None


class PredictionType(str, Enum):
    """Types of ML predictions."""
    RECOVERY = "recovery"
    READINESS = "readiness"
    SLEEP_QUALITY = "sleep_quality"
    WELLNESS_TREND = "wellness_trend"


class Prediction(BaseModel):
    """ML prediction result."""
    id: UUID
    user_id: UUID
    prediction_type: PredictionType
    predicted_value: float
    confidence: float
    input_features: dict
    contributing_factors: list[dict]
    created_at: datetime
    valid_until: datetime


class InsightCategory(str, Enum):
    """Categories of AI insights."""
    CORRELATION = "correlation"
    ANOMALY = "anomaly"
    TREND = "trend"
    RECOMMENDATION = "recommendation"
    ACHIEVEMENT = "achievement"


class Insight(BaseModel):
    """AI-generated insight."""
    id: UUID
    user_id: UUID
    category: InsightCategory
    title: str
    description: str
    supporting_data: dict | None = None
    priority: int = 0  # Higher = more important
    is_read: bool = False
    created_at: datetime
    expires_at: datetime | None = None
