"""Nutrition-related Pydantic models for calorie and macro tracking."""

from datetime import date, datetime
from enum import Enum
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field


# Enums

class Gender(str, Enum):
    """Gender options for BMR calculation."""
    MALE = "male"
    FEMALE = "female"
    OTHER = "other"


class ActivityLevel(str, Enum):
    """Activity level for TDEE calculation."""
    SEDENTARY = "sedentary"
    LIGHT = "light"
    MODERATE = "moderate"
    ACTIVE = "active"
    VERY_ACTIVE = "very_active"


class NutritionGoalType(str, Enum):
    """Nutrition goal types."""
    LOSE_WEIGHT = "lose_weight"
    BUILD_MUSCLE = "build_muscle"
    MAINTAIN = "maintain"
    GENERAL_HEALTH = "general_health"


class MealType(str, Enum):
    """Meal types for food logging."""
    BREAKFAST = "breakfast"
    LUNCH = "lunch"
    DINNER = "dinner"
    SNACK = "snack"


# Request Models

class PhysicalProfileUpdate(BaseModel):
    """Request to update physical profile data for BMR calculation."""
    age: int = Field(ge=13, le=120, description="Age in years")
    height_cm: float = Field(ge=100, le=250, description="Height in centimeters")
    gender: Gender
    activity_level: ActivityLevel = ActivityLevel.MODERATE


class NutritionGoalCreate(BaseModel):
    """Request to create/update nutrition goal."""
    goal_type: NutritionGoalType
    custom_calorie_target: Optional[float] = Field(
        None, ge=800, le=10000, description="Override calculated calorie target"
    )
    custom_protein_target_g: Optional[float] = Field(
        None, ge=0, le=500, description="Override protein target in grams"
    )
    custom_carbs_target_g: Optional[float] = Field(
        None, ge=0, le=1000, description="Override carbs target in grams"
    )
    custom_fat_target_g: Optional[float] = Field(
        None, ge=0, le=500, description="Override fat target in grams"
    )
    adjust_for_activity: bool = Field(
        True, description="Adjust TDEE based on logged workouts"
    )


class FoodEntryCreate(BaseModel):
    """Request to log a food entry."""
    name: str = Field(min_length=1, max_length=200)
    meal_type: Optional[MealType] = None
    calories: float = Field(ge=0, description="Calories")
    protein_g: float = Field(ge=0, default=0, description="Protein in grams")
    carbs_g: float = Field(ge=0, default=0, description="Carbs in grams")
    fat_g: float = Field(ge=0, default=0, description="Fat in grams")
    fiber_g: float = Field(ge=0, default=0, description="Fiber in grams")
    serving_size: float = Field(ge=0, default=1, description="Number of servings")
    serving_unit: str = Field(default="serving", max_length=50)
    logged_at: Optional[datetime] = Field(None, description="When the food was consumed")
    notes: Optional[str] = Field(None, max_length=500)


class TargetCalculationRequest(BaseModel):
    """Request to preview calculated targets without saving.

    If profile fields are provided, they will be used for calculation
    instead of the saved profile data. This enables real-time preview
    while user is editing their profile.
    """
    goal_type: NutritionGoalType
    weight_kg: Optional[float] = Field(None, ge=20, le=500, description="Override current weight")
    # Optional profile overrides for real-time preview
    age: Optional[int] = Field(None, ge=13, le=120, description="Override age")
    height_cm: Optional[float] = Field(None, ge=100, le=250, description="Override height")
    gender: Optional[str] = Field(None, description="Override gender (male/female/other)")
    activity_level: Optional[str] = Field(None, description="Override activity level")


# Response Models

class MacroTargets(BaseModel):
    """Macro nutrient targets."""
    protein_g: float
    carbs_g: float
    fat_g: float
    protein_pct: float
    carbs_pct: float
    fat_pct: float


class CalorieTargets(BaseModel):
    """Complete calorie and macro targets."""
    bmr: float
    tdee: float
    calorie_target: float
    macros: MacroTargets
    goal_type: NutritionGoalType
    using_custom_values: bool = False


class PhysicalProfileResponse(BaseModel):
    """Physical profile data response."""
    age: Optional[int] = None
    height_cm: Optional[float] = None
    gender: Optional[str] = None
    activity_level: Optional[str] = None
    latest_weight_kg: Optional[float] = None
    profile_complete: bool = False


class NutritionGoalResponse(BaseModel):
    """Full nutrition goal response."""
    id: UUID
    user_id: UUID
    goal_type: NutritionGoalType
    bmr: Optional[float] = None
    tdee: Optional[float] = None
    calorie_target: Optional[float] = None
    protein_target_g: Optional[float] = None
    carbs_target_g: Optional[float] = None
    fat_target_g: Optional[float] = None
    custom_calorie_target: Optional[float] = None
    custom_protein_target_g: Optional[float] = None
    custom_carbs_target_g: Optional[float] = None
    custom_fat_target_g: Optional[float] = None
    adjust_for_activity: bool = True
    created_at: datetime
    updated_at: Optional[datetime] = None


class FoodEntryResponse(BaseModel):
    """Food entry response."""
    id: UUID
    user_id: UUID
    name: str
    meal_type: Optional[str] = None
    calories: float
    protein_g: float
    carbs_g: float
    fat_g: float
    fiber_g: float
    serving_size: float
    serving_unit: str
    logged_at: datetime
    notes: Optional[str] = None
    source: str = "manual"
    created_at: datetime


class MacroProgress(BaseModel):
    """Progress toward a macro target."""
    consumed: float
    target: float
    remaining: float
    progress_pct: float


class DailyNutritionSummary(BaseModel):
    """Daily nutrition progress summary."""
    date: date

    # Consumed totals
    total_calories: float
    total_protein_g: float
    total_carbs_g: float
    total_fat_g: float

    # Targets
    calorie_target: float
    protein_target_g: float
    carbs_target_g: float
    fat_target_g: float

    # Progress percentages (0-200%, over 100% = exceeded)
    calorie_progress_pct: float
    protein_progress_pct: float
    carbs_progress_pct: float
    fat_progress_pct: float

    # Remaining
    calories_remaining: float
    protein_remaining_g: float
    carbs_remaining_g: float
    fat_remaining_g: float

    # Nutrition score for wellness integration
    nutrition_score: float

    # Score breakdown
    score_breakdown: Optional[dict] = None

    # Entries
    entries: list[FoodEntryResponse] = []
    entries_by_meal: dict[str, list[FoodEntryResponse]] = {}


class NutritionScoreResponse(BaseModel):
    """Nutrition score breakdown for wellness integration."""
    nutrition_score: float
    calorie_adherence_score: float
    macro_balance_score: float
    consistency_score: float
    contributing_factors: dict
