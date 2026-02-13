"""Nutrition service for data operations and orchestration.

Follows the pattern of prediction_service.py - fetches data from DB,
delegates calculations to nutrition_calculator.py.
"""

import logging
from datetime import date, datetime, timedelta
from uuid import UUID

logger = logging.getLogger(__name__)

from app.database import get_supabase_client
from app.services.nutrition_calculator import (
    get_nutrition_calculator,
    NutritionTargets,
    NutritionScoreBreakdown,
)


class NutritionService:
    """Service for nutrition data operations."""

    def __init__(self):
        self.calculator = get_nutrition_calculator()
        self.supabase = get_supabase_client()

    async def get_user_physical_profile(self, user_id: UUID) -> dict | None:
        """Get user's physical profile data needed for BMR calculation.

        Args:
            user_id: User's UUID

        Returns:
            Dict with age, height_cm, gender, activity_level or None
        """
        result = (
            self.supabase.table("profiles")
            .select("age, height_cm, gender, activity_level")
            .eq("id", str(user_id))
            .single()
            .execute()
        )
        return result.data if result.data else None

    async def update_physical_profile(
        self,
        user_id: UUID,
        age: int,
        height_cm: float,
        gender: str,
        activity_level: str,
    ) -> dict:
        """Update user's physical profile data.

        Args:
            user_id: User's UUID
            age: Age in years
            height_cm: Height in centimeters
            gender: male, female, or other
            activity_level: Activity level string

        Returns:
            Updated profile data
        """
        update_data = {
            "age": age,
            "height_cm": height_cm,
            "gender": gender,
            "activity_level": activity_level,
        }

        result = (
            self.supabase.table("profiles")
            .update(update_data)
            .eq("id", str(user_id))
            .execute()
        )

        return result.data[0] if result.data else None

    async def get_latest_weight(self, user_id: UUID) -> float | None:
        """Get user's most recent weight from health metrics.

        Args:
            user_id: User's UUID

        Returns:
            Weight in kg or None if not found
        """
        result = (
            self.supabase.table("health_metrics")
            .select("value")
            .eq("user_id", str(user_id))
            .eq("metric_type", "weight")
            .order("timestamp", desc=True)
            .limit(1)
            .execute()
        )

        if result.data:
            return float(result.data[0].get("value"))
        return None

    async def get_nutrition_goal(self, user_id: UUID) -> dict | None:
        """Get user's current nutrition goal.

        Args:
            user_id: User's UUID

        Returns:
            Nutrition goal dict or None
        """
        try:
            result = (
                self.supabase.table("nutrition_goals")
                .select("*")
                .eq("user_id", str(user_id))
                .maybe_single()
                .execute()
            )
            return result.data if result and result.data else None
        except Exception:
            logger.warning("Failed to fetch nutrition goal for user %s", user_id, exc_info=True)
            return None

    async def create_or_update_nutrition_goal(
        self,
        user_id: UUID,
        goal_type: str,
        custom_calorie_target: float | None = None,
        custom_protein_g: float | None = None,
        custom_carbs_g: float | None = None,
        custom_fat_g: float | None = None,
        adjust_for_activity: bool = True,
    ) -> dict:
        """Create or update nutrition goal with calculated targets.

        Args:
            user_id: User's UUID
            goal_type: Nutrition goal type
            custom_calorie_target: Optional custom calorie override
            custom_protein_g: Optional custom protein override
            custom_carbs_g: Optional custom carbs override
            custom_fat_g: Optional custom fat override
            adjust_for_activity: Whether to adjust TDEE from workouts

        Returns:
            Created/updated goal dict

        Raises:
            ValueError: If profile is incomplete or weight not found
        """
        # Get physical profile
        profile = await self.get_user_physical_profile(user_id)
        if not profile or not all([
            profile.get("age"),
            profile.get("height_cm"),
            profile.get("gender")
        ]):
            raise ValueError(
                "Physical profile incomplete. Please set age, height, and gender first."
            )

        # Get latest weight
        weight_kg = await self.get_latest_weight(user_id)
        if not weight_kg:
            raise ValueError("No weight data found. Please log your weight first.")

        # Calculate targets
        targets = self.calculator.calculate_targets(
            weight_kg=weight_kg,
            height_cm=float(profile["height_cm"]),
            age=int(profile["age"]),
            gender=profile["gender"],
            activity_level=profile.get("activity_level", "moderate"),
            goal_type=goal_type,
            custom_calorie_target=custom_calorie_target,
            custom_protein_g=custom_protein_g,
            custom_carbs_g=custom_carbs_g,
            custom_fat_g=custom_fat_g,
        )

        # Prepare goal data
        goal_data = {
            "user_id": str(user_id),
            "goal_type": goal_type,
            "bmr": targets.bmr,
            "tdee": targets.tdee,
            "calorie_target": targets.calorie_target,
            "protein_target_g": targets.protein_g,
            "carbs_target_g": targets.carbs_g,
            "fat_target_g": targets.fat_g,
            "custom_calorie_target": custom_calorie_target,
            "custom_protein_target_g": custom_protein_g,
            "custom_carbs_target_g": custom_carbs_g,
            "custom_fat_target_g": custom_fat_g,
            "adjust_for_activity": adjust_for_activity,
            "updated_at": datetime.utcnow().isoformat(),
        }

        # Check if goal exists
        existing = await self.get_nutrition_goal(user_id)

        if existing:
            result = (
                self.supabase.table("nutrition_goals")
                .update(goal_data)
                .eq("user_id", str(user_id))
                .execute()
            )
        else:
            result = (
                self.supabase.table("nutrition_goals")
                .insert(goal_data)
                .execute()
            )

        return result.data[0] if result.data else None

    async def log_food_entry(
        self,
        user_id: UUID,
        name: str,
        calories: float,
        protein_g: float = 0,
        carbs_g: float = 0,
        fat_g: float = 0,
        fiber_g: float = 0,
        meal_type: str | None = None,
        serving_size: float = 1,
        serving_unit: str = "serving",
        logged_at: datetime | None = None,
        notes: str | None = None,
    ) -> dict:
        """Log a food entry.

        Args:
            user_id: User's UUID
            name: Food name
            calories: Calorie amount
            protein_g: Protein in grams
            carbs_g: Carbs in grams
            fat_g: Fat in grams
            fiber_g: Fiber in grams
            meal_type: breakfast, lunch, dinner, or snack
            serving_size: Number of servings
            serving_unit: Unit name
            logged_at: When the food was consumed
            notes: Optional notes

        Returns:
            Created food entry dict
        """
        entry_data = {
            "user_id": str(user_id),
            "name": name,
            "meal_type": meal_type,
            "calories": calories,
            "protein_g": protein_g,
            "carbs_g": carbs_g,
            "fat_g": fat_g,
            "fiber_g": fiber_g,
            "serving_size": serving_size,
            "serving_unit": serving_unit,
            "logged_at": (logged_at or datetime.utcnow()).isoformat(),
            "notes": notes,
            "source": "manual",
        }

        result = (
            self.supabase.table("food_entries")
            .insert(entry_data)
            .execute()
        )

        return result.data[0] if result.data else None

    async def get_food_entries(
        self,
        user_id: UUID,
        target_date: date | None = None,
        start_date: date | None = None,
        end_date: date | None = None,
        limit: int = 100,
    ) -> list[dict]:
        """Get food entries for a date range.

        Args:
            user_id: User's UUID
            target_date: Specific date to get entries for
            start_date: Range start date
            end_date: Range end date
            limit: Maximum entries to return

        Returns:
            List of food entry dicts
        """
        query = (
            self.supabase.table("food_entries")
            .select("*")
            .eq("user_id", str(user_id))
            .order("logged_at", desc=True)
            .limit(limit)
        )

        if target_date:
            start = datetime.combine(target_date, datetime.min.time())
            end = datetime.combine(target_date, datetime.max.time())
            query = query.gte("logged_at", start.isoformat())
            query = query.lte("logged_at", end.isoformat())
        elif start_date and end_date:
            query = query.gte("logged_at", start_date.isoformat())
            query = query.lte("logged_at", end_date.isoformat())

        result = query.execute()
        return result.data or []

    async def delete_food_entry(self, user_id: UUID, entry_id: UUID) -> bool:
        """Delete a food entry.

        Args:
            user_id: User's UUID
            entry_id: Food entry UUID

        Returns:
            True if deleted, False if not found
        """
        result = (
            self.supabase.table("food_entries")
            .delete()
            .eq("id", str(entry_id))
            .eq("user_id", str(user_id))
            .execute()
        )
        return len(result.data or []) > 0

    async def get_daily_nutrition_summary(
        self,
        user_id: UUID,
        target_date: date | None = None,
    ) -> dict:
        """Get daily nutrition summary with progress toward goals.

        Args:
            user_id: User's UUID
            target_date: Date to get summary for (defaults to today)

        Returns:
            Dict with totals, targets, progress, and entries
        """
        target = target_date or date.today()

        # Get food entries for the day
        entries = await self.get_food_entries(user_id, target_date=target)

        # Calculate totals
        total_calories = sum(float(e.get("calories", 0)) for e in entries)
        total_protein = sum(float(e.get("protein_g", 0)) for e in entries)
        total_carbs = sum(float(e.get("carbs_g", 0)) for e in entries)
        total_fat = sum(float(e.get("fat_g", 0)) for e in entries)

        # Get targets from nutrition goal
        goal = await self.get_nutrition_goal(user_id)

        if goal:
            calorie_target = float(
                goal.get("custom_calorie_target") or
                goal.get("calorie_target") or
                2000
            )
            protein_target = float(
                goal.get("custom_protein_target_g") or
                goal.get("protein_target_g") or
                150
            )
            carbs_target = float(
                goal.get("custom_carbs_target_g") or
                goal.get("carbs_target_g") or
                250
            )
            fat_target = float(
                goal.get("custom_fat_target_g") or
                goal.get("fat_target_g") or
                65
            )
        else:
            # Default targets if no goal set
            calorie_target = 2000
            protein_target = 150
            carbs_target = 250
            fat_target = 65

        # Calculate progress percentages
        def safe_pct(consumed: float, target: float) -> float:
            return (consumed / target * 100) if target > 0 else 0

        calorie_progress = safe_pct(total_calories, calorie_target)
        protein_progress = safe_pct(total_protein, protein_target)
        carbs_progress = safe_pct(total_carbs, carbs_target)
        fat_progress = safe_pct(total_fat, fat_target)

        # Calculate nutrition score
        # Get days logged this week for consistency score
        week_start = target - timedelta(days=target.weekday())
        week_entries = await self.get_food_entries(
            user_id, start_date=week_start, end_date=target
        )

        # Count unique days with entries
        days_logged = len(set(
            self._parse_date(e.get("logged_at", ""))
            for e in week_entries
            if e.get("logged_at")
        ))

        score_breakdown = self.calculator.calculate_nutrition_score(
            calories_consumed=total_calories,
            calorie_target=calorie_target,
            protein_consumed=total_protein,
            protein_target=protein_target,
            carbs_consumed=total_carbs,
            carbs_target=carbs_target,
            fat_consumed=total_fat,
            fat_target=fat_target,
            days_logged_this_week=days_logged,
        )

        # Group entries by meal
        entries_by_meal: dict[str, list] = {}
        for entry in entries:
            meal = entry.get("meal_type") or "other"
            if meal not in entries_by_meal:
                entries_by_meal[meal] = []
            entries_by_meal[meal].append(entry)

        return {
            "date": target.isoformat(),
            "total_calories": round(total_calories, 1),
            "total_protein_g": round(total_protein, 1),
            "total_carbs_g": round(total_carbs, 1),
            "total_fat_g": round(total_fat, 1),
            "calorie_target": round(calorie_target, 1),
            "protein_target_g": round(protein_target, 1),
            "carbs_target_g": round(carbs_target, 1),
            "fat_target_g": round(fat_target, 1),
            "calorie_progress_pct": round(calorie_progress, 1),
            "protein_progress_pct": round(protein_progress, 1),
            "carbs_progress_pct": round(carbs_progress, 1),
            "fat_progress_pct": round(fat_progress, 1),
            "calories_remaining": round(calorie_target - total_calories, 1),
            "protein_remaining_g": round(protein_target - total_protein, 1),
            "carbs_remaining_g": round(carbs_target - total_carbs, 1),
            "fat_remaining_g": round(fat_target - total_fat, 1),
            "nutrition_score": score_breakdown.overall_score,
            "score_breakdown": {
                "calorie_adherence": score_breakdown.calorie_adherence_score,
                "macro_balance": score_breakdown.macro_balance_score,
                "consistency": score_breakdown.consistency_score,
            },
            "entries": entries,
            "entries_by_meal": entries_by_meal,
        }

    async def get_nutrition_score_for_wellness(
        self,
        user_id: UUID,
        target_date: date | None = None,
    ) -> float:
        """Get nutrition score for wellness calculation integration.

        Args:
            user_id: User's UUID
            target_date: Date to calculate score for

        Returns:
            Nutrition score (0-100)
        """
        summary = await self.get_daily_nutrition_summary(user_id, target_date)
        return summary.get("nutrition_score", 70.0)

    def _parse_date(self, date_str: str) -> date | None:
        """Parse ISO date string to date object."""
        if not date_str:
            return None
        try:
            # Handle various ISO formats
            dt_str = date_str.replace("Z", "+00:00")
            if "T" in dt_str:
                return datetime.fromisoformat(dt_str).date()
            return date.fromisoformat(dt_str)
        except (ValueError, TypeError):
            return None


# Singleton instance
_service: NutritionService | None = None


def get_nutrition_service() -> NutritionService:
    """Get or create the nutrition service instance."""
    global _service
    if _service is None:
        _service = NutritionService()
    return _service
