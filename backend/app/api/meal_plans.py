"""Meal plans API routes for recipes, templates, barcode lookups, and shopping lists."""

from fastapi import APIRouter, Depends, HTTPException, Query
from uuid import UUID
from app.auth import get_current_user, CurrentUser
from app.services.meal_plan_service import get_meal_plan_service
from app.models.meal_plans import (
    RecipeListItem, RecipeResponse,
    MealPlanTemplateListItem, MealPlanTemplateResponse,
    QuickAddFromRecipeRequest, BarcodeProductResponse, ShoppingListItem,
)

router = APIRouter()


@router.get("/recipes", response_model=list[RecipeListItem])
async def list_recipes(
    category: str | None = None,
    goal_type: str | None = None,
    search: str | None = None,
    tag: str | None = None,
    current_user: CurrentUser = Depends(get_current_user),
):
    service = get_meal_plan_service()
    return service.get_recipes(category=category, goal_type=goal_type, search=search, tag=tag)


@router.get("/recipes/{recipe_id}", response_model=RecipeResponse)
async def get_recipe(recipe_id: UUID, current_user: CurrentUser = Depends(get_current_user)):
    service = get_meal_plan_service()
    recipe = service.get_recipe(recipe_id)
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    return recipe


@router.get("/templates", response_model=list[MealPlanTemplateListItem])
async def list_templates(
    goal_type: str | None = None,
    current_user: CurrentUser = Depends(get_current_user),
):
    service = get_meal_plan_service()
    return service.get_meal_plan_templates(goal_type=goal_type)


@router.get("/templates/{template_id}", response_model=MealPlanTemplateResponse)
async def get_template(template_id: UUID, current_user: CurrentUser = Depends(get_current_user)):
    service = get_meal_plan_service()
    template = service.get_meal_plan_template(template_id)
    if not template:
        raise HTTPException(status_code=404, detail="Meal plan template not found")
    return template


@router.post("/quick-add")
async def quick_add_recipe(
    data: QuickAddFromRecipeRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    service = get_meal_plan_service()
    result = service.quick_add_recipe(
        user_id=current_user.id,
        recipe_id=data.recipe_id,
        meal_type=data.meal_type,
        servings=data.servings,
        logged_at=data.logged_at,
    )
    if not result:
        raise HTTPException(status_code=404, detail="Recipe not found")
    return result


@router.get("/suggestions", response_model=list[RecipeListItem])
async def get_suggestions(
    meal_type: str | None = None,
    current_user: CurrentUser = Depends(get_current_user),
):
    service = get_meal_plan_service()
    return service.get_suggested_recipes(user_id=current_user.id, meal_type=meal_type)


@router.get("/barcode/{barcode}", response_model=BarcodeProductResponse)
async def lookup_barcode(barcode: str, current_user: CurrentUser = Depends(get_current_user)):
    service = get_meal_plan_service()
    result = service.lookup_barcode(barcode)
    return result


@router.get("/templates/{template_id}/shopping-list", response_model=list[ShoppingListItem])
async def get_shopping_list(template_id: UUID, current_user: CurrentUser = Depends(get_current_user)):
    service = get_meal_plan_service()
    result = service.get_shopping_list(template_id)
    if result is None:
        raise HTTPException(status_code=404, detail="Template not found")
    return result
