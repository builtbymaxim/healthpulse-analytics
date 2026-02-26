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
# Narrative Dashboard Models (Phase 11B)
# ============================================

class CausalAnnotation(BaseModel):
    """Explains WHY a metric has its current value."""
    metric_name: str           # "recovery", "readiness"
    current_value: float
    primary_driver: str        # "sleep was 5h 40m"
    driver_factor: str         # "sleep_hours"
    driver_impact_pct: float
    secondary_driver: str | None = None


class CommitmentSlot(BaseModel):
    """A single action slot in the Now/Next/Tonight framework."""
    slot: str                  # "now", "next", "tonight"
    title: str
    subtitle: str
    icon: str                  # SF Symbol name
    category: str              # "workout", "nutrition", "recovery", "sleep"
    action_route: str | None = None
    load_modifier: str | None = None  # "reduce_30", "reduce_10", "normal", "increase_5"


class PrioritizedCard(BaseModel):
    """A dashboard card with its computed priority."""
    card_type: str             # "workout", "nutrition", "recovery", "sleep", "streak", "progress", "weekly"
    priority: int
    reason: str


class DailyAction(BaseModel):
    """A daily action item for the dashboard checklist."""
    id: str                    # e.g. "log_workout", "track_meals"
    title: str
    icon: str                  # SF Symbol name
    action_route: str          # tab to navigate to
    is_completed: bool
    priority: int


class NarrativeDashboardResponse(BaseModel):
    """Extended dashboard with causal story."""
    # Existing fields (superset of DashboardResponse)
    enhanced_recovery: EnhancedRecoveryResponse
    readiness_score: float
    readiness_intensity: str
    progress: ProgressSummary
    recommendations: list[SmartRecommendation]
    weekly_summary: WeeklySummary
    # Narrative fields
    causal_annotations: list[CausalAnnotation]
    commitments: list[CommitmentSlot]
    card_priority_order: list[PrioritizedCard]
    greeting_context: str
    readiness_narrative: str
    daily_actions: list[DailyAction] = []


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

    async def get_narrative_dashboard(self, user_id: UUID) -> NarrativeDashboardResponse:
        """Get dashboard data with causal narrative and commitment slots."""
        logger.info("Building narrative dashboard for user %s", user_id)

        # 1. Get base dashboard data (reuses existing logic)
        base = await self.get_dashboard(user_id)

        # 2. Build causal annotations
        causal = self._build_causal_annotations(base)

        # 3. Fetch today's planned workout from training plan
        today_workout = await self._get_todays_planned_workout(user_id)

        # 4. Build commitment slots (Now/Next/Tonight) — training-plan-aware
        commitments = self._build_commitments(base, today_workout)

        # 5. Compute card priority order based on readiness
        card_order = self._compute_card_priority(base)

        # 6. Generate greeting context and narrative
        greeting_context = self._get_greeting_context(base)
        narrative = self._build_readiness_narrative(base, causal)

        # 7. Build daily action items from real user data
        daily_actions = await self._build_daily_actions(user_id, today_workout)

        return NarrativeDashboardResponse(
            enhanced_recovery=base.enhanced_recovery,
            readiness_score=base.readiness_score,
            readiness_intensity=base.readiness_intensity,
            progress=base.progress,
            recommendations=base.recommendations,
            weekly_summary=base.weekly_summary,
            causal_annotations=causal,
            commitments=commitments,
            card_priority_order=card_order,
            greeting_context=greeting_context,
            readiness_narrative=narrative,
            daily_actions=daily_actions,
        )

    def _build_causal_annotations(self, dashboard: DashboardResponse) -> list[CausalAnnotation]:
        """Find the primary driver for each key metric."""
        annotations = []
        factors = dashboard.enhanced_recovery.factors

        if factors:
            worst = min(factors, key=lambda f: f.score)
            annotations.append(CausalAnnotation(
                metric_name="recovery",
                current_value=dashboard.enhanced_recovery.score,
                primary_driver=self._factor_to_human(worst),
                driver_factor=worst.name,
                driver_impact_pct=round(100 - worst.score, 1),
                secondary_driver=(
                    self._factor_to_human(max(factors, key=lambda f: f.score))
                    if len(factors) > 1 else None
                ),
            ))

        # Readiness annotation
        primary_driver = "recovery is low" if dashboard.enhanced_recovery.score < 60 else "training load"
        if factors:
            worst = min(factors, key=lambda f: f.score)
            primary_driver = self._factor_to_human(worst)

        annotations.append(CausalAnnotation(
            metric_name="readiness",
            current_value=dashboard.readiness_score,
            primary_driver=primary_driver,
            driver_factor="recovery" if dashboard.enhanced_recovery.score < 60 else "training_load",
            driver_impact_pct=abs(dashboard.readiness_score - 70),
        ))

        return annotations

    def _factor_to_human(self, factor: RecoveryFactor) -> str:
        """Convert a RecoveryFactor to human-readable string."""
        if factor.name == "sleep_hours":
            hours = int(factor.value)
            minutes = int((factor.value - hours) * 60)
            if minutes > 0:
                return f"sleep was {hours}h {minutes}m"
            return f"sleep was {hours}h"
        elif factor.name == "training_load":
            if factor.value > 400:
                return "training load is high"
            elif factor.value < 150:
                return "training load is light"
            return "training load is moderate"
        elif factor.name == "hrv":
            if factor.score < 50:
                return f"HRV is low at {int(factor.value)}ms"
            return f"HRV is good at {int(factor.value)}ms"
        return f"{factor.name} is {int(factor.value)}"

    def _build_commitments(
        self, dashboard: DashboardResponse, today_workout: str | None = None,
    ) -> list[CommitmentSlot]:
        """Build Now/Next/Tonight commitment slots."""
        hour = datetime.now().hour
        readiness = dashboard.readiness_score
        recovery = dashboard.enhanced_recovery

        # Determine load modifier
        if readiness < 40:
            load_modifier = "reduce_30"
        elif readiness < 60:
            load_modifier = "reduce_10"
        elif readiness >= 85:
            load_modifier = "increase_5"
        else:
            load_modifier = "normal"

        now_slot = self._compute_now_slot(
            hour, readiness, recovery, dashboard, load_modifier, today_workout,
        )
        next_slot = self._compute_next_slot(hour, readiness, now_slot, dashboard)
        tonight_slot = self._compute_tonight_slot(recovery)

        return [now_slot, next_slot, tonight_slot]

    def _compute_now_slot(
        self, hour: int, readiness: float, recovery: EnhancedRecoveryResponse,
        dashboard: DashboardResponse, load_modifier: str,
        today_workout: str | None = None,
    ) -> CommitmentSlot:
        """Compute the NOW commitment based on training plan, readiness, and time."""
        # 1. Training plan takes priority — if today has a scheduled workout
        if today_workout:
            return CommitmentSlot(
                slot="now",
                title=today_workout,
                subtitle="Scheduled in your training plan",
                icon="dumbbell.fill",
                category="workout",
                action_route="workout",
                load_modifier=load_modifier,
            )

        # 2. Low readiness → active recovery
        if readiness < 40:
            return CommitmentSlot(
                slot="now",
                title="Active Recovery",
                subtitle="Light movement: walk, stretch, or mobility",
                icon="figure.walk",
                category="recovery",
                action_route="workout",
            )

        # 3. High readiness + recovered muscles → suggest workout
        if readiness >= 60 and dashboard.progress.muscle_balance:
            recovered = [m for m in dashboard.progress.muscle_balance if m.status == "recovered"]
            if recovered:
                best = max(recovered, key=lambda m: m.days_since_trained or 0)
                if best.days_since_trained and best.days_since_trained >= 2:
                    return CommitmentSlot(
                        slot="now",
                        title=f"{best.category.title()} Workout",
                        subtitle=f"Fully recovered ({best.days_since_trained}d rest)",
                        icon="dumbbell.fill",
                        category="workout",
                        action_route="workout",
                        load_modifier=load_modifier,
                    )

        # 4. Default: nutrition
        return CommitmentSlot(
            slot="now",
            title="Log a Meal",
            subtitle="Stay on track with your nutrition goals",
            icon="fork.knife",
            category="nutrition",
            action_route="nutrition",
        )

    def _compute_next_slot(
        self, hour: int, readiness: float, now_slot: CommitmentSlot,
        dashboard: DashboardResponse,  # noqa: ARG002 — kept for future use
    ) -> CommitmentSlot:
        """Compute the NEXT commitment (2-4 hours ahead)."""
        # If NOW is a workout → NEXT should be nutrition
        if now_slot.category == "workout":
            return CommitmentSlot(
                slot="next",
                title="Post-Workout Protein",
                subtitle="Hit your protein target within 2 hours",
                icon="fork.knife",
                category="nutrition",
                action_route="nutrition",
            )

        # If NOW is recovery → suggest light planning
        if now_slot.category == "recovery":
            return CommitmentSlot(
                slot="next",
                title="Plan Tomorrow",
                subtitle="Review your training plan for tomorrow",
                icon="calendar",
                category="workout",
                action_route="workout",
            )

        # NOW is nutrition — avoid double-nutrition for NEXT
        # Morning: suggest workout prep
        if hour < 12 and readiness >= 60:
            return CommitmentSlot(
                slot="next",
                title="Workout Prep",
                subtitle="Your readiness is good — plan your session",
                icon="dumbbell.fill",
                category="workout",
                action_route="workout",
            )

        # Afternoon: review progress
        if hour < 17:
            return CommitmentSlot(
                slot="next",
                title="Check Your Progress",
                subtitle="See how your week is shaping up",
                icon="chart.line.uptrend.xyaxis",
                category="workout",
                action_route="workout",
            )

        # Evening: wind-down
        return CommitmentSlot(
            slot="next",
            title="Evening Wind-Down",
            subtitle="Start dimming screens to protect sleep quality",
            icon="moon.stars",
            category="sleep",
            action_route="sleep",
        )

    def _compute_tonight_slot(self, recovery: EnhancedRecoveryResponse) -> CommitmentSlot:
        """Compute the TONIGHT commitment — always sleep/recovery focused."""
        deficit = recovery.sleep_deficit_hours or 0
        if deficit > 1:
            target_hours = 8 + deficit
            return CommitmentSlot(
                slot="tonight",
                title=f"Sleep {target_hours:.0f}+ Hours",
                subtitle=f"You have a {deficit:.1f}h sleep deficit to recover",
                icon="moon.zzz.fill",
                category="sleep",
                action_route="sleep",
            )

        return CommitmentSlot(
            slot="tonight",
            title="Wind Down by 10pm",
            subtitle="Maintain your good sleep consistency",
            icon="moon.zzz.fill",
            category="sleep",
            action_route="sleep",
        )

    def _compute_card_priority(self, dashboard: DashboardResponse) -> list[PrioritizedCard]:
        """Reorder dashboard cards based on readiness score."""
        readiness = dashboard.readiness_score

        if readiness >= 70:
            return [
                PrioritizedCard(card_type="workout", priority=1, reason="High readiness — ready to train"),
                PrioritizedCard(card_type="progress", priority=2, reason="Show momentum when ready"),
                PrioritizedCard(card_type="nutrition", priority=3, reason="Fuel the workout"),
                PrioritizedCard(card_type="recovery", priority=4, reason="Less urgent when recovered"),
                PrioritizedCard(card_type="sleep", priority=5, reason="Informational"),
            ]
        elif readiness >= 40:
            return [
                PrioritizedCard(card_type="recovery", priority=1, reason="Moderate readiness — recovery context first"),
                PrioritizedCard(card_type="workout", priority=2, reason="Modified workout still OK"),
                PrioritizedCard(card_type="nutrition", priority=3, reason="Recovery nutrition matters"),
                PrioritizedCard(card_type="sleep", priority=4, reason="Sleep drives recovery"),
                PrioritizedCard(card_type="progress", priority=5, reason="Context"),
            ]
        else:
            return [
                PrioritizedCard(card_type="recovery", priority=1, reason="Low readiness — recovery is top priority"),
                PrioritizedCard(card_type="sleep", priority=2, reason="Sleep deficit is likely culprit"),
                PrioritizedCard(card_type="nutrition", priority=3, reason="Recovery nutrition"),
                PrioritizedCard(card_type="workout", priority=4, reason="Light movement only"),
                PrioritizedCard(card_type="progress", priority=5, reason="De-emphasized when resting"),
            ]

    def _get_greeting_context(self, dashboard: DashboardResponse) -> str:
        """Return a contextual label based on readiness and state."""
        readiness = dashboard.readiness_score
        if readiness >= 80:
            return "Push Day"
        elif readiness >= 60:
            return "Training Day"
        elif readiness >= 40:
            return "Easy Day"
        else:
            return "Recovery Day"

    def _build_readiness_narrative(
        self, dashboard: DashboardResponse, causal: list[CausalAnnotation],
    ) -> str:
        """Build a human-readable readiness narrative."""
        score = dashboard.readiness_score
        recovery_annotation = next((a for a in causal if a.metric_name == "recovery"), None)
        driver = recovery_annotation.primary_driver if recovery_annotation else "multiple factors"

        if score >= 80:
            return f"Your body is {int(score)}% ready — great shape for an intense session"
        elif score >= 60:
            return f"Your body is {int(score)}% ready — {driver}, but overall good to go"
        elif score >= 40:
            return f"Your body is {int(score)}% ready — mainly because {driver}"
        else:
            return f"Your body needs rest at {int(score)}% — {driver}"

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
        """Get progress on key lifts (batched: 3 queries instead of 15)."""
        key_exercises = ["Bench Press", "Squat", "Deadlift", "Overhead Press", "Barbell Row"]

        # 1) Batch lookup: find all key exercises in one query
        or_filter = ",".join(f"name.ilike.%{name}%" for name in key_exercises)
        exercise_result = (
            self.supabase.table("exercises")
            .select("id, name")
            .or_(or_filter)
            .execute()
        )
        if not exercise_result.data:
            return []

        # Map exercise_id -> canonical name (first match per key exercise)
        exercise_map: dict[str, str] = {}  # id -> display name
        for name in key_exercises:
            for ex in exercise_result.data:
                if name.lower() in ex["name"].lower() and ex["id"] not in exercise_map:
                    exercise_map[ex["id"]] = name
                    break

        if not exercise_map:
            return []

        exercise_ids = list(exercise_map.keys())
        month_ago = (datetime.now() - timedelta(days=30)).isoformat()
        two_months_ago = (datetime.now() - timedelta(days=60)).isoformat()

        # 2) Batch: current month sets for all exercises
        current_result = (
            self.supabase.table("workout_sets")
            .select("exercise_id, weight_kg, reps")
            .eq("user_id", str(user_id))
            .in_("exercise_id", exercise_ids)
            .eq("is_warmup", False)
            .gte("performed_at", month_ago)
            .order("weight_kg", desc=True)
            .execute()
        )

        # 3) Batch: previous month sets for all exercises
        previous_result = (
            self.supabase.table("workout_sets")
            .select("exercise_id, weight_kg, reps")
            .eq("user_id", str(user_id))
            .in_("exercise_id", exercise_ids)
            .eq("is_warmup", False)
            .gte("performed_at", two_months_ago)
            .lt("performed_at", month_ago)
            .order("weight_kg", desc=True)
            .execute()
        )

        # Group by exercise_id and take the best (first, since ordered desc)
        current_best: dict[str, float] = {}
        for row in current_result.data or []:
            eid = row["exercise_id"]
            if eid not in current_best:
                current_best[eid] = row["weight_kg"]

        previous_best: dict[str, float] = {}
        for row in previous_result.data or []:
            eid = row["exercise_id"]
            if eid not in previous_best:
                previous_best[eid] = row["weight_kg"]

        # Build results
        lifts = []
        for eid, exercise_name in exercise_map.items():
            if eid in current_best:
                current_weight = current_best[eid]
                previous_weight = previous_best.get(eid, current_weight)
                change = current_weight - previous_weight
                change_pct = (change / previous_weight * 100) if previous_weight > 0 else 0
                lifts.append(LiftProgress(
                    exercise_name=exercise_name,
                    current_value=current_weight,
                    change_value=round(change, 1),
                    change_percent=round(change_pct, 1),
                    period="month",
                ))

        return lifts[:4]

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
        """Calculate nutrition adherence percentage (1 query instead of N)."""
        today = date.today()
        start_date = today - timedelta(days=days - 1)

        # Single query: get all food entries in the date range
        result = (
            self.supabase.table("food_entries")
            .select("entry_date")
            .eq("user_id", str(user_id))
            .gte("entry_date", start_date.isoformat())
            .lte("entry_date", today.isoformat())
            .execute()
        )

        # Count distinct dates with entries
        dates_with_entries = len({row["entry_date"] for row in (result.data or [])})
        return (dates_with_entries / days) * 100 if days > 0 else 0

    async def _get_todays_planned_workout(self, user_id: UUID) -> str | None:
        """Get today's workout name from the active training plan, or None for rest day."""
        result = (
            self.supabase.table("user_training_plans")
            .select("schedule")
            .eq("user_id", str(user_id))
            .eq("is_active", True)
            .limit(1)
            .execute()
        )

        if not result.data:
            return None

        schedule = result.data[0].get("schedule", {})
        # ISO weekday: 1=Mon ... 7=Sun
        iso_weekday = date.today().isoweekday()
        day_key = str(iso_weekday)

        workout_name = schedule.get(day_key)
        if workout_name and isinstance(workout_name, str):
            return workout_name
        # Also try day name keys (some plans use "monday", "tuesday", etc.)
        day_names = ["", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        if iso_weekday < len(day_names):
            workout_name = schedule.get(day_names[iso_weekday])
            if workout_name and isinstance(workout_name, str):
                return workout_name

        return None

    async def _build_daily_actions(
        self, user_id: UUID, today_workout: str | None,
    ) -> list[DailyAction]:
        """Build daily action items based on what the user has/hasn't done today."""
        actions: list[DailyAction] = []
        today_str = date.today().isoformat()

        # 1. Log workout (if today is a workout day)
        if today_workout:
            workout_result = (
                self.supabase.table("workout_sessions")
                .select("id")
                .eq("user_id", str(user_id))
                .eq("date", today_str)
                .limit(1)
                .execute()
            )
            has_workout = bool(workout_result.data)
            actions.append(DailyAction(
                id="log_workout",
                title=f"Complete {today_workout}",
                icon="dumbbell.fill",
                action_route="workout",
                is_completed=has_workout,
                priority=1,
            ))

        # 2. Track meals
        food_result = (
            self.supabase.table("food_entries")
            .select("id")
            .eq("user_id", str(user_id))
            .eq("entry_date", today_str)
            .limit(1)
            .execute()
        )
        has_meals = bool(food_result.data)
        actions.append(DailyAction(
            id="track_meals",
            title="Track your meals",
            icon="fork.knife",
            action_route="nutrition",
            is_completed=has_meals,
            priority=2,
        ))

        # 3. Weigh in (check if weight logged this week)
        week_start = (date.today() - timedelta(days=date.today().weekday())).isoformat()
        weight_result = (
            self.supabase.table("health_metrics")
            .select("id")
            .eq("user_id", str(user_id))
            .eq("metric_type", "weight")
            .gte("recorded_at", week_start)
            .limit(1)
            .execute()
        )
        has_weight = bool(weight_result.data)
        actions.append(DailyAction(
            id="weigh_in",
            title="Log your weight",
            icon="scalemass.fill",
            action_route="profile",
            is_completed=has_weight,
            priority=3,
        ))

        # 4. Weekly review prompt (Sunday or Monday)
        weekday = date.today().weekday()  # 0=Mon, 6=Sun
        if weekday in (0, 6):
            actions.append(DailyAction(
                id="weekly_review",
                title="Check your weekly review",
                icon="chart.bar.doc.horizontal",
                action_route="workout",
                is_completed=False,  # No tracking for this yet
                priority=4,
            ))

        # Sort by priority
        actions.sort(key=lambda a: (a.is_completed, a.priority))
        return actions


# Singleton instance
_service: DashboardService | None = None


def get_dashboard_service() -> DashboardService:
    """Get or create the dashboard service instance."""
    global _service
    if _service is None:
        _service = DashboardService()
    return _service
