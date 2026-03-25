"""Nutrition and calorie tracking API endpoints."""

import logging
from datetime import date, datetime, timedelta
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query

from app.auth import get_current_user, CurrentUser
from app.services.nutrition_service import get_nutrition_service
from app.services.nutrition_calculator import get_nutrition_calculator, DailyTargets
from app.services.food_scan_service import get_food_scan_service
from app.models.nutrition import (
    PhysicalProfileUpdate,
    PhysicalProfileResponse,
    NutritionGoalCreate,
    NutritionGoalResponse,
    FoodEntryCreate,
    FoodEntryResponse,
    FoodEntryUpdate,
    DailyNutritionSummary,
    DailyTargetsResponse,
    CalorieTargets,
    MacroTargets,
    TargetCalculationRequest,
    GoalTimelineRequest,
    GoalTimelineResponse,
    NutritionGoalType,
)
from app.models.food_scan import FoodScanRequest, FoodScanResponse

logger = logging.getLogger(__name__)

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

    # Auto-recalculate nutrition goal when profile changes
    existing_goal = await service.get_nutrition_goal(current_user.id)
    if existing_goal and weight:
        try:
            await service.create_or_update_nutrition_goal(
                user_id=current_user.id,
                goal_type=existing_goal["goal_type"],
                custom_calorie_target=existing_goal.get("custom_calorie_target"),
                custom_protein_g=existing_goal.get("custom_protein_target_g"),
                custom_carbs_g=existing_goal.get("custom_carbs_target_g"),
                custom_fat_g=existing_goal.get("custom_fat_target_g"),
                adjust_for_activity=existing_goal.get("adjust_for_activity", True),
            )
            logger.info("Auto-recalculated nutrition goal after profile update for user %s", current_user.id)
        except Exception:
            logger.warning("Failed to auto-recalculate goal for user %s", current_user.id, exc_info=True)

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


# Daily Targets (Calorie Cycling)

@router.get("/daily-targets", response_model=DailyTargetsResponse)
async def get_daily_targets(
    target_date: date | None = Query(None, alias="date", description="Date to get targets for"),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get cycling-aware daily nutrition targets.

    Checks the user's active training plan to determine if the date is a
    training day or rest day, then returns adjusted calorie and macro targets.
    Training days get +10% calories with higher carbs; rest days get the
    compensating reduction with higher protein and fat.
    """
    service = get_nutrition_service()

    try:
        result = await service.get_daily_targets(
            user_id=current_user.id,
            target_date=target_date,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    return DailyTargetsResponse(**result)


# Goal Timeline Validation

@router.post("/goals/validate-timeline", response_model=GoalTimelineResponse)
async def validate_goal_timeline(
    data: GoalTimelineRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Validate a weight goal timeline against safe rate boundaries.

    Returns safety assessment with color-coded level (green/yellow/orange/red)
    and a suggested minimum timeframe if the requested pace is unsafe.
    """
    service = get_nutrition_service()
    calculator = get_nutrition_calculator()

    # Get profile for BMR/TDEE calculation
    profile = await service.get_user_physical_profile(current_user.id)
    if not profile or not all([profile.get("age"), profile.get("height_cm"), profile.get("gender")]):
        raise HTTPException(status_code=400, detail="Physical profile incomplete.")

    gender = data.gender or profile.get("gender", "other")
    body_fat_pct = await service._get_latest_body_fat(current_user.id)

    bmr, _ = calculator.calculate_bmr(
        weight_kg=data.current_weight_kg,
        height_cm=float(profile["height_cm"]),
        age=int(profile["age"]),
        gender=gender,
        body_fat_pct=body_fat_pct,
    )
    tdee = calculator.calculate_tdee(bmr, profile.get("activity_level", "moderate"))

    result = calculator.validate_goal_timeline(
        current_weight_kg=data.current_weight_kg,
        target_weight_kg=data.target_weight_kg,
        timeframe_days=data.timeframe_days,
        gender=gender,
        bmr=bmr,
        tdee=tdee,
    )

    return GoalTimelineResponse(
        is_safe=result.is_safe,
        weekly_rate_kg=result.weekly_rate_kg,
        weekly_rate_pct=result.weekly_rate_pct,
        daily_adjustment_kcal=result.daily_adjustment_kcal,
        suggested_min_weeks=result.suggested_min_weeks,
        safety_level=result.safety_level,
        message=result.message,
        calorie_target=result.calorie_target,
        calorie_floor_applied=result.calorie_floor_applied,
    )


# Food Entry Endpoints


@router.post("/food/scan", response_model=FoodScanResponse)
async def scan_food(
    request: FoodScanRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Analyze a food photo using vision AI and return identified items with macros."""
    service = get_food_scan_service()
    try:
        result = await service.analyze_food(
            image_base64=request.image_base64,
            hints=request.classification_hints,
        )
        return FoodScanResponse(**result)
    except Exception as e:
        logger.error("Food scan failed for user %s: %s", current_user.id, e)
        raise HTTPException(status_code=502, detail="Vision API error")


@router.get("/food/recent")
async def get_recent_foods(
    limit: int = Query(10, ge=1, le=20),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get the user's most recently logged foods, deduplicated by name.

    Returns up to `limit` distinct foods ordered by most-recently logged,
    with per-100g macro values and a frequency count.
    """
    service = get_nutrition_service()
    return await service.get_recent_foods(current_user.id, limit=limit)


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
        source=entry.source,
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


@router.put("/food/{entry_id}", response_model=FoodEntryResponse)
async def update_food_entry(
    entry_id: UUID,
    data: FoodEntryUpdate,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Update an existing food entry. Only provided fields are updated."""
    service = get_nutrition_service()

    # Build update dict from non-None fields
    update_data = {}
    if data.name is not None:
        update_data["name"] = data.name
    if data.meal_type is not None:
        update_data["meal_type"] = data.meal_type.value
    if data.calories is not None:
        update_data["calories"] = data.calories
    if data.protein_g is not None:
        update_data["protein_g"] = data.protein_g
    if data.carbs_g is not None:
        update_data["carbs_g"] = data.carbs_g
    if data.fat_g is not None:
        update_data["fat_g"] = data.fat_g
    if data.fiber_g is not None:
        update_data["fiber_g"] = data.fiber_g
    if data.serving_size is not None:
        update_data["serving_size"] = data.serving_size
    if data.serving_unit is not None:
        update_data["serving_unit"] = data.serving_unit
    if data.notes is not None:
        update_data["notes"] = data.notes

    if not update_data:
        raise HTTPException(status_code=400, detail="No fields to update")

    result = await service.update_food_entry(
        user_id=current_user.id,
        entry_id=entry_id,
        update_data=update_data,
    )

    if not result:
        raise HTTPException(status_code=404, detail="Food entry not found")

    return FoodEntryResponse(**result)


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


# Readiness-Adjusted Targets

@router.get("/readiness-targets")
async def get_readiness_targets(
    target_date: date | None = Query(None, alias="date", description="Date to get targets for"),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get recovery-adjusted nutrition targets with deficit status.

    Combines cycling-aware daily targets with readiness/recovery data to
    produce adjusted macro targets, plus a live deficit radar showing
    current consumption vs adjusted targets.
    """
    from app.database import get_supabase_client
    from app.services.dashboard_service import get_dashboard_service

    service = get_nutrition_service()
    calculator = get_nutrition_calculator()
    supabase = get_supabase_client()
    target = target_date or date.today()

    # 1. Get cycling-aware base targets
    try:
        base_result = await service.get_daily_targets(
            user_id=current_user.id,
            target_date=target,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    base_targets = DailyTargets(
        calories=base_result["calories"],
        protein_g=base_result["protein_g"],
        carbs_g=base_result["carbs_g"],
        fat_g=base_result["fat_g"],
        is_training_day=base_result["is_training_day"],
        protein_pct=base_result["protein_pct"],
        carbs_pct=base_result["carbs_pct"],
        fat_pct=base_result["fat_pct"],
    )

    # 2. Get recovery/readiness data
    readiness_score = 70.0  # default
    sleep_deficit_hours = 0.0
    try:
        dashboard = get_dashboard_service()
        recovery = await dashboard._get_enhanced_recovery(current_user.id)
        readiness_score = recovery.score
        sleep_deficit_hours = recovery.sleep_deficit_hours or 0.0
    except Exception:
        logger.warning("Could not fetch recovery data for readiness targets", exc_info=True)

    # 3. Get last 7 days of workouts for training load + yesterday's workout type
    training_load_7d = 0.0
    yesterday_workout_type = None
    try:
        week_ago = (datetime.now() - timedelta(days=7)).isoformat()
        workouts_result = (
            supabase.table("workouts")
            .select("training_load, workout_type, planned_workout_name, start_time")
            .eq("user_id", str(current_user.id))
            .gte("start_time", week_ago)
            .order("start_time", desc=True)
            .execute()
        )
        workouts = workouts_result.data or []
        training_load_7d = sum(float(w.get("training_load") or 0) for w in workouts)

        # Find yesterday's workout type
        yesterday = (target - timedelta(days=1)).isoformat()
        today_str = target.isoformat()
        for w in workouts:
            st = w.get("start_time", "")
            if st >= yesterday and st < today_str:
                yesterday_workout_type = (
                    w.get("planned_workout_name") or w.get("workout_type")
                )
                break
    except Exception:
        logger.warning("Could not fetch workout data for readiness targets", exc_info=True)

    # 4. Calculate recovery-adjusted targets
    adjusted = calculator.recovery_adjusted_targets(
        base_targets=base_targets,
        readiness_score=readiness_score,
        sleep_deficit_hours=sleep_deficit_hours,
        training_load_7d=training_load_7d,
        is_training_day=base_targets.is_training_day,
        yesterday_workout_type=yesterday_workout_type,
    )

    # 5. Get nutrition summary for deficit calculation
    summary = await service.get_daily_nutrition_summary(
        user_id=current_user.id,
        target_date=target,
    )
    calories_consumed = summary["total_calories"]
    protein_consumed = summary["total_protein_g"]

    calories_remaining = adjusted.calories - calories_consumed
    protein_remaining = adjusted.protein_g - protein_consumed

    # Urgency logic based on time of day
    now_hour = datetime.now().hour
    cal_pct_remaining = (calories_remaining / adjusted.calories * 100) if adjusted.calories > 0 else 0

    if cal_pct_remaining <= 30 or now_hour < 12:
        urgency = "on_track"
    elif cal_pct_remaining > 50 and now_hour >= 18:
        urgency = "critical"
    elif cal_pct_remaining > 30 and now_hour >= 12:
        urgency = "behind"
    else:
        urgency = "on_track"

    # Build deficit message
    if urgency == "on_track":
        message = "You're on track with your nutrition today."
    elif protein_remaining > 20:
        message = f"You need {protein_remaining:.0f}g more protein for recovery."
    else:
        message = f"You have {calories_remaining:.0f} kcal remaining today."

    return {
        "date": target.isoformat(),
        "readiness_score": round(readiness_score, 1),
        "is_training_day": base_targets.is_training_day,
        "base": {
            "calories": base_targets.calories,
            "protein_g": base_targets.protein_g,
            "carbs_g": base_targets.carbs_g,
            "fat_g": base_targets.fat_g,
            "is_training_day": base_targets.is_training_day,
        },
        "adjusted": {
            "calories": adjusted.calories,
            "protein_g": adjusted.protein_g,
            "carbs_g": adjusted.carbs_g,
            "fat_g": adjusted.fat_g,
            "is_training_day": base_targets.is_training_day,
        },
        "adjustments": [
            {
                "factor": a.factor,
                "adjustment": a.adjustment,
                "explanation": a.explanation,
            }
            for a in adjusted.adjustments
        ],
        "deficit": {
            "calories_consumed": round(calories_consumed, 1),
            "calories_target": adjusted.calories,
            "calories_remaining": round(calories_remaining, 1),
            "protein_consumed_g": round(protein_consumed, 1),
            "protein_target_g": adjusted.protein_g,
            "protein_remaining_g": round(protein_remaining, 1),
            "urgency": urgency,
            "message": message,
        },
    }
