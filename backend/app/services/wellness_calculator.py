"""Wellness score calculation service."""

from dataclasses import dataclass
from datetime import date
from typing import Optional


@dataclass
class DailyMetrics:
    """Input metrics for wellness calculation."""
    steps: Optional[int] = None
    active_calories: Optional[int] = None
    sleep_duration_hours: Optional[float] = None
    sleep_quality: Optional[float] = None  # 0-100
    resting_hr: Optional[int] = None
    hrv: Optional[float] = None
    energy_level: Optional[int] = None  # 1-10
    mood: Optional[int] = None  # 1-10
    stress: Optional[int] = None  # 1-10
    soreness: Optional[int] = None  # 1-10


@dataclass
class WellnessBreakdown:
    """Breakdown of wellness score components."""
    overall_score: float
    activity_score: float
    sleep_score: float
    recovery_score: float
    mental_score: float
    data_completeness: float


class WellnessCalculator:
    """Calculate wellness scores from daily metrics."""

    # Default goals for scoring
    DEFAULT_GOALS = {
        "steps": 10000,
        "active_calories": 500,
        "sleep_hours": 8,
        "resting_hr_optimal": 60,  # Lower is generally better
        "hrv_baseline": 50,  # Higher is generally better
    }

    # Component weights for overall score
    WEIGHTS = {
        "activity": 0.25,
        "sleep": 0.30,
        "recovery": 0.25,
        "mental": 0.20,
    }

    def __init__(self, user_goals: dict | None = None):
        """Initialize with optional custom user goals."""
        self.goals = {**self.DEFAULT_GOALS, **(user_goals or {})}

    def calculate(self, metrics: DailyMetrics) -> WellnessBreakdown:
        """Calculate wellness score breakdown from daily metrics."""
        # Calculate component scores
        activity_score = self._calculate_activity_score(metrics)
        sleep_score = self._calculate_sleep_score(metrics)
        recovery_score = self._calculate_recovery_score(metrics)
        mental_score = self._calculate_mental_score(metrics)

        # Track data completeness
        completeness = self._calculate_completeness(metrics)

        # Calculate weighted overall score
        overall = (
            activity_score * self.WEIGHTS["activity"]
            + sleep_score * self.WEIGHTS["sleep"]
            + recovery_score * self.WEIGHTS["recovery"]
            + mental_score * self.WEIGHTS["mental"]
        )

        return WellnessBreakdown(
            overall_score=round(overall, 1),
            activity_score=round(activity_score, 1),
            sleep_score=round(sleep_score, 1),
            recovery_score=round(recovery_score, 1),
            mental_score=round(mental_score, 1),
            data_completeness=round(completeness, 2),
        )

    def _calculate_activity_score(self, metrics: DailyMetrics) -> float:
        """Calculate activity score from steps and calories."""
        scores = []

        if metrics.steps is not None:
            step_score = min(100, (metrics.steps / self.goals["steps"]) * 100)
            scores.append(step_score)

        if metrics.active_calories is not None:
            cal_score = min(100, (metrics.active_calories / self.goals["active_calories"]) * 100)
            scores.append(cal_score)

        return sum(scores) / len(scores) if scores else 50.0

    def _calculate_sleep_score(self, metrics: DailyMetrics) -> float:
        """Calculate sleep score from duration and quality."""
        scores = []

        if metrics.sleep_duration_hours is not None:
            # Optimal is around 7-9 hours
            duration = metrics.sleep_duration_hours
            if 7 <= duration <= 9:
                duration_score = 100
            elif duration < 7:
                duration_score = max(0, 100 - (7 - duration) * 20)
            else:
                duration_score = max(0, 100 - (duration - 9) * 10)
            scores.append(duration_score)

        if metrics.sleep_quality is not None:
            scores.append(metrics.sleep_quality)

        return sum(scores) / len(scores) if scores else 50.0

    def _calculate_recovery_score(self, metrics: DailyMetrics) -> float:
        """Calculate recovery score from HRV and resting HR."""
        scores = []

        if metrics.hrv is not None:
            # Higher HRV generally indicates better recovery
            hrv_score = min(100, (metrics.hrv / self.goals["hrv_baseline"]) * 70 + 30)
            scores.append(hrv_score)

        if metrics.resting_hr is not None:
            # Lower resting HR generally indicates better fitness/recovery
            rhr = metrics.resting_hr
            optimal = self.goals["resting_hr_optimal"]
            if rhr <= optimal:
                rhr_score = 100
            else:
                rhr_score = max(0, 100 - (rhr - optimal) * 2)
            scores.append(rhr_score)

        if metrics.soreness is not None:
            # Invert soreness (lower is better for recovery)
            soreness_score = (10 - metrics.soreness) * 10
            scores.append(soreness_score)

        return sum(scores) / len(scores) if scores else 50.0

    def _calculate_mental_score(self, metrics: DailyMetrics) -> float:
        """Calculate mental wellness score from mood, energy, stress."""
        scores = []

        if metrics.energy_level is not None:
            scores.append(metrics.energy_level * 10)

        if metrics.mood is not None:
            scores.append(metrics.mood * 10)

        if metrics.stress is not None:
            # Invert stress (lower is better)
            scores.append((10 - metrics.stress) * 10)

        return sum(scores) / len(scores) if scores else 50.0

    def _calculate_completeness(self, metrics: DailyMetrics) -> float:
        """Calculate what percentage of metrics are present."""
        fields = [
            metrics.steps,
            metrics.active_calories,
            metrics.sleep_duration_hours,
            metrics.sleep_quality,
            metrics.resting_hr,
            metrics.hrv,
            metrics.energy_level,
            metrics.mood,
            metrics.stress,
            metrics.soreness,
        ]
        present = sum(1 for f in fields if f is not None)
        return present / len(fields)

    def get_readiness_recommendation(self, recovery_score: float) -> dict:
        """Get training readiness recommendation based on recovery score."""
        if recovery_score >= 80:
            return {
                "status": "optimal",
                "recommendation": "Great recovery! You're ready for high-intensity training.",
                "suggested_intensity": "hard",
            }
        elif recovery_score >= 60:
            return {
                "status": "good",
                "recommendation": "Good recovery. Moderate training recommended.",
                "suggested_intensity": "moderate",
            }
        elif recovery_score >= 40:
            return {
                "status": "fair",
                "recommendation": "Recovery is below optimal. Consider light activity or active recovery.",
                "suggested_intensity": "light",
            }
        else:
            return {
                "status": "low",
                "recommendation": "Your body needs rest. Prioritize recovery today.",
                "suggested_intensity": "rest",
            }
