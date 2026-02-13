"""Meal plans API routes for recipes, templates, barcode lookups, and shopping lists."""

from datetime import date as Date
from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import JSONResponse
from uuid import UUID
from app.auth import get_current_user, CurrentUser
from app.services.meal_plan_service import get_meal_plan_service
from app.models.meal_plans import (
    RecipeListItem, RecipeResponse,
    MealPlanTemplateListItem, MealPlanTemplateResponse,
    QuickAddFromRecipeRequest, BarcodeProductResponse, ShoppingListItem,
    WeeklyMealPlanResponse, WeeklyMealPlanListItem,
    CreateWeeklyPlanRequest, UpsertWeeklyPlanItemRequest,
    AutoFillRequest, ApplyToPlanRequest,
    DayMacroSummary, WeeklyShoppingListItem, WeeklyPlanItemResponse,
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


# ─── Phase 9A: User Weekly Meal Plans ────────────────────────────────────────


@router.get("/weekly-plans", response_model=list[WeeklyMealPlanListItem])
async def list_weekly_plans(current_user: CurrentUser = Depends(get_current_user)):
    service = get_meal_plan_service()
    return service.get_weekly_plans(user_id=current_user.id)


@router.post("/weekly-plans", response_model=WeeklyMealPlanResponse, status_code=201)
async def create_weekly_plan(
    data: CreateWeeklyPlanRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    service = get_meal_plan_service()
    return service.create_weekly_plan(
        user_id=current_user.id,
        name=data.name,
        week_start_date=data.week_start_date,
        is_recurring=data.is_recurring,
    )


@router.get("/weekly-plans/for-week", response_model=WeeklyMealPlanResponse | None)
async def get_plan_for_week(
    week_start_date: Date = Query(...),
    current_user: CurrentUser = Depends(get_current_user),
):
    service = get_meal_plan_service()
    return service.get_weekly_plan_for_week(user_id=current_user.id, week_start_date=week_start_date)


@router.get("/weekly-plans/{plan_id}", response_model=WeeklyMealPlanResponse)
async def get_weekly_plan(plan_id: UUID, current_user: CurrentUser = Depends(get_current_user)):
    service = get_meal_plan_service()
    plan = service.get_weekly_plan(user_id=current_user.id, plan_id=plan_id)
    if not plan:
        raise HTTPException(status_code=404, detail="Weekly plan not found")
    return plan


@router.put("/weekly-plans/{plan_id}", response_model=WeeklyMealPlanResponse)
async def update_weekly_plan(
    plan_id: UUID,
    data: CreateWeeklyPlanRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    service = get_meal_plan_service()
    plan = service.update_weekly_plan(
        user_id=current_user.id,
        plan_id=plan_id,
        name=data.name,
        is_recurring=data.is_recurring,
    )
    if not plan:
        raise HTTPException(status_code=404, detail="Weekly plan not found")
    return plan


@router.delete("/weekly-plans/{plan_id}", status_code=204)
async def delete_weekly_plan(plan_id: UUID, current_user: CurrentUser = Depends(get_current_user)):
    service = get_meal_plan_service()
    deleted = service.delete_weekly_plan(user_id=current_user.id, plan_id=plan_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Weekly plan not found")
    return None


@router.put("/weekly-plans/{plan_id}/items", response_model=WeeklyPlanItemResponse)
async def upsert_plan_item(
    plan_id: UUID,
    data: UpsertWeeklyPlanItemRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    service = get_meal_plan_service()
    item = service.upsert_plan_item(
        user_id=current_user.id,
        plan_id=plan_id,
        day_of_week=data.day_of_week,
        meal_type=data.meal_type,
        recipe_id=data.recipe_id,
        servings=data.servings,
        sort_order=data.sort_order,
    )
    if not item:
        raise HTTPException(status_code=404, detail="Weekly plan not found")
    return item


@router.delete("/weekly-plans/{plan_id}/items/{item_id}", status_code=204)
async def delete_plan_item(
    plan_id: UUID,
    item_id: UUID,
    current_user: CurrentUser = Depends(get_current_user),
):
    service = get_meal_plan_service()
    deleted = service.delete_plan_item(user_id=current_user.id, plan_id=plan_id, item_id=item_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Plan item not found")
    return None


@router.post("/weekly-plans/{plan_id}/auto-fill", response_model=WeeklyMealPlanResponse)
async def auto_fill_from_template(
    plan_id: UUID,
    data: AutoFillRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    service = get_meal_plan_service()
    plan = service.auto_fill_from_template(
        user_id=current_user.id,
        plan_id=plan_id,
        template_id=data.template_id,
        mode=data.mode,
    )
    if not plan:
        raise HTTPException(status_code=404, detail="Weekly plan or template not found")
    return plan


@router.get("/weekly-plans/{plan_id}/macros", response_model=list[DayMacroSummary])
async def get_macro_summary(plan_id: UUID, current_user: CurrentUser = Depends(get_current_user)):
    service = get_meal_plan_service()
    return service.get_day_macro_summary(user_id=current_user.id, plan_id=plan_id)


@router.post("/weekly-plans/{plan_id}/apply")
async def apply_to_food_log(
    plan_id: UUID,
    data: ApplyToPlanRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    service = get_meal_plan_service()
    count = service.apply_plan_to_food_log(user_id=current_user.id, plan_id=plan_id, mode=data.mode)
    return {"entries_created": count}


@router.get("/weekly-plans/{plan_id}/shopping-list", response_model=list[WeeklyShoppingListItem])
async def get_weekly_shopping_list(plan_id: UUID, current_user: CurrentUser = Depends(get_current_user)):
    service = get_meal_plan_service()
    result = service.get_weekly_shopping_list(user_id=current_user.id, plan_id=plan_id)
    return result


@router.post("/weekly-plans/{plan_id}/copy-next-week", response_model=WeeklyMealPlanResponse)
async def copy_to_next_week(plan_id: UUID, current_user: CurrentUser = Depends(get_current_user)):
    service = get_meal_plan_service()
    plan = service.copy_plan_to_next_week(user_id=current_user.id, plan_id=plan_id)
    if not plan:
        raise HTTPException(status_code=404, detail="Weekly plan not found")
    return plan
