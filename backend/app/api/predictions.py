"""ML predictions and insights endpoints."""

import logging
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from datetime import datetime, date
from uuid import UUID, uuid4
from enum import Enum

logger = logging.getLogger(__name__)

from app.auth import get_current_user, CurrentUser
from app.database import get_supabase_client
from app.services.prediction_service import get_prediction_service
from app.services.dashboard_service import (
    get_dashboard_service,
    DashboardResponse,
)

router = APIRouter()


class PredictionType(str, Enum):
    """Types of predictions available."""
    RECOVERY_SCORE = "recovery_score"
    READINESS_SCORE = "readiness_score"
    SLEEP_QUALITY = "sleep_quality"
    TRAINING_LOAD = "training_load"
    WELLNESS_TREND = "wellness_trend"


class InsightCategory(str, Enum):
    """Categories of insights."""
    CORRELATION = "correlation"
    ANOMALY = "anomaly"
    TREND = "trend"
    RECOMMENDATION = "recommendation"
    ACHIEVEMENT = "achievement"


# Response Models
class RecoveryPrediction(BaseModel):
    """Recovery score prediction with details."""
    score: float = Field(ge=0, le=100, description="Recovery score 0-100")
    confidence: float = Field(ge=0, le=1)
    status: str  # "recovered", "moderate", "fatigued"
    contributing_factors: dict
    recommendations: list[str]


class ReadinessPrediction(BaseModel):
    """Readiness score for training."""
    score: float = Field(ge=0, le=100)
    confidence: float = Field(ge=0, le=1)
    recommended_intensity: str  # "rest", "light", "moderate", "hard"
    factors: dict
    suggested_workout_types: list[str]


class WellnessScoreBreakdown(BaseModel):
    """Daily wellness score with breakdown."""
    date: date
    overall_score: float = Field(ge=0, le=100)
    components: dict  # sleep_score, activity_score, recovery_score, etc.
    trend: str  # "improving", "stable", "declining"
    comparison_to_baseline: float


class CorrelationInsight(BaseModel):
    """Correlation discovery insight."""
    factor_a: str
    factor_b: str
    correlation: float = Field(ge=-1, le=1)
    insight: str
    data_points: int
    confidence: float


class InsightResponse(BaseModel):
    """AI-generated insight."""
    id: UUID
    category: InsightCategory
    title: str
    description: str
    data: dict | None = None
    created_at: datetime


class AnalysisResponse(BaseModel):
    """Response from triggering analysis."""
    status: str
    message: str
    predictions_updated: list[str]


# Endpoints
@router.get("/recovery", response_model=RecoveryPrediction)
async def get_recovery_prediction(
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get current recovery score prediction.

    Calculates recovery based on:
    - Sleep duration and quality
    - Heart rate variability (HRV)
    - Resting heart rate
    - Recent training load
    - Stress levels
    """
    service = get_prediction_service()
    result = await service.get_recovery_prediction(current_user.id)

    return RecoveryPrediction(
        score=result["score"],
        confidence=result["confidence"],
        status=result["status"],
        contributing_factors=result["contributing_factors"],
        recommendations=result["recommendations"],
    )


@router.get("/readiness", response_model=ReadinessPrediction)
async def get_readiness_prediction(
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get training readiness prediction.

    Determines optimal workout intensity based on:
    - Current recovery status
    - Sleep quality
    - Days since last hard workout
    - Energy levels
    - Muscle soreness
    """
    service = get_prediction_service()
    result = await service.get_readiness_prediction(current_user.id)

    return ReadinessPrediction(
        score=result["score"],
        confidence=result["confidence"],
        recommended_intensity=result["recommended_intensity"],
        factors=result["factors"],
        suggested_workout_types=result["suggested_workout_types"],
    )


@router.get("/wellness", response_model=WellnessScoreBreakdown)
async def get_wellness_score(
    target_date: date | None = Query(None, description="Date to get score for (defaults to today)"),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get wellness score with breakdown.

    Overall wellness is calculated from:
    - Sleep (25%)
    - Activity (20%)
    - Recovery (20%)
    - Nutrition (15%)
    - Stress management (10%)
    - Mood (10%)
    """
    service = get_prediction_service()
    result = await service.get_wellness_score(current_user.id, target_date)

    return WellnessScoreBreakdown(
        date=target_date or date.today(),
        overall_score=result["overall_score"],
        components=result["components"],
        trend=result["trend"],
        comparison_to_baseline=result["comparison_to_baseline"],
    )


@router.get("/wellness/history", response_model=list[WellnessScoreBreakdown])
async def get_wellness_history(
    days: int = Query(30, ge=1, le=365, description="Number of days of history"),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get wellness score history."""
    service = get_prediction_service()
    history = await service.get_wellness_history(current_user.id, days)

    return [
        WellnessScoreBreakdown(
            date=date.fromisoformat(h["date"]) if isinstance(h["date"], str) else h["date"],
            overall_score=h["overall_score"],
            components=h["components"],
            trend=h["trend"],
            comparison_to_baseline=h["comparison_to_baseline"],
        )
        for h in history
    ]


@router.get("/correlations", response_model=list[CorrelationInsight])
async def get_correlations(
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get discovered correlations in user's data.

    Analyzes the past 30 days of health metrics to find
    meaningful relationships between different factors.
    """
    service = get_prediction_service()
    correlations = await service.analyze_correlations(current_user.id)

    return [
        CorrelationInsight(
            factor_a=c["factor_a"],
            factor_b=c["factor_b"],
            correlation=c["correlation"],
            insight=c["insight"],
            data_points=c["data_points"],
            confidence=c["confidence"],
        )
        for c in correlations
    ]


@router.get("/insights", response_model=list[InsightResponse])
async def get_insights(
    category: InsightCategory | None = Query(None, description="Filter by category"),
    limit: int = Query(10, ge=1, le=50),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get AI-generated insights.

    Returns personalized insights based on:
    - Discovered correlations
    - Trend analysis
    - Anomaly detection
    - Achievement tracking
    """
    # Generate insights from predictions and correlations
    service = get_prediction_service()
    insights = []

    # Get recovery and generate insight
    try:
        recovery = await service.get_recovery_prediction(current_user.id)
        if recovery["score"] >= 85:
            insights.append(InsightResponse(
                id=uuid4(),
                category=InsightCategory.RECOMMENDATION,
                title="Peak Recovery",
                description=f"Your recovery score is {recovery['score']}. This is an excellent day for a challenging workout!",
                data={"recovery_score": recovery["score"]},
                created_at=datetime.now(),
            ))
        elif recovery["score"] < 50:
            insights.append(InsightResponse(
                id=uuid4(),
                category=InsightCategory.RECOMMENDATION,
                title="Recovery Needed",
                description=f"Your recovery score is {recovery['score']}. Consider rest or light activity today.",
                data={"recovery_score": recovery["score"], "recommendations": recovery["recommendations"]},
                created_at=datetime.now(),
            ))
    except Exception:
        logger.warning("Failed to generate recovery insights", exc_info=True)

    # Get correlations and add as insights
    try:
        correlations = await service.analyze_correlations(current_user.id)
        for corr in correlations[:3]:
            insights.append(InsightResponse(
                id=uuid4(),
                category=InsightCategory.CORRELATION,
                title=f"{corr['factor_a'].title()} & {corr['factor_b'].title()} Connection",
                description=corr["insight"],
                data={
                    "correlation": corr["correlation"],
                    "data_points": corr["data_points"],
                },
                created_at=datetime.now(),
            ))
    except Exception:
        logger.warning("Failed to generate correlation insights", exc_info=True)

    # Filter by category if specified
    if category:
        insights = [i for i in insights if i.category == category]

    return insights[:limit]


@router.post("/analyze", response_model=AnalysisResponse)
async def trigger_analysis(
    current_user: CurrentUser = Depends(get_current_user),
):
    """Trigger a fresh analysis of user's data.

    This recalculates all predictions and updates cached scores.
    """
    service = get_prediction_service()
    updated = []

    try:
        await service.get_recovery_prediction(current_user.id)
        updated.append("recovery")
    except Exception as e:
        logger.warning("Recovery analysis failed: %s", e)

    try:
        await service.get_readiness_prediction(current_user.id)
        updated.append("readiness")
    except Exception as e:
        logger.warning("Readiness analysis failed: %s", e)

    try:
        await service.get_wellness_score(current_user.id)
        updated.append("wellness")
    except Exception as e:
        logger.warning("Wellness analysis failed: %s", e)

    try:
        await service.analyze_correlations(current_user.id)
        updated.append("correlations")
    except Exception as e:
        logger.warning("Correlations analysis failed: %s", e)

    return AnalysisResponse(
        status="completed",
        message=f"Analysis complete. Updated {len(updated)} predictions.",
        predictions_updated=updated,
    )


@router.get("/dashboard/narrative")
async def get_narrative_dashboard(
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get dashboard with causal narrative, commitments, and prioritized card order."""
    from fastapi.responses import JSONResponse
    service = get_dashboard_service()
    data = await service.get_narrative_dashboard(current_user.id)
    return JSONResponse(
        content=data.model_dump(mode="json"),
        headers={"Cache-Control": "private, max-age=120, stale-while-revalidate=300"},
    )


@router.get("/review")
async def get_review(
    period: str = Query(default="weekly", regex="^(weekly|monthly)$"),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get weekly or monthly review with comprehensive insights."""
    from datetime import timedelta
    from pydantic import BaseModel as BM

    supabase = get_supabase_client()
    user_id = str(current_user.id)
    today = date.today()

    if period == "weekly":
        start = today - timedelta(days=7)
    else:
        start = today - timedelta(days=30)

    start_str = start.isoformat()
    end_str = today.isoformat()
    tomorrow_str = (today + timedelta(days=1)).isoformat()

    # Workouts
    workouts_result = (
        supabase.table("workouts")
        .select("training_load, duration_minutes")
        .eq("user_id", user_id)
        .gte("start_time", start_str)
        .execute()
    )
    workouts = workouts_result.data or []
    workouts_completed = len(workouts)
    total_volume = sum(w.get("training_load", 0) or 0 for w in workouts)

    # Previous period for comparison
    if period == "weekly":
        prev_start = start - timedelta(days=7)
    else:
        prev_start = start - timedelta(days=30)
    prev_workouts = (
        supabase.table("workouts")
        .select("training_load")
        .eq("user_id", user_id)
        .gte("start_time", prev_start.isoformat())
        .lt("start_time", start_str)
        .execute()
    )
    prev_volume = sum(w.get("training_load", 0) or 0 for w in (prev_workouts.data or []))
    volume_change = ((total_volume - prev_volume) / prev_volume * 100) if prev_volume > 0 else 0

    # Planned workouts
    plan_result = (
        supabase.table("user_training_plans")
        .select("schedule")
        .eq("user_id", user_id)
        .eq("is_active", True)
        .limit(1)
        .execute()
    )
    workouts_planned = 0
    if plan_result.data:
        schedule = plan_result.data[0].get("schedule", {})
        days_in_period = 7 if period == "weekly" else 30
        workouts_per_week = sum(1 for v in schedule.values() if v is not None)
        workouts_planned = workouts_per_week * (days_in_period // 7)

    # PRs in period
    prs_result = (
        supabase.table("personal_records")
        .select("record_type, value, achieved_at, exercises(name)")
        .eq("user_id", user_id)
        .gte("achieved_at", start_str)
        .execute()
    )
    prs = [
        {
            "exercise_name": (r.get("exercises") or {}).get("name") or "Unknown",
            **{k: v for k, v in r.items() if k != "exercises"},
        }
        for r in (prs_result.data or [])
    ]

    # Nutrition adherence
    food_result = (
        supabase.table("food_entries")
        .select("logged_at")
        .eq("user_id", user_id)
        .gte("logged_at", start_str + "T00:00:00")
        .lt("logged_at", tomorrow_str + "T00:00:00")
        .execute()
    )
    dates_with_food = len({row["logged_at"][:10] for row in (food_result.data or [])})
    days_in_period = (today - start).days or 1
    nutrition_adherence = (dates_with_food / days_in_period) * 100

    # Avg calories/protein
    food_details = (
        supabase.table("food_entries")
        .select("calories, protein_g")
        .eq("user_id", user_id)
        .gte("logged_at", start_str + "T00:00:00")
        .lt("logged_at", tomorrow_str + "T00:00:00")
        .execute()
    )
    total_cal = sum(f.get("calories", 0) or 0 for f in (food_details.data or []))
    total_protein = sum(f.get("protein_g", 0) or 0 for f in (food_details.data or []))
    avg_calories = total_cal / max(1, dates_with_food)
    avg_protein = total_protein / max(1, dates_with_food)

    # Sleep
    sleep_result = (
        supabase.table("health_metrics")
        .select("value")
        .eq("user_id", user_id)
        .eq("metric_type", "sleep_duration")
        .gte("timestamp", start_str)
        .execute()
    )
    sleep_values = [s["value"] for s in (sleep_result.data or []) if s.get("value")]
    avg_sleep = sum(sleep_values) / len(sleep_values) if sleep_values else 0
    # Consistency: % of days within 1h of average
    consistent_days = sum(1 for v in sleep_values if abs(v - avg_sleep) < 1) if sleep_values else 0
    sleep_consistency = (consistent_days / len(sleep_values) * 100) if sleep_values else 0

    # Weight
    weight_result = (
        supabase.table("health_metrics")
        .select("value, timestamp")
        .eq("user_id", user_id)
        .eq("metric_type", "weight")
        .gte("timestamp", start_str)
        .order("timestamp", desc=False)
        .execute()
    )
    weights = weight_result.data or []
    weight_start = weights[0]["value"] if weights else None
    weight_end = weights[-1]["value"] if weights else None
    weight_change = round(weight_end - weight_start, 1) if weight_start and weight_end else None

    # Highlights
    highlights = []
    if workouts_completed > 0:
        highlights.append(f"Completed {workouts_completed} workout{'s' if workouts_completed != 1 else ''}")
    if prs:
        highlights.append(f"Set {len(prs)} new PR{'s' if len(prs) != 1 else ''}")
    if nutrition_adherence >= 80:
        highlights.append("Great nutrition consistency")
    elif nutrition_adherence >= 50:
        highlights.append("Moderate nutrition tracking")
    if avg_sleep >= 7:
        highlights.append(f"Averaging {avg_sleep:.1f}h sleep — solid recovery")

    # Overall score (weighted composite)
    workout_score = min(100, (workouts_completed / max(1, workouts_planned)) * 100) if workouts_planned else 50
    sleep_score = min(100, (avg_sleep / 8) * 100) if avg_sleep else 50
    overall = (workout_score * 0.3 + nutrition_adherence * 0.3 + sleep_score * 0.2 + sleep_consistency * 0.2)

    return {
        "period": period,
        "start_date": start_str,
        "end_date": end_str,
        "workouts_completed": workouts_completed,
        "workouts_planned": workouts_planned,
        "total_volume": round(total_volume, 1),
        "volume_change_pct": round(volume_change, 1),
        "prs": prs,
        "nutrition_adherence_pct": round(nutrition_adherence, 1),
        "avg_calories": round(avg_calories, 1),
        "avg_protein": round(avg_protein, 1),
        "avg_sleep_hours": round(avg_sleep, 1),
        "sleep_consistency": round(sleep_consistency, 1),
        "weight_start": weight_start,
        "weight_end": weight_end,
        "weight_change": weight_change,
        "highlights": highlights,
        "overall_score": round(overall, 1),
    }


@router.get("/dashboard", response_model=DashboardResponse)
async def get_dashboard_data(
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get comprehensive dashboard data in a single call.

    Aggregates data from multiple services to reduce API calls:
    - Enhanced recovery with contributing factors
    - Training readiness score
    - Progress summary (key lifts, volume, PRs, muscle balance)
    - Smart recommendations
    - Weekly summary

    This endpoint combines what would otherwise require 5+ separate API calls.
    """
    service = get_dashboard_service()
    return await service.get_dashboard(current_user.id)
