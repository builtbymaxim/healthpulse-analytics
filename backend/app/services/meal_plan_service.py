"""Service layer for meal plans, recipes, barcode lookups, and shopping lists."""

import httpx
from uuid import UUID
from datetime import datetime, timezone
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
        goal_result = self.supabase.table("nutrition_goals").select("goal_type").eq("user_id", str(user_id)).maybe_single().execute()
        goal_type = goal_result.data["goal_type"] if goal_result and goal_result.data else None
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
        result = query.order("name").limit(20).execute()
        return result.data or []

    def lookup_barcode(self, barcode: str) -> dict:
        """Proxy to Open Food Facts API."""
        url = f"https://world.openfoodfacts.org/api/v2/product/{barcode}"
        params = {"fields": "product_name,brands,nutriments,image_url,serving_size"}
        try:
            with httpx.Client(timeout=10) as client:
                response = client.get(url, params=params)
                response.raise_for_status()
                data = response.json()
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


_service: MealPlanService | None = None


def get_meal_plan_service() -> MealPlanService:
    global _service
    if _service is None:
        _service = MealPlanService()
    return _service
