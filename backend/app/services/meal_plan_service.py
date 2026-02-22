"""Service layer for meal plans, recipes, barcode lookups, and shopping lists."""

import logging
import httpx

from app.utils.circuit_breaker import CircuitBreaker
from app.utils.retry import call_with_retry

logger = logging.getLogger(__name__)

# Circuit breaker for Open Food Facts: open after 5 failures, recover after 2 min
_barcode_cb = CircuitBreaker("openfoodfacts", failure_threshold=5, cooldown_seconds=120)
from uuid import UUID
from datetime import date, datetime, timedelta, timezone
from app.models.meal_plans import (
    RecipeListItem, RecipeResponse, RecipeIngredient,
    MealPlanTemplateListItem, MealPlanTemplateResponse, MealPlanItemResponse,
    BarcodeProductResponse, ShoppingListItem,
)


class MealPlanService:
    def __init__(self):
        from app.config import get_settings
        from supabase import create_client
        settings = get_settings()
        self.supabase = create_client(settings.supabase_url, settings.supabase_service_key)

    def get_recipes(self, category=None, goal_type=None, search=None, tag=None):
        query = self.supabase.table("recipes").select(
            "id, name, category, description, calories_per_serving, protein_g_per_serving, "
            "carbs_g_per_serving, fat_g_per_serving, fiber_g_per_serving, tags, goal_types, "
            "prep_time_min, cook_time_min"
        )
        if category:
            query = query.eq("category", category)
        if goal_type:
            query = query.contains("goal_types", [goal_type])
        if search:
            query = query.ilike("name", f"%{search}%")
        if tag:
            query = query.contains("tags", [tag])
        result = query.order("category").order("name").execute()
        return result.data or []

    def get_recipe(self, recipe_id: UUID):
        result = self.supabase.table("recipes").select("*").eq("id", str(recipe_id)).maybe_single().execute()
        return result.data if result and result.data else None

    # ─── Custom Recipe CRUD ──────────────────────────────────────────

    def create_custom_recipe(self, user_id: UUID, data: dict) -> dict:
        data["user_id"] = str(user_id)
        result = self.supabase.table("recipes").insert(data).execute()
        if not result.data:
            raise ValueError("Failed to create recipe")
        return result.data[0]

    def get_custom_recipes(self, user_id: UUID):
        result = (
            self.supabase.table("recipes")
            .select("id, name, category, description, calories_per_serving, protein_g_per_serving, "
                    "carbs_g_per_serving, fat_g_per_serving, fiber_g_per_serving, tags, goal_types, "
                    "prep_time_min, cook_time_min")
            .eq("user_id", str(user_id))
            .order("name")
            .execute()
        )
        return result.data or []

    def update_custom_recipe(self, user_id: UUID, recipe_id: UUID, data: dict) -> dict | None:
        result = (
            self.supabase.table("recipes")
            .update(data)
            .eq("id", str(recipe_id))
            .eq("user_id", str(user_id))
            .execute()
        )
        return result.data[0] if result.data else None

    def delete_custom_recipe(self, user_id: UUID, recipe_id: UUID) -> bool:
        result = (
            self.supabase.table("recipes")
            .delete()
            .eq("id", str(recipe_id))
            .eq("user_id", str(user_id))
            .execute()
        )
        return bool(result.data)

    def get_meal_plan_templates(self, goal_type=None):
        query = self.supabase.table("meal_plan_templates").select("*")
        if goal_type:
            query = query.eq("goal_type", goal_type)
        result = query.order("goal_type").order("name").execute()
        templates = result.data or []
        # Add item counts
        for t in templates:
            items_result = self.supabase.table("meal_plan_items").select("id", count="exact").eq("template_id", t["id"]).execute()
            t["item_count"] = items_result.count or 0
        return templates

    def get_meal_plan_template(self, template_id: UUID):
        # Fetch template
        result = self.supabase.table("meal_plan_templates").select("*").eq("id", str(template_id)).maybe_single().execute()
        template = result.data if result and result.data else None
        if not template:
            return None
        # Fetch items
        items_result = self.supabase.table("meal_plan_items").select("*").eq("template_id", str(template_id)).order("sort_order").execute()
        items = items_result.data or []
        # Fetch recipes for items
        recipe_ids = list(set(item["recipe_id"] for item in items))
        recipes_map = {}
        if recipe_ids:
            recipes_result = self.supabase.table("recipes").select(
                "id, name, category, description, calories_per_serving, protein_g_per_serving, "
                "carbs_g_per_serving, fat_g_per_serving, fiber_g_per_serving, tags, goal_types, "
                "prep_time_min, cook_time_min"
            ).in_("id", recipe_ids).execute()
            for r in (recipes_result.data or []):
                recipes_map[r["id"]] = r
        # Build response items with computed totals
        enriched_items = []
        for item in items:
            recipe = recipes_map.get(item["recipe_id"])
            servings = float(item.get("servings", 1))
            enriched_item = {
                **item,
                "recipe": recipe,
                "total_calories": round((recipe["calories_per_serving"] * servings), 1) if recipe else 0,
                "total_protein_g": round((recipe["protein_g_per_serving"] * servings), 1) if recipe else 0,
                "total_carbs_g": round((recipe["carbs_g_per_serving"] * servings), 1) if recipe else 0,
                "total_fat_g": round((recipe["fat_g_per_serving"] * servings), 1) if recipe else 0,
            }
            enriched_items.append(enriched_item)
        template["items"] = enriched_items
        return template

    def quick_add_recipe(self, user_id: UUID, recipe_id: UUID, meal_type: str, servings: float = 1, logged_at: datetime | None = None):
        # Fetch recipe
        recipe = self.get_recipe(recipe_id)
        if not recipe:
            return None
        # Calculate macros
        entry_data = {
            "user_id": str(user_id),
            "name": recipe["name"],
            "meal_type": meal_type,
            "calories": round(recipe["calories_per_serving"] * servings, 1),
            "protein_g": round(recipe["protein_g_per_serving"] * servings, 1),
            "carbs_g": round(recipe["carbs_g_per_serving"] * servings, 1),
            "fat_g": round(recipe["fat_g_per_serving"] * servings, 1),
            "fiber_g": round(recipe.get("fiber_g_per_serving", 0) * servings, 1),
            "serving_size": servings,
            "serving_unit": "serving",
            "source": "recipe",
            "notes": f"From recipe: {recipe['name']}",
        }
        if logged_at:
            entry_data["logged_at"] = logged_at.isoformat()
        result = self.supabase.table("food_entries").insert(entry_data).execute()
        return result.data[0] if result.data else None

    def get_suggested_recipes(self, user_id: UUID, meal_type: str | None = None):
        # Get user's goal type from nutrition_goals
        goal_result = self.supabase.table("nutrition_goals").select("goal_type, calorie_target").eq("user_id", str(user_id)).maybe_single().execute()
        goal_type = goal_result.data["goal_type"] if goal_result and goal_result.data else None
        calorie_target = goal_result.data.get("calorie_target") if goal_result and goal_result.data else None

        # Get user's dietary preferences from profile settings
        profile_result = self.supabase.table("profiles").select("settings").eq("id", str(user_id)).maybe_single().execute()
        settings = (profile_result.data or {}).get("settings") or {}
        dietary_pattern = settings.get("dietary_pattern")
        allergies = settings.get("allergies") or []
        meals_per_day = settings.get("meals_per_day") or 3

        # Fetch recipes
        query = self.supabase.table("recipes").select(
            "id, name, category, description, calories_per_serving, protein_g_per_serving, "
            "carbs_g_per_serving, fat_g_per_serving, fiber_g_per_serving, tags, goal_types, "
            "prep_time_min, cook_time_min"
        )
        if goal_type:
            query = query.contains("goal_types", [goal_type])
        if meal_type:
            query = query.eq("category", meal_type)

        # Apply dietary pattern filtering via tags
        if dietary_pattern and dietary_pattern != "omnivore":
            tag_map = {
                "vegan": "vegan",
                "vegetarian": "vegetarian",
                "pescatarian": "pescatarian",
                "keto": "keto",
            }
            if dietary_pattern in tag_map:
                query = query.contains("tags", [tag_map[dietary_pattern]])

        result = query.order("name").limit(50).execute()
        recipes = result.data or []

        # Filter out recipes containing allergens (tag-based exclusion)
        if allergies:
            allergen_tag_map = {
                "gluten": "gluten_free",
                "dairy": "dairy_free",
            }
            # For allergens that have a "free" tag, only keep recipes with that tag
            for allergy in allergies:
                free_tag = allergen_tag_map.get(allergy)
                if free_tag:
                    recipes = [r for r in recipes if free_tag in (r.get("tags") or [])]

        # Per-meal calorie budgeting: rank by proximity to budget
        if calorie_target and meals_per_day:
            per_meal_budget = calorie_target / meals_per_day
            budget_min = per_meal_budget * 0.5
            budget_max = per_meal_budget * 1.5
            # Prefer recipes within budget range, then sort by proximity
            in_budget = [r for r in recipes if budget_min <= r.get("calories_per_serving", 0) <= budget_max]
            out_budget = [r for r in recipes if r not in in_budget]
            in_budget.sort(key=lambda r: abs(r.get("calories_per_serving", 0) - per_meal_budget))
            recipes = in_budget + out_budget

        return recipes[:20]

    def lookup_barcode(self, barcode: str) -> dict:
        """Proxy to Open Food Facts API with retry and circuit breaker."""
        if _barcode_cb.is_open:
            logger.warning("Barcode lookup skipped — circuit open for openfoodfacts")
            return {"barcode": barcode, "found": False}

        url = f"https://world.openfoodfacts.org/api/v2/product/{barcode}"
        params = {"fields": "product_name,brands,nutriments,image_url,serving_size"}
        try:
            with httpx.Client(timeout=10) as client:
                response = call_with_retry(
                    client.get, url,
                    max_attempts=3,
                    base_delay=1.0,
                    exceptions=(httpx.HTTPError, httpx.TimeoutException),
                    params=params,
                )
                response.raise_for_status()
                data = response.json()
            _barcode_cb.record_success()
            if data.get("status") != 1 or not data.get("product"):
                return {"barcode": barcode, "found": False}
            product = data["product"]
            nutriments = product.get("nutriments", {})
            return {
                "barcode": barcode,
                "name": product.get("product_name"),
                "brand": product.get("brands"),
                "calories_per_100g": nutriments.get("energy-kcal_100g", 0) or 0,
                "protein_g_per_100g": nutriments.get("proteins_100g", 0) or 0,
                "carbs_g_per_100g": nutriments.get("carbohydrates_100g", 0) or 0,
                "fat_g_per_100g": nutriments.get("fat_100g", 0) or 0,
                "fiber_g_per_100g": nutriments.get("fiber_100g", 0) or 0,
                "serving_size": product.get("serving_size"),
                "image_url": product.get("image_url"),
                "found": True,
            }
        except Exception:
            _barcode_cb.record_failure()
            logger.warning("Barcode lookup failed for %s", barcode, exc_info=True)
            return {"barcode": barcode, "found": False}

    def get_shopping_list(self, template_id: UUID) -> list[dict]:
        """Get consolidated shopping list for a meal plan template."""
        template = self.get_meal_plan_template(template_id)
        if not template:
            return []
        # Aggregate ingredients across all items
        ingredient_map: dict[str, dict] = {}  # key: "name|unit"
        for item in template.get("items", []):
            recipe = item.get("recipe")
            if not recipe:
                continue
            # Need full recipe for ingredients
            full_recipe = self.get_recipe(recipe["id"])
            if not full_recipe or not full_recipe.get("ingredients"):
                continue
            servings_multiplier = float(item.get("servings", 1))
            for ing in full_recipe["ingredients"]:
                if isinstance(ing, dict):
                    key = f"{ing['name'].lower()}|{ing.get('unit', '')}"
                    if key in ingredient_map:
                        ingredient_map[key]["total_amount"] += ing.get("amount", 0) * servings_multiplier
                    else:
                        ingredient_map[key] = {
                            "name": ing["name"],
                            "total_amount": round(ing.get("amount", 0) * servings_multiplier, 1),
                            "unit": ing.get("unit", ""),
                        }
        return sorted(ingredient_map.values(), key=lambda x: x["name"])

    # ─── Phase 9A: User Weekly Meal Plans ────────────────────────────────

    def _enrich_items(self, items: list[dict]) -> list[dict]:
        """Batch-fetch recipes and compute macro totals for plan items."""
        if not items:
            return []
        recipe_ids = list(set(item["recipe_id"] for item in items))
        recipes_map: dict[str, dict] = {}
        if recipe_ids:
            recipes_result = self.supabase.table("recipes").select(
                "id, name, category, description, calories_per_serving, protein_g_per_serving, "
                "carbs_g_per_serving, fat_g_per_serving, fiber_g_per_serving, tags, goal_types, "
                "prep_time_min, cook_time_min"
            ).in_("id", recipe_ids).execute()
            for r in (recipes_result.data or []):
                recipes_map[r["id"]] = r
        enriched = []
        for item in items:
            recipe = recipes_map.get(item["recipe_id"])
            servings = float(item.get("servings", 1))
            enriched.append({
                **item,
                "recipe": recipe,
                "total_calories": round(recipe["calories_per_serving"] * servings, 1) if recipe else 0,
                "total_protein_g": round(recipe["protein_g_per_serving"] * servings, 1) if recipe else 0,
                "total_carbs_g": round(recipe["carbs_g_per_serving"] * servings, 1) if recipe else 0,
                "total_fat_g": round(recipe["fat_g_per_serving"] * servings, 1) if recipe else 0,
            })
        return enriched

    def get_weekly_plans(self, user_id: UUID) -> list[dict]:
        """List all weekly meal plans for a user."""
        result = self.supabase.table("user_weekly_meal_plans").select("*").eq(
            "user_id", str(user_id)
        ).order("week_start_date", desc=True).execute()
        plans = result.data or []
        for plan in plans:
            items_result = self.supabase.table("user_weekly_plan_items").select("*").eq(
                "plan_id", plan["id"]
            ).execute()
            items = items_result.data or []
            enriched = self._enrich_items(items)
            plan["item_count"] = len(items)
            plan["total_calories"] = round(sum(i.get("total_calories", 0) for i in enriched), 1)
        return plans

    def get_weekly_plan(self, user_id: UUID, plan_id: UUID) -> dict | None:
        """Get a single weekly plan with all enriched items."""
        result = self.supabase.table("user_weekly_meal_plans").select("*").eq(
            "id", str(plan_id)
        ).eq("user_id", str(user_id)).maybe_single().execute()
        plan = result.data if result and result.data else None
        if not plan:
            return None
        items_result = self.supabase.table("user_weekly_plan_items").select("*").eq(
            "plan_id", str(plan_id)
        ).order("day_of_week").order("sort_order").execute()
        plan["items"] = self._enrich_items(items_result.data or [])
        return plan

    def get_weekly_plan_for_week(self, user_id: UUID, week_start_date) -> dict | None:
        """Get the weekly plan for a specific week start date."""
        result = self.supabase.table("user_weekly_meal_plans").select("*").eq(
            "user_id", str(user_id)
        ).eq("week_start_date", str(week_start_date)).maybe_single().execute()
        plan = result.data if result and result.data else None
        if not plan:
            return None
        items_result = self.supabase.table("user_weekly_plan_items").select("*").eq(
            "plan_id", plan["id"]
        ).order("day_of_week").order("sort_order").execute()
        plan["items"] = self._enrich_items(items_result.data or [])
        return plan

    def create_weekly_plan(self, user_id: UUID, name: str, week_start_date, is_recurring: bool = False) -> dict:
        """Create a new weekly meal plan."""
        data = {
            "user_id": str(user_id),
            "name": name,
            "week_start_date": str(week_start_date),
            "is_recurring": is_recurring,
        }
        result = self.supabase.table("user_weekly_meal_plans").insert(data).execute()
        plan = result.data[0] if result.data else data
        plan["items"] = []
        return plan

    def update_weekly_plan(self, user_id: UUID, plan_id: UUID, **kwargs) -> dict | None:
        """Update allowed fields on a weekly plan (name, is_recurring)."""
        allowed = {k: v for k, v in kwargs.items() if k in ("name", "is_recurring") and v is not None}
        if not allowed:
            return self.get_weekly_plan(user_id, plan_id)
        self.supabase.table("user_weekly_meal_plans").update(allowed).eq(
            "id", str(plan_id)
        ).eq("user_id", str(user_id)).execute()
        return self.get_weekly_plan(user_id, plan_id)

    def delete_weekly_plan(self, user_id: UUID, plan_id: UUID) -> bool:
        """Delete a weekly plan by id and user_id."""
        result = self.supabase.table("user_weekly_meal_plans").delete().eq(
            "id", str(plan_id)
        ).eq("user_id", str(user_id)).execute()
        return bool(result.data)

    def upsert_plan_item(
        self, user_id: UUID, plan_id: UUID, day_of_week: int,
        meal_type: str, recipe_id: UUID, servings: float = 1, sort_order: int = 0,
    ) -> dict | None:
        """Replace the item in a given (plan, day, meal_type) slot."""
        # Verify plan ownership
        plan_check = self.supabase.table("user_weekly_meal_plans").select("id").eq(
            "id", str(plan_id)
        ).eq("user_id", str(user_id)).maybe_single().execute()
        if not (plan_check and plan_check.data):
            return None
        # Remove existing item in that slot
        self.supabase.table("user_weekly_plan_items").delete().eq(
            "plan_id", str(plan_id)
        ).eq("day_of_week", day_of_week).eq("meal_type", meal_type).execute()
        # Insert new item
        new_item = {
            "plan_id": str(plan_id),
            "day_of_week": day_of_week,
            "meal_type": meal_type,
            "recipe_id": str(recipe_id),
            "servings": servings,
            "sort_order": sort_order,
        }
        result = self.supabase.table("user_weekly_plan_items").insert(new_item).execute()
        item = result.data[0] if result.data else new_item
        enriched = self._enrich_items([item])
        return enriched[0] if enriched else item

    def delete_plan_item(self, user_id: UUID, plan_id: UUID, item_id: UUID) -> bool:
        """Delete a single item from a weekly plan, verifying ownership."""
        plan_check = self.supabase.table("user_weekly_meal_plans").select("id").eq(
            "id", str(plan_id)
        ).eq("user_id", str(user_id)).maybe_single().execute()
        if not (plan_check and plan_check.data):
            return False
        result = self.supabase.table("user_weekly_plan_items").delete().eq(
            "id", str(item_id)
        ).eq("plan_id", str(plan_id)).execute()
        return bool(result.data)

    def auto_fill_from_template(
        self, user_id: UUID, plan_id: UUID, template_id: UUID, mode: str = "repeat",
    ) -> dict | None:
        """Auto-fill a weekly plan from a meal plan template."""
        # Verify plan ownership
        plan_check = self.supabase.table("user_weekly_meal_plans").select("id").eq(
            "id", str(plan_id)
        ).eq("user_id", str(user_id)).maybe_single().execute()
        if not (plan_check and plan_check.data):
            return None
        # Get template with items
        template = self.get_meal_plan_template(template_id)
        if not template:
            return None
        template_items = template.get("items", [])
        if not template_items:
            return self.get_weekly_plan(user_id, plan_id)
        # Clear existing items
        self.supabase.table("user_weekly_plan_items").delete().eq(
            "plan_id", str(plan_id)
        ).execute()
        # Build new items
        new_items = []
        if mode == "repeat":
            for day in range(1, 8):
                for idx, t_item in enumerate(template_items):
                    new_items.append({
                        "plan_id": str(plan_id),
                        "day_of_week": day,
                        "meal_type": t_item.get("meal_type", "lunch"),
                        "recipe_id": t_item["recipe_id"],
                        "servings": float(t_item.get("servings", 1)),
                        "sort_order": idx,
                    })
        elif mode == "rotate":
            # Group template items by meal_type
            by_meal: dict[str, list[dict]] = {}
            for t_item in template_items:
                mt = t_item.get("meal_type", "lunch")
                by_meal.setdefault(mt, []).append(t_item)
            for day in range(1, 8):
                for mt, mt_items in by_meal.items():
                    picked = mt_items[(day - 1) % len(mt_items)]
                    new_items.append({
                        "plan_id": str(plan_id),
                        "day_of_week": day,
                        "meal_type": mt,
                        "recipe_id": picked["recipe_id"],
                        "servings": float(picked.get("servings", 1)),
                        "sort_order": 0,
                    })
        # Bulk insert
        if new_items:
            self.supabase.table("user_weekly_plan_items").insert(new_items).execute()
        return self.get_weekly_plan(user_id, plan_id)

    def get_day_macro_summary(self, user_id: UUID, plan_id: UUID) -> list[dict]:
        """Aggregate macros by day_of_week for a weekly plan, with goal comparison."""
        plan = self.get_weekly_plan(user_id, plan_id)
        if not plan:
            return []

        # Fetch user's nutrition goal for comparison
        goal_result = self.supabase.table("nutrition_goals").select(
            "calorie_target, protein_target_g"
        ).eq("user_id", str(user_id)).maybe_single().execute()
        goal = goal_result.data if goal_result and goal_result.data else None
        target_cal = goal.get("calorie_target") if goal else None
        target_protein = goal.get("protein_target_g") if goal else None

        day_map: dict[int, dict] = {}
        for item in plan.get("items", []):
            d = item.get("day_of_week", 1)
            if d not in day_map:
                day_map[d] = {
                    "day_of_week": d,
                    "total_calories": 0,
                    "total_protein_g": 0,
                    "total_carbs_g": 0,
                    "total_fat_g": 0,
                }
            day_map[d]["total_calories"] += item.get("total_calories", 0)
            day_map[d]["total_protein_g"] += item.get("total_protein_g", 0)
            day_map[d]["total_carbs_g"] += item.get("total_carbs_g", 0)
            day_map[d]["total_fat_g"] += item.get("total_fat_g", 0)
        # Round values and add goal comparison
        for d in day_map.values():
            d["total_calories"] = round(d["total_calories"], 1)
            d["total_protein_g"] = round(d["total_protein_g"], 1)
            d["total_carbs_g"] = round(d["total_carbs_g"], 1)
            d["total_fat_g"] = round(d["total_fat_g"], 1)
            if target_cal:
                d["target_calories"] = target_cal
                d["calorie_diff"] = round(d["total_calories"] - target_cal, 1)
            if target_protein:
                d["target_protein_g"] = target_protein
                d["protein_diff"] = round(d["total_protein_g"] - target_protein, 1)
            if target_cal:
                d["on_track"] = abs(d["total_calories"] - target_cal) <= target_cal * 0.1
        return sorted(day_map.values(), key=lambda x: x["day_of_week"])

    def apply_plan_to_food_log(self, user_id: UUID, plan_id: UUID, mode: str) -> int:
        """Apply weekly plan items to food_entries. Returns count of entries created."""
        plan = self.get_weekly_plan(user_id, plan_id)
        if not plan:
            return 0
        items = plan.get("items", [])
        if not items:
            return 0
        week_start = plan["week_start_date"]
        if isinstance(week_start, str):
            week_start = date.fromisoformat(week_start)
        # Determine today's ISO weekday (Mon=1..Sun=7)
        today = date.today()
        today_iso_weekday = today.isoweekday()
        if mode == "today":
            items = [i for i in items if i.get("day_of_week") == today_iso_weekday]
        # Meal time mapping
        meal_times = {
            "breakfast": "08:00:00",
            "lunch": "12:30:00",
            "dinner": "19:00:00",
            "snack": "15:30:00",
        }
        entries = []
        for item in items:
            day_offset = item.get("day_of_week", 1) - 1
            entry_date = week_start + timedelta(days=day_offset)
            meal_type = item.get("meal_type", "lunch")
            time_str = meal_times.get(meal_type, "12:00:00")
            logged_at = f"{entry_date}T{time_str}"
            recipe = item.get("recipe")
            recipe_name = recipe["name"] if recipe else "Unknown"
            entries.append({
                "user_id": str(user_id),
                "name": recipe_name,
                "meal_type": meal_type,
                "calories": item.get("total_calories", 0),
                "protein_g": item.get("total_protein_g", 0),
                "carbs_g": item.get("total_carbs_g", 0),
                "fat_g": item.get("total_fat_g", 0),
                "source": "meal_plan",
                "logged_at": logged_at,
            })
        if entries:
            self.supabase.table("food_entries").insert(entries).execute()
        return len(entries)

    def get_weekly_shopping_list(self, user_id: UUID, plan_id: UUID) -> list[dict]:
        """Get consolidated shopping list for a weekly plan."""
        plan = self.get_weekly_plan(user_id, plan_id)
        if not plan:
            return []
        ingredient_map: dict[str, dict] = {}
        for item in plan.get("items", []):
            recipe = item.get("recipe")
            if not recipe:
                continue
            full_recipe = self.get_recipe(recipe["id"])
            if not full_recipe or not full_recipe.get("ingredients"):
                continue
            servings_multiplier = float(item.get("servings", 1))
            for ing in full_recipe["ingredients"]:
                if isinstance(ing, dict):
                    key = f"{ing['name'].lower()}|{ing.get('unit', '')}"
                    if key in ingredient_map:
                        ingredient_map[key]["total_amount"] += ing.get("amount", 0) * servings_multiplier
                    else:
                        ingredient_map[key] = {
                            "name": ing["name"],
                            "total_amount": round(ing.get("amount", 0) * servings_multiplier, 1),
                            "unit": ing.get("unit", ""),
                        }
        # Round final amounts
        for v in ingredient_map.values():
            v["total_amount"] = round(v["total_amount"], 1)
        return sorted(ingredient_map.values(), key=lambda x: x["name"])

    def copy_plan_to_next_week(self, user_id: UUID, plan_id: UUID) -> dict | None:
        """Copy a weekly plan to the following week (next Monday)."""
        plan = self.get_weekly_plan(user_id, plan_id)
        if not plan:
            return None
        week_start = plan["week_start_date"]
        if isinstance(week_start, str):
            week_start = date.fromisoformat(week_start)
        next_monday = week_start + timedelta(days=7)
        # Delete existing plan for next week if any
        existing = self.supabase.table("user_weekly_meal_plans").select("id").eq(
            "user_id", str(user_id)
        ).eq("week_start_date", str(next_monday)).maybe_single().execute()
        if existing and existing.data:
            self.supabase.table("user_weekly_meal_plans").delete().eq(
                "id", existing.data["id"]
            ).execute()
        # Create new plan
        new_plan = self.create_weekly_plan(
            user_id=user_id,
            name=plan.get("name", "Weekly Plan"),
            week_start_date=next_monday,
            is_recurring=plan.get("is_recurring", False),
        )
        # Copy items
        items = plan.get("items", [])
        if items:
            new_items = []
            for item in items:
                new_items.append({
                    "plan_id": new_plan["id"],
                    "day_of_week": item["day_of_week"],
                    "meal_type": item["meal_type"],
                    "recipe_id": item["recipe_id"],
                    "servings": float(item.get("servings", 1)),
                    "sort_order": item.get("sort_order", 0),
                })
            self.supabase.table("user_weekly_plan_items").insert(new_items).execute()
        return self.get_weekly_plan(user_id, UUID(new_plan["id"]))


_service: MealPlanService | None = None


def get_meal_plan_service() -> MealPlanService:
    global _service
    if _service is None:
        _service = MealPlanService()
    return _service
