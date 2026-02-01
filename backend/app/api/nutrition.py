"""Nutrition and calorie tracking API endpoints."""

from datetime import date, timedelta
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query

from app.auth import get_current_user, CurrentUser
from app.services.nutrition_service import get_nutrition_service
from app.services.nutrition_calculator import get_nutrition_calculator
from app.models.nutrition import (
    PhysicalProfileUpdate,
    PhysicalProfileResponse,
    NutritionGoalCreate,
    NutritionGoalResponse,
    FoodEntryCreate,
    FoodEntryResponse,
    DailyNutritionSummary,
    CalorieTargets,
    MacroTargets,
    TargetCalculationRequest,
    NutritionGoalType,
)

router = APIRouter()


# Physical Profile Endpoints

@router.get("/physical-profile", response_model=PhysicalProfileResponse)
async def get_physical_profile(
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get user's physical profile data for BMR calculation."""
    service = get_nutrition_service()

    profile = await service.get_user_physical_profile(current_user.id)
    weight = await service.get_latest_weight(current_user.id)

    if not profile:
        return PhysicalProfileResponse(
            age=None,
            height_cm=None,
            gender=None,
            activity_level=None,
            latest_weight_kg=weight,
            profile_complete=False,
        )

    profile_complete = all([
        profile.get("age"),
        profile.get("height_cm"),
        profile.get("gender"),
        weight,
    ])

    return PhysicalProfileResponse(
        age=profile.get("age"),
        height_cm=profile.get("height_cm"),
        gender=profile.get("gender"),
        activity_level=profile.get("activity_level"),
        latest_weight_kg=weight,
        profile_complete=profile_complete,
    )


@router.put("/physical-profile", response_model=PhysicalProfileResponse)
async def update_physical_profile(
    data: PhysicalProfileUpdate,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Update physical profile data (age, height, gender, activity level)."""
    service = get_nutrition_service()

    await service.update_physical_profile(
        user_id=current_user.id,
        age=data.age,
        height_cm=data.height_cm,
        gender=data.gender.value,
        activity_level=data.activity_level.value,
    )

    # Get latest weight for response
    weight = await service.get_latest_weight(current_user.id)

    return PhysicalProfileResponse(
        age=data.age,
        height_cm=data.height_cm,
        gender=data.gender.value,
        activity_level=data.activity_level.value,
        latest_weight_kg=weight,
        profile_complete=weight is not None,
    )


# Nutrition Goals Endpoints

@router.post("/goals/preview", response_model=CalorieTargets)
async def preview_nutrition_targets(
    data: TargetCalculationRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Preview calculated targets for a goal type without saving.

    Useful for showing users what their targets would be before committing.
    If profile fields are provided in the request, they will be used instead
    of saved profile data for real-time preview during profile editing.
    """
    service = get_nutrition_service()
    calculator = get_nutrition_calculator()

    # Use provided values or fall back to saved profile
    profile = await service.get_user_physical_profile(current_user.id)

    # Determine values: use request overrides if provided, else saved profile
    age = data.age or (profile.get("age") if profile else None)
    height_cm = data.height_cm or (profile.get("height_cm") if profile else None)
    gender = data.gender or (profile.get("gender") if profile else None)
    activity_level = data.activity_level or (profile.get("activity_level") if profile else "moderate")

    if not all([age, height_cm, gender]):
        raise HTTPException(
            status_code=400,
            detail="Physical profile incomplete. Provide age, height, and gender."
        )

    weight = data.weight_kg or await service.get_latest_weight(current_user.id)
    if not weight:
        raise HTTPException(
            status_code=400,
            detail="No weight data available. Please provide weight_kg."
        )

    targets = calculator.calculate_targets(
        weight_kg=weight,
        height_cm=float(height_cm),
        age=int(age),
        gender=gender,
        activity_level=activity_level,
        goal_type=data.goal_type.value,
    )

    return CalorieTargets(
        bmr=targets.bmr,
        tdee=targets.tdee,
        calorie_target=targets.calorie_target,
        macros=MacroTargets(
            protein_g=targets.protein_g,
            carbs_g=targets.carbs_g,
            fat_g=targets.fat_g,
            protein_pct=targets.protein_pct,
            carbs_pct=targets.carbs_pct,
            fat_pct=targets.fat_pct,
        ),
        goal_type=data.goal_type,
        using_custom_values=False,
    )


@router.post("/goals", response_model=NutritionGoalResponse)
async def set_nutrition_goal(
    data: NutritionGoalCreate,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Set or update nutrition goal with calculated targets."""
    service = get_nutrition_service()

    try:
        goal = await service.create_or_update_nutrition_goal(
            user_id=current_user.id,
            goal_type=data.goal_type.value,
            custom_calorie_target=data.custom_calorie_target,
            custom_protein_g=data.custom_protein_target_g,
            custom_carbs_g=data.custom_carbs_target_g,
            custom_fat_g=data.custom_fat_target_g,
            adjust_for_activity=data.adjust_for_activity,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    if not goal:
        raise HTTPException(status_code=500, detail="Failed to save nutrition goal")

    return NutritionGoalResponse(**goal)


@router.get("/goals")
async def get_nutrition_goal(
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get current nutrition goal and targets."""
    service = get_nutrition_service()
    goal = await service.get_nutrition_goal(current_user.id)

    if not goal:
        return None

    return NutritionGoalResponse(**goal)


# Food Entry Endpoints

@router.post("/food", response_model=FoodEntryResponse)
async def log_food(
    entry: FoodEntryCreate,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Log a food entry with calories and macros."""
    service = get_nutrition_service()

    result = await service.log_food_entry(
        user_id=current_user.id,
        name=entry.name,
        calories=entry.calories,
        protein_g=entry.protein_g,
        carbs_g=entry.carbs_g,
        fat_g=entry.fat_g,
        fiber_g=entry.fiber_g,
        meal_type=entry.meal_type.value if entry.meal_type else None,
        serving_size=entry.serving_size,
        serving_unit=entry.serving_unit,
        logged_at=entry.logged_at,
        notes=entry.notes,
    )

    if not result:
        raise HTTPException(status_code=500, detail="Failed to log food entry")

    return FoodEntryResponse(**result)


@router.get("/food", response_model=list[FoodEntryResponse])
async def get_food_entries(
    target_date: date | None = Query(None, alias="date", description="Date to get entries for"),
    start_date: date | None = Query(None, description="Range start date"),
    end_date: date | None = Query(None, description="Range end date"),
    limit: int = Query(100, ge=1, le=500),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get food entries for a date or date range."""
    service = get_nutrition_service()

    entries = await service.get_food_entries(
        user_id=current_user.id,
        target_date=target_date,
        start_date=start_date,
        end_date=end_date,
        limit=limit,
    )

    return [FoodEntryResponse(**e) for e in entries]


@router.delete("/food/{entry_id}")
async def delete_food_entry(
    entry_id: UUID,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Delete a food entry."""
    service = get_nutrition_service()

    deleted = await service.delete_food_entry(current_user.id, entry_id)

    if not deleted:
        raise HTTPException(status_code=404, detail="Food entry not found")

    return {"message": "Food entry deleted", "id": str(entry_id)}


# Summary Endpoints

@router.get("/summary", response_model=DailyNutritionSummary)
async def get_daily_nutrition_summary(
    target_date: date | None = Query(None, alias="date", description="Date to get summary for"),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get daily nutrition summary with progress toward goals."""
    service = get_nutrition_service()

    summary = await service.get_daily_nutrition_summary(
        user_id=current_user.id,
        target_date=target_date,
    )

    # Convert entries to response models
    summary["entries"] = [FoodEntryResponse(**e) for e in summary.get("entries", [])]

    entries_by_meal = {}
    for meal, entries in summary.get("entries_by_meal", {}).items():
        entries_by_meal[meal] = [FoodEntryResponse(**e) for e in entries]
    summary["entries_by_meal"] = entries_by_meal

    return DailyNutritionSummary(**summary)


@router.get("/summary/weekly")
async def get_weekly_nutrition_summary(
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get nutrition summary for the past 7 days."""
    service = get_nutrition_service()
    summaries = []

    for i in range(7):
        target = date.today() - timedelta(days=i)
        summary = await service.get_daily_nutrition_summary(
            user_id=current_user.id,
            target_date=target,
        )
        # Simplify for weekly view (exclude full entries)
        summaries.append({
            "date": summary["date"],
            "total_calories": summary["total_calories"],
            "total_protein_g": summary["total_protein_g"],
            "total_carbs_g": summary["total_carbs_g"],
            "total_fat_g": summary["total_fat_g"],
            "calorie_target": summary["calorie_target"],
            "calorie_progress_pct": summary["calorie_progress_pct"],
            "nutrition_score": summary["nutrition_score"],
        })

    return summaries
