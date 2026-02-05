"""ML predictions and insights endpoints."""

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from datetime import datetime, date
from uuid import UUID, uuid4
from enum import Enum

from app.auth import get_current_user, CurrentUser
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
        pass

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
        pass

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
        pass

    try:
        await service.get_readiness_prediction(current_user.id)
        updated.append("readiness")
    except Exception as e:
        pass

    try:
        await service.get_wellness_score(current_user.id)
        updated.append("wellness")
    except Exception as e:
        pass

    try:
        await service.analyze_correlations(current_user.id)
        updated.append("correlations")
    except Exception as e:
        pass

    return AnalysisResponse(
        status="completed",
        message=f"Analysis complete. Updated {len(updated)} predictions.",
        predictions_updated=updated,
    )


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
