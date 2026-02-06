"""Dashboard service that aggregates data for the smart dashboard.

Combines data from prediction_service, exercise_service, sleep_service,
and nutrition_service into a single composite response to reduce API calls.
"""

from __future__ import annotations

import logging
from datetime import datetime, date, timedelta
from uuid import UUID
from pydantic import BaseModel

from app.database import get_supabase_client

logger = logging.getLogger(__name__)
from app.services.prediction_service import get_prediction_service
from app.services.exercise_service import get_exercise_service
from app.services.sleep_service import get_sleep_service
from app.services.nutrition_service import get_nutrition_service


# ============================================
# Response Models
# ============================================

class RecoveryFactor(BaseModel):
    """A factor contributing to recovery score."""
    name: str           # "sleep_hours", "hrv", "training_load"
    value: float
    score: float        # 0-100
    impact: str         # "positive", "negative", "neutral"
    recommendation: str | None = None


class EnhancedRecoveryResponse(BaseModel):
    """Enhanced recovery data with contributing factors."""
    score: float
    status: str
    factors: list[RecoveryFactor]
    primary_recommendation: str
    sleep_deficit_hours: float | None = None
    estimated_full_recovery_hours: int | None = None


class LiftProgress(BaseModel):
    """Progress on a key lift."""
    exercise_name: str
    current_value: float
    change_value: float
    change_percent: float
    period: str  # "week", "month"


class MuscleBalance(BaseModel):
    """Muscle group balance info."""
    category: str
    volume_7d: float
    days_since_trained: int | None
    status: str  # "recovered", "recovering", "needs_attention"


class ProgressSummary(BaseModel):
    """Summary of training progress."""
    key_lifts: list[LiftProgress]
    total_volume_week: float
    volume_trend_pct: float
    recent_prs: list[dict]
    muscle_balance: list[MuscleBalance]


class SmartRecommendation(BaseModel):
    """A smart recommendation based on user data."""
    id: str
    category: str       # "workout", "recovery", "nutrition", "sleep"
    priority: int       # Lower = more important
    title: str
    message: str
    action_route: str | None = None  # iOS navigation route


class WeeklySummary(BaseModel):
    """Weekly activity summary."""
    workouts_completed: int
    workouts_planned: int
    avg_sleep_score: float
    nutrition_adherence_pct: float
    best_day: str | None = None
    highlights: list[str]


class DashboardResponse(BaseModel):
    """Complete dashboard data response."""
    enhanced_recovery: EnhancedRecoveryResponse
    readiness_score: float
    readiness_intensity: str
    progress: ProgressSummary
    recommendations: list[SmartRecommendation]
    weekly_summary: WeeklySummary


# ============================================
# Dashboard Service
# ============================================

class DashboardService:
    """Service for aggregating dashboard data."""

    def __init__(self):
        self.supabase = get_supabase_client()
        self.prediction_service = get_prediction_service()
        self.exercise_service = get_exercise_service()
        self.sleep_service = get_sleep_service()
        self.nutrition_service = get_nutrition_service()

    async def get_dashboard(self, user_id: UUID) -> DashboardResponse:
        """Get comprehensive dashboard data in a single call."""
        # Each section is wrapped in try/except so partial failures
        # don't crash the entire dashboard.

        try:
            enhanced_recovery = await self._get_enhanced_recovery(user_id)
        except Exception as e:
            logger.warning("Dashboard: enhanced_recovery failed: %s", e)
            enhanced_recovery = EnhancedRecoveryResponse(
                score=50, status="unknown", factors=[],
                primary_recommendation="Unable to calculate recovery right now.",
            )

        try:
            readiness = await self.prediction_service.get_readiness_prediction(user_id)
        except Exception as e:
            logger.warning("Dashboard: readiness failed: %s", e)
            readiness = {"score": 50, "recommended_intensity": "moderate"}

        try:
            progress = await self._get_progress_summary(user_id)
        except Exception as e:
            logger.warning("Dashboard: progress failed: %s", e)
            progress = ProgressSummary(
                key_lifts=[], total_volume_week=0, volume_trend_pct=0,
                recent_prs=[], muscle_balance=[],
            )

        try:
            weekly = await self._get_weekly_summary(user_id)
        except Exception as e:
            logger.warning("Dashboard: weekly_summary failed: %s", e)
            weekly = WeeklySummary(
                workouts_completed=0, workouts_planned=0, avg_sleep_score=0,
                nutrition_adherence_pct=0, highlights=[],
            )

        recommendations = self._generate_recommendations(
            enhanced_recovery, readiness, progress, weekly
        )

        return DashboardResponse(
            enhanced_recovery=enhanced_recovery,
            readiness_score=readiness["score"],
            readiness_intensity=readiness["recommended_intensity"],
            progress=progress,
            recommendations=recommendations,
            weekly_summary=weekly,
        )

    async def _get_enhanced_recovery(self, user_id: UUID) -> EnhancedRecoveryResponse:
        """Get recovery score with contributing factors."""
        recovery = await self.prediction_service.get_recovery_prediction(user_id)

        # Get sleep data for factor analysis
        sleep_summary = await self.sleep_service.get_sleep_summary(user_id)

        # Calculate individual factor scores
        factors = []

        # Sleep hours factor
        sleep_hours = 7.0
        sleep_score = 70.0
        if sleep_summary:
            sleep_hours = sleep_summary.duration_hours
            sleep_score = min(100, (sleep_hours / 8.0) * 100)

        sleep_impact = "positive" if sleep_score >= 80 else "negative" if sleep_score < 60 else "neutral"
        factors.append(RecoveryFactor(
            name="sleep_hours",
            value=round(sleep_hours, 1),
            score=round(sleep_score, 1),
            impact=sleep_impact,
            recommendation="Aim for 7-9 hours of sleep" if sleep_score < 80 else None,
        ))

        # Training load factor (from 7-day workout data)
        workouts = await self._get_recent_workouts(user_id, days=7)
        training_load = sum(w.get("training_load", 0) or 0 for w in workouts)
        # Optimal training load is ~200-400 per week for most people
        load_score = 100 - abs(training_load - 300) / 3  # Simplified scoring
        load_score = max(0, min(100, load_score))
        load_impact = "positive" if 150 <= training_load <= 400 else "negative" if training_load > 500 else "neutral"

        factors.append(RecoveryFactor(
            name="training_load",
            value=round(training_load, 1),
            score=round(load_score, 1),
            impact=load_impact,
            recommendation="Consider a lighter session" if training_load > 500 else None,
        ))

        # HRV factor (if available)
        hrv_data = await self._get_latest_metric(user_id, "hrv")
        if hrv_data:
            hrv_value = hrv_data.get("value", 50)
            # Higher HRV generally indicates better recovery
            hrv_score = min(100, (hrv_value / 60) * 100)
            hrv_impact = "positive" if hrv_score >= 80 else "negative" if hrv_score < 50 else "neutral"
            factors.append(RecoveryFactor(
                name="hrv",
                value=round(hrv_value, 1),
                score=round(hrv_score, 1),
                impact=hrv_impact,
                recommendation=None,
            ))

        # Calculate sleep deficit
        sleep_deficit = max(0, 8.0 - sleep_hours) if sleep_hours else None

        # Estimate recovery time
        estimated_recovery_hours = None
        if recovery["score"] < 70:
            # Rough estimate: need 8 hours rest + extra based on deficit
            estimated_recovery_hours = int(8 + (sleep_deficit or 0) * 2)

        # Generate primary recommendation
        primary_recommendation = self._get_primary_recovery_recommendation(
            recovery["score"], factors, sleep_deficit
        )

        return EnhancedRecoveryResponse(
            score=recovery["score"],
            status=recovery["status"],
            factors=factors,
            primary_recommendation=primary_recommendation,
            sleep_deficit_hours=round(sleep_deficit, 1) if sleep_deficit else None,
            estimated_full_recovery_hours=estimated_recovery_hours,
        )

    async def _get_progress_summary(self, user_id: UUID) -> ProgressSummary:
        """Get training progress summary."""
        # Get volume analytics
        volume = await self.exercise_service.get_volume_analytics(user_id, "week")

        # Get key lifts progress (from PRs and recent sessions)
        key_lifts = await self._get_key_lift_progress(user_id)

        # Get recent PRs
        prs = await self.exercise_service.get_personal_records(user_id)
        recent_prs = []
        cutoff = datetime.now() - timedelta(days=30)
        for pr in prs[:5]:  # Top 5 recent
            if pr.achieved_at >= cutoff:
                recent_prs.append({
                    "exercise_name": pr.exercise_name,
                    "record_type": pr.record_type,
                    "value": pr.value,
                    "previous_value": pr.previous_value,
                    "achieved_at": pr.achieved_at.isoformat(),
                })

        # Get muscle balance
        muscle_stats = await self.exercise_service.get_muscle_group_stats(user_id)
        muscle_balance = []
        for stat in muscle_stats:
            status = "recovered"
            if stat.days_since_trained is not None:
                if stat.days_since_trained <= 1:
                    status = "recovering"
                elif stat.days_since_trained > 7:
                    status = "needs_attention"

            muscle_balance.append(MuscleBalance(
                category=stat.category.value if hasattr(stat.category, 'value') else str(stat.category),
                volume_7d=stat.total_volume_7d,
                days_since_trained=stat.days_since_trained,
                status=status,
            ))

        return ProgressSummary(
            key_lifts=key_lifts,
            total_volume_week=volume.total_volume,
            volume_trend_pct=volume.trend_pct,
            recent_prs=recent_prs,
            muscle_balance=muscle_balance,
        )

    async def _get_weekly_summary(self, user_id: UUID) -> WeeklySummary:
        """Get weekly activity summary."""
        today = date.today()
        week_start = today - timedelta(days=today.weekday())

        # Get workouts this week
        workouts = await self._get_recent_workouts(user_id, days=7)
        workouts_completed = len(workouts)

        # Get planned workouts from training plan
        workouts_planned = await self._get_planned_workouts_count(user_id)

        # Get sleep analytics for average score
        sleep_analytics = await self.sleep_service.get_sleep_analytics(user_id, days=7)
        avg_sleep_score = sleep_analytics.avg_sleep_score if sleep_analytics else 0

        # Get nutrition adherence
        nutrition_adherence = await self._get_nutrition_adherence(user_id, days=7)

        # Generate highlights
        highlights = []
        if workouts_completed >= workouts_planned and workouts_planned > 0:
            highlights.append(f"Completed all {workouts_planned} planned workouts!")
        elif workouts_completed > 0:
            highlights.append(f"Logged {workouts_completed} workouts this week")

        if avg_sleep_score >= 80:
            highlights.append("Great sleep quality this week")

        if nutrition_adherence >= 80:
            highlights.append("Excellent nutrition adherence")

        # Find best day (day with most activity/best metrics)
        best_day = None
        if workouts:
            # Find day with most/best workout
            workout_dates = {}
            for w in workouts:
                start_time = w.get("start_time", "")
                if start_time:
                    try:
                        dt = datetime.fromisoformat(start_time.replace("Z", "+00:00"))
                        day_name = dt.strftime("%A")
                        workout_dates[day_name] = workout_dates.get(day_name, 0) + 1
                    except (ValueError, TypeError):
                        pass
            if workout_dates:
                best_day = max(workout_dates.keys(), key=lambda k: workout_dates[k])

        return WeeklySummary(
            workouts_completed=workouts_completed,
            workouts_planned=workouts_planned,
            avg_sleep_score=round(avg_sleep_score, 1),
            nutrition_adherence_pct=round(nutrition_adherence, 1),
            best_day=best_day,
            highlights=highlights,
        )

    def _generate_recommendations(
        self,
        recovery: EnhancedRecoveryResponse,
        readiness: dict,
        progress: ProgressSummary,
        weekly: WeeklySummary,
    ) -> list[SmartRecommendation]:
        """Generate smart recommendations based on all data."""
        recommendations = []
        priority = 0

        # Sleep-based recommendations
        if recovery.sleep_deficit_hours and recovery.sleep_deficit_hours > 1:
            priority += 1
            recommendations.append(SmartRecommendation(
                id=f"sleep_{priority}",
                category="sleep",
                priority=priority,
                title="Sleep Recovery",
                message=f"You're {recovery.sleep_deficit_hours:.1f}h behind on sleep. Consider an earlier bedtime tonight.",
                action_route="sleep",
            ))

        # Recovery-based recommendations
        if recovery.score < 60:
            priority += 1
            recommendations.append(SmartRecommendation(
                id=f"recovery_{priority}",
                category="recovery",
                priority=priority,
                title="Rest Day Recommended",
                message="Your recovery is low. A light activity day would help you bounce back faster.",
                action_route=None,
            ))

        # Workout recommendations based on muscle recovery
        recovered_muscles = [m for m in progress.muscle_balance if m.status == "recovered"]
        if recovered_muscles:
            # Find most rested muscle group
            best_muscle = max(
                recovered_muscles,
                key=lambda m: m.days_since_trained or 0
            )
            if best_muscle.days_since_trained and best_muscle.days_since_trained >= 3:
                priority += 1
                recommendations.append(SmartRecommendation(
                    id=f"workout_{priority}",
                    category="workout",
                    priority=priority,
                    title=f"{best_muscle.category.title()} Day",
                    message=f"Your {best_muscle.category} is fully recovered ({best_muscle.days_since_trained} days rest)",
                    action_route="workout",
                ))

        # Nutrition recommendations
        if weekly.nutrition_adherence_pct < 60:
            priority += 1
            recommendations.append(SmartRecommendation(
                id=f"nutrition_{priority}",
                category="nutrition",
                priority=priority,
                title="Track Your Meals",
                message="Logging meals helps hit your goals. Try logging at least 2 meals today.",
                action_route="nutrition",
            ))

        # Progress-based recommendations
        if progress.volume_trend_pct < -20:
            priority += 1
            recommendations.append(SmartRecommendation(
                id=f"progress_{priority}",
                category="workout",
                priority=priority,
                title="Volume Drop",
                message="Your training volume is down. Consider adding an extra set to your key lifts.",
                action_route="workout",
            ))

        # Celebration for recent PRs
        if progress.recent_prs:
            priority += 1
            pr = progress.recent_prs[0]
            recommendations.append(SmartRecommendation(
                id=f"pr_{priority}",
                category="workout",
                priority=100,  # Low priority (celebration, not actionable)
                title="New PR! 🎉",
                message=f"You hit a new {pr['record_type']} on {pr['exercise_name']}!",
                action_route=None,
            ))

        # Sort by priority
        recommendations.sort(key=lambda r: r.priority)
        return recommendations[:5]  # Return top 5

    def _get_primary_recovery_recommendation(
        self,
        score: float,
        factors: list[RecoveryFactor],
        sleep_deficit: float | None,
    ) -> str:
        """Generate primary recovery recommendation."""
        if score >= 85:
            return "You're well recovered. Great day for an intense workout!"
        elif score >= 70:
            return "Recovery is good. Ready for moderate training."
        elif score >= 50:
            # Find the worst factor
            worst_factor = min(factors, key=lambda f: f.score) if factors else None
            if worst_factor and worst_factor.name == "sleep_hours":
                return f"Prioritize sleep tonight - aim for {8 + (sleep_deficit or 0):.0f}+ hours."
            elif worst_factor and worst_factor.name == "training_load":
                return "Training load is high. Consider active recovery today."
            return "Consider a lighter workout or active recovery."
        else:
            return "Rest day recommended. Focus on sleep and nutrition."

    async def _get_recent_workouts(self, user_id: UUID, days: int) -> list[dict]:
        """Get recent workouts."""
        start_date = (datetime.now() - timedelta(days=days)).isoformat()
        result = (
            self.supabase.table("workouts")
            .select("*")
            .eq("user_id", str(user_id))
            .gte("start_time", start_date)
            .execute()
        )
        return result.data or []

    async def _get_latest_metric(self, user_id: UUID, metric_type: str) -> dict | None:
        """Get latest health metric of a type."""
        result = (
            self.supabase.table("health_metrics")
            .select("*")
            .eq("user_id", str(user_id))
            .eq("metric_type", metric_type)
            .order("timestamp", desc=True)
            .limit(1)
            .execute()
        )
        return result.data[0] if result.data else None

    async def _get_key_lift_progress(self, user_id: UUID) -> list[LiftProgress]:
        """Get progress on key lifts."""
        # Key compound lifts to track
        key_exercises = ["Bench Press", "Squat", "Deadlift", "Overhead Press", "Barbell Row"]
        lifts = []

        for exercise_name in key_exercises:
            # Get exercise by name
            exercise_result = (
                self.supabase.table("exercises")
                .select("id")
                .ilike("name", f"%{exercise_name}%")
                .limit(1)
                .execute()
            )

            if not exercise_result.data:
                continue

            exercise_id = exercise_result.data[0]["id"]

            # Get recent sets for this exercise
            month_ago = (datetime.now() - timedelta(days=30)).isoformat()
            two_months_ago = (datetime.now() - timedelta(days=60)).isoformat()

            # Current month best
            current_result = (
                self.supabase.table("workout_sets")
                .select("weight_kg, reps")
                .eq("user_id", str(user_id))
                .eq("exercise_id", exercise_id)
                .eq("is_warmup", False)
                .gte("performed_at", month_ago)
                .order("weight_kg", desc=True)
                .limit(1)
                .execute()
            )

            # Previous month best
            previous_result = (
                self.supabase.table("workout_sets")
                .select("weight_kg, reps")
                .eq("user_id", str(user_id))
                .eq("exercise_id", exercise_id)
                .eq("is_warmup", False)
                .gte("performed_at", two_months_ago)
                .lt("performed_at", month_ago)
                .order("weight_kg", desc=True)
                .limit(1)
                .execute()
            )

            if current_result.data:
                current_weight = current_result.data[0]["weight_kg"]
                previous_weight = previous_result.data[0]["weight_kg"] if previous_result.data else current_weight

                change = current_weight - previous_weight
                change_pct = (change / previous_weight * 100) if previous_weight > 0 else 0

                lifts.append(LiftProgress(
                    exercise_name=exercise_name,
                    current_value=current_weight,
                    change_value=round(change, 1),
                    change_percent=round(change_pct, 1),
                    period="month",
                ))

        return lifts[:4]  # Top 4 lifts

    async def _get_planned_workouts_count(self, user_id: UUID) -> int:
        """Get number of planned workouts this week from active training plan."""
        result = (
            self.supabase.table("user_training_plans")
            .select("schedule")
            .eq("user_id", str(user_id))
            .eq("is_active", True)
            .limit(1)
            .execute()
        )

        if not result.data:
            return 0

        schedule = result.data[0].get("schedule", {})
        # Count non-null workout days
        return sum(1 for v in schedule.values() if v is not None)

    async def _get_nutrition_adherence(self, user_id: UUID, days: int) -> float:
        """Calculate nutrition adherence percentage over given days."""
        today = date.today()
        days_with_entries = 0

        for i in range(days):
            target_date = today - timedelta(days=i)
            entries = await self.nutrition_service.get_food_entries(
                user_id, target_date=target_date
            )
            if entries:
                days_with_entries += 1

        return (days_with_entries / days) * 100 if days > 0 else 0


# Singleton instance
_service: DashboardService | None = None


def get_dashboard_service() -> DashboardService:
    """Get or create the dashboard service instance."""
    global _service
    if _service is None:
        _service = DashboardService()
    return _service
