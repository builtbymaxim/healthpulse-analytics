"""Meal plan models for recipes, templates, and barcode lookups."""

from pydantic import BaseModel, Field
from enum import Enum
from uuid import UUID
from datetime import date as DateType, datetime


class RecipeCategory(str, Enum):
    BREAKFAST = "breakfast"
    LUNCH = "lunch"
    DINNER = "dinner"
    SNACK = "snack"
    DESSERT = "dessert"
    SHAKE = "shake"


class RecipeIngredient(BaseModel):
    name: str
    amount: float
    unit: str


class RecipeListItem(BaseModel):
    """Lightweight recipe for list views."""
    id: UUID
    name: str
    category: str
    description: str | None = None
    calories_per_serving: float
    protein_g_per_serving: float
    carbs_g_per_serving: float
    fat_g_per_serving: float
    fiber_g_per_serving: float = 0
    tags: list[str] = []
    goal_types: list[str] = []
    prep_time_min: int | None = None
    cook_time_min: int | None = None


class RecipeResponse(RecipeListItem):
    """Full recipe with ingredients and instructions."""
    ingredients: list[RecipeIngredient] = []
    instructions: list[str] = []
    servings: int = 1
    image_url: str | None = None
    created_at: datetime | None = None


class MealPlanItemResponse(BaseModel):
    id: UUID
    recipe_id: UUID
    recipe: RecipeListItem | None = None
    meal_type: str
    servings: float = 1
    sort_order: int = 0
    total_calories: float = 0
    total_protein_g: float = 0
    total_carbs_g: float = 0
    total_fat_g: float = 0


class MealPlanTemplateListItem(BaseModel):
    """Lightweight template for list views."""
    id: UUID
    name: str
    description: str | None = None
    goal_type: str
    total_calories: float
    total_protein_g: float
    total_carbs_g: float
    total_fat_g: float
    tags: list[str] = []
    item_count: int = 0


class MealPlanTemplateResponse(BaseModel):
    """Full template with items and recipe details."""
    id: UUID
    name: str
    description: str | None = None
    goal_type: str
    total_calories: float
    total_protein_g: float
    total_carbs_g: float
    total_fat_g: float
    tags: list[str] = []
    items: list[MealPlanItemResponse] = []


class QuickAddFromRecipeRequest(BaseModel):
    recipe_id: UUID
    meal_type: str = Field(pattern="^(breakfast|lunch|dinner|snack)$")
    servings: float = Field(ge=0.5, le=10, default=1)
    logged_at: datetime | None = None


class BarcodeProductResponse(BaseModel):
    barcode: str
    name: str | None = None
    brand: str | None = None
    calories_per_100g: float = 0
    protein_g_per_100g: float = 0
    carbs_g_per_100g: float = 0
    fat_g_per_100g: float = 0
    fiber_g_per_100g: float = 0
    serving_size: str | None = None
    image_url: str | None = None
    found: bool = True


class ShoppingListItem(BaseModel):
    name: str
    total_amount: float
    unit: str


# ─── Phase 9A: User Weekly Meal Plans ────────────────────────────────────────


class WeeklyPlanItemBase(BaseModel):
    day_of_week: int = Field(ge=1, le=7)
    meal_type: str = Field(pattern="^(breakfast|lunch|dinner|snack)$")
    recipe_id: UUID
    servings: float = Field(ge=0.5, le=10, default=1)
    sort_order: int = 0


class WeeklyPlanItemResponse(WeeklyPlanItemBase):
    id: UUID
    plan_id: UUID
    recipe: RecipeListItem | None = None
    total_calories: float = 0
    total_protein_g: float = 0
    total_carbs_g: float = 0
    total_fat_g: float = 0


class WeeklyMealPlanResponse(BaseModel):
    id: UUID
    user_id: UUID
    name: str
    week_start_date: DateType
    is_recurring: bool
    created_at: datetime | None = None
    updated_at: datetime | None = None
    items: list[WeeklyPlanItemResponse] = []


class WeeklyMealPlanListItem(BaseModel):
    id: UUID
    name: str
    week_start_date: DateType
    is_recurring: bool
    total_calories: float = 0
    item_count: int = 0


class CreateWeeklyPlanRequest(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    week_start_date: DateType
    is_recurring: bool = False


class UpsertWeeklyPlanItemRequest(BaseModel):
    day_of_week: int = Field(ge=1, le=7)
    meal_type: str = Field(pattern="^(breakfast|lunch|dinner|snack)$")
    recipe_id: UUID
    servings: float = Field(ge=0.5, le=10, default=1)
    sort_order: int = 0


class AutoFillRequest(BaseModel):
    template_id: UUID
    mode: str = Field(default="repeat", pattern="^(repeat|rotate)$")


class ApplyToPlanRequest(BaseModel):
    mode: str = Field(pattern="^(today|week)$")


class DayMacroSummary(BaseModel):
    day_of_week: int
    total_calories: float
    total_protein_g: float
    total_carbs_g: float
    total_fat_g: float


class WeeklyShoppingListItem(BaseModel):
    name: str
    total_amount: float
    unit: str
