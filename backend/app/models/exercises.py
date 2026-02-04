"""Exercise and strength training models."""

from pydantic import BaseModel, Field
from datetime import datetime
from uuid import UUID
from enum import Enum


class ExerciseCategory(str, Enum):
    """Exercise muscle group categories."""
    CHEST = "chest"
    BACK = "back"
    SHOULDERS = "shoulders"
    ARMS = "arms"
    LEGS = "legs"
    CORE = "core"
    CARDIO = "cardio"
    OTHER = "other"


class EquipmentType(str, Enum):
    """Exercise equipment types."""
    BARBELL = "barbell"
    DUMBBELL = "dumbbell"
    CABLE = "cable"
    MACHINE = "machine"
    BODYWEIGHT = "bodyweight"
    KETTLEBELL = "kettlebell"
    BANDS = "bands"
    OTHER = "other"


class PRType(str, Enum):
    """Personal record types."""
    ONE_RM = "1rm"
    THREE_RM = "3rm"
    FIVE_RM = "5rm"
    TEN_RM = "10rm"
    MAX_REPS = "max_reps"
    MAX_VOLUME = "max_volume"


class ExerciseInputType(str, Enum):
    """How exercise sets are logged."""
    WEIGHT_AND_REPS = "weight_and_reps"  # Standard: weight × reps (e.g., Bench Press: 80kg × 5)
    REPS_ONLY = "reps_only"              # Bodyweight: reps only (e.g., Push-up: 20 reps)
    TIME_ONLY = "time_only"              # Timed: duration in seconds (e.g., Plank: 60s)
    DISTANCE_AND_TIME = "distance_and_time"  # Cardio: distance and time (e.g., Run: 5km in 25min)


# ============================================
# Exercise Library Models
# ============================================


class Exercise(BaseModel):
    """Global exercise from library."""
    id: UUID
    name: str
    category: ExerciseCategory
    muscle_groups: list[str]
    equipment: EquipmentType | None = None
    input_type: ExerciseInputType = ExerciseInputType.WEIGHT_AND_REPS
    is_compound: bool = False
    instructions: str | None = None
    created_at: datetime


class ExerciseCreate(BaseModel):
    """Create new exercise (admin only)."""
    name: str
    category: ExerciseCategory
    muscle_groups: list[str]
    equipment: EquipmentType | None = None
    is_compound: bool = False
    instructions: str | None = None


# ============================================
# Workout Set Models
# ============================================


class WorkoutSetBase(BaseModel):
    """Base workout set data."""
    exercise_id: UUID
    set_number: int = Field(gt=0)
    weight_kg: float = Field(ge=0)
    reps: int = Field(gt=0)
    rpe: float | None = Field(default=None, ge=1, le=10)
    is_warmup: bool = False
    notes: str | None = None


class WorkoutSetCreate(WorkoutSetBase):
    """Create workout set request."""
    performed_at: datetime | None = None


class WorkoutSet(WorkoutSetBase):
    """Full workout set model."""
    id: UUID
    user_id: UUID
    workout_id: UUID | None = None
    is_pr: bool = False
    performed_at: datetime
    created_at: datetime

    # Joined exercise info
    exercise_name: str | None = None
    exercise_category: ExerciseCategory | None = None


class WorkoutSetWithExercise(WorkoutSet):
    """Workout set with full exercise details."""
    exercise: Exercise


# ============================================
# Personal Record Models
# ============================================


class PersonalRecordBase(BaseModel):
    """Base PR data."""
    exercise_id: UUID
    record_type: PRType
    value: float
    achieved_at: datetime


class PersonalRecord(PersonalRecordBase):
    """Full personal record model."""
    id: UUID
    user_id: UUID
    workout_set_id: UUID | None = None
    previous_value: float | None = None
    created_at: datetime

    # Joined exercise info
    exercise_name: str | None = None
    exercise_category: ExerciseCategory | None = None


class PersonalRecordWithExercise(PersonalRecord):
    """PR with full exercise details."""
    exercise: Exercise


# ============================================
# Workout with Sets (Composite)
# ============================================


class WorkoutWithSets(BaseModel):
    """Complete workout with all sets."""
    workout_id: UUID
    workout_type: str
    start_time: datetime
    duration_minutes: int
    intensity: str
    notes: str | None = None
    sets: list[WorkoutSet]
    total_volume: float  # Sum of weight * reps
    exercises_performed: int


class WorkoutSetsCreate(BaseModel):
    """Create multiple sets for a workout."""
    workout_id: UUID | None = None
    sets: list[WorkoutSetCreate]


# ============================================
# Analytics Models
# ============================================


class ExerciseHistory(BaseModel):
    """Exercise performance history."""
    exercise_id: UUID
    exercise_name: str
    sets: list[WorkoutSet]
    personal_records: list[PersonalRecord]
    estimated_1rm: float | None = None
    total_volume_30d: float
    session_count_30d: int


class VolumeAnalytics(BaseModel):
    """Volume tracking analytics."""
    period: str  # "week", "month"
    total_volume: float
    volume_by_category: dict[str, float]
    volume_by_exercise: dict[str, float]
    trend_pct: float  # Change from previous period


class FrequencyAnalytics(BaseModel):
    """Training frequency analytics."""
    period: str  # "week", "month"
    total_sessions: int
    sessions_by_category: dict[str, int]
    sessions_by_day: dict[str, int]  # Mon, Tue, etc.
    avg_sets_per_session: float


class MuscleGroupStats(BaseModel):
    """Stats for a muscle group."""
    category: ExerciseCategory
    total_volume_7d: float
    total_sets_7d: int
    last_trained: datetime | None = None
    days_since_trained: int | None = None
