"""Machine learning models for HealthPulse fitness predictions.

Provides predictors for:
- Recovery score (based on sleep, HRV, training load)
- Training readiness (based on recovery, fatigue, recent workouts)
- Wellness score (overall health index)
"""

from __future__ import annotations

import numpy as np
from datetime import datetime, timedelta
from typing import TypedDict


class RecoveryResult(TypedDict):
    score: float
    confidence: float
    status: str
    contributing_factors: dict
    recommendations: list[str]


class ReadinessResult(TypedDict):
    score: float
    confidence: float
    recommended_intensity: str
    factors: dict
    suggested_workout_types: list[str]


class WellnessResult(TypedDict):
    overall_score: float
    components: dict
    trend: str
    comparison_to_baseline: float


class FitnessPredictor:
    """Predict recovery, readiness, and wellness scores.

    Uses a rule-based model with weighted factors. Can be extended
    with XGBoost training when sufficient user data is collected.
    """

    # Weights for recovery score calculation
    RECOVERY_WEIGHTS = {
        "sleep_hours": 0.25,
        "sleep_quality": 0.20,
        "hrv": 0.20,
        "resting_hr": 0.15,
        "training_load_7d": 0.10,
        "stress": 0.10,
    }

    # Weights for readiness score
    READINESS_WEIGHTS = {
        "recovery_score": 0.35,
        "sleep_quality": 0.20,
        "days_since_hard_workout": 0.15,
        "energy_level": 0.15,
        "muscle_soreness": 0.15,
    }

    # Weights for wellness score components
    WELLNESS_WEIGHTS = {
        "sleep": 0.25,
        "activity": 0.20,
        "recovery": 0.20,
        "nutrition": 0.15,
        "stress": 0.10,
        "mood": 0.10,
    }

    def __init__(self) -> None:
        self.baseline_scores: dict[str, float] = {}

    def calculate_recovery_score(
        self,
        sleep_hours: float = 7.0,
        sleep_quality: float = 70.0,
        hrv: float | None = None,
        resting_hr: float | None = None,
        training_load_7d: float = 0.0,
        stress_level: float = 5.0,
        hrv_baseline: float = 50.0,
        rhr_baseline: float = 60.0,
    ) -> RecoveryResult:
        """Calculate recovery score (0-100) based on multiple factors.

        Args:
            sleep_hours: Hours of sleep (0-12)
            sleep_quality: Sleep quality score (0-100)
            hrv: Heart rate variability in ms (optional)
            resting_hr: Resting heart rate (optional)
            training_load_7d: Training load over past 7 days (0-1000)
            stress_level: Perceived stress (1-10)
            hrv_baseline: User's baseline HRV
            rhr_baseline: User's baseline resting HR

        Returns:
            RecoveryResult with score, confidence, status, factors, recommendations
        """
        factors = {}
        weights_used = 0.0
        weighted_score = 0.0

        # Sleep hours component (optimal: 7-9 hours)
        if sleep_hours > 0:
            if 7 <= sleep_hours <= 9:
                sleep_hrs_score = 100
            elif sleep_hours < 7:
                sleep_hrs_score = max(0, (sleep_hours / 7) * 100)
            else:  # > 9 hours
                sleep_hrs_score = max(70, 100 - (sleep_hours - 9) * 10)

            factors["sleep_hours"] = {
                "value": sleep_hours,
                "score": sleep_hrs_score,
                "impact": "positive" if sleep_hrs_score > 70 else "negative"
            }
            weighted_score += sleep_hrs_score * self.RECOVERY_WEIGHTS["sleep_hours"]
            weights_used += self.RECOVERY_WEIGHTS["sleep_hours"]

        # Sleep quality component
        if sleep_quality > 0:
            factors["sleep_quality"] = {
                "value": sleep_quality,
                "score": sleep_quality,
                "impact": "positive" if sleep_quality > 70 else "negative"
            }
            weighted_score += sleep_quality * self.RECOVERY_WEIGHTS["sleep_quality"]
            weights_used += self.RECOVERY_WEIGHTS["sleep_quality"]

        # HRV component (higher is better, compare to baseline)
        if hrv is not None and hrv > 0:
            hrv_ratio = hrv / hrv_baseline
            hrv_score = min(100, max(0, hrv_ratio * 80))
            factors["hrv"] = {
                "value": hrv,
                "baseline": hrv_baseline,
                "score": hrv_score,
                "impact": "positive" if hrv >= hrv_baseline else "negative"
            }
            weighted_score += hrv_score * self.RECOVERY_WEIGHTS["hrv"]
            weights_used += self.RECOVERY_WEIGHTS["hrv"]

        # Resting HR component (lower is better, compare to baseline)
        if resting_hr is not None and resting_hr > 0:
            rhr_ratio = rhr_baseline / resting_hr
            rhr_score = min(100, max(0, rhr_ratio * 80))
            factors["resting_hr"] = {
                "value": resting_hr,
                "baseline": rhr_baseline,
                "score": rhr_score,
                "impact": "positive" if resting_hr <= rhr_baseline else "negative"
            }
            weighted_score += rhr_score * self.RECOVERY_WEIGHTS["resting_hr"]
            weights_used += self.RECOVERY_WEIGHTS["resting_hr"]

        # Training load component (moderate load is ideal)
        if training_load_7d >= 0:
            # Optimal training load: 200-500 arbitrary units
            if 200 <= training_load_7d <= 500:
                load_score = 90
            elif training_load_7d < 200:
                load_score = 70 + (training_load_7d / 200) * 20
            else:  # > 500 (overtraining risk)
                load_score = max(30, 90 - (training_load_7d - 500) * 0.12)

            factors["training_load"] = {
                "value": training_load_7d,
                "score": load_score,
                "impact": "positive" if 200 <= training_load_7d <= 500 else "negative"
            }
            weighted_score += load_score * self.RECOVERY_WEIGHTS["training_load_7d"]
            weights_used += self.RECOVERY_WEIGHTS["training_load_7d"]

        # Stress component (lower is better)
        stress_score = max(0, (10 - stress_level) / 10 * 100)
        factors["stress"] = {
            "value": stress_level,
            "score": stress_score,
            "impact": "positive" if stress_level <= 4 else "negative"
        }
        weighted_score += stress_score * self.RECOVERY_WEIGHTS["stress"]
        weights_used += self.RECOVERY_WEIGHTS["stress"]

        # Calculate final score
        if weights_used > 0:
            score = weighted_score / weights_used
        else:
            score = 50.0  # Default neutral score

        # Confidence based on data completeness
        confidence = min(1.0, weights_used / sum(self.RECOVERY_WEIGHTS.values()))

        # Determine status
        if score >= 80:
            status = "recovered"
        elif score >= 50:
            status = "moderate"
        else:
            status = "fatigued"

        # Generate recommendations
        recommendations = self._generate_recovery_recommendations(factors, score)

        return RecoveryResult(
            score=round(score, 1),
            confidence=round(confidence, 2),
            status=status,
            contributing_factors=factors,
            recommendations=recommendations,
        )

    def _generate_recovery_recommendations(
        self, factors: dict, score: float
    ) -> list[str]:
        """Generate personalized recovery recommendations."""
        recommendations = []

        if "sleep_hours" in factors and factors["sleep_hours"]["score"] < 70:
            recommendations.append(
                f"Aim for 7-9 hours of sleep. You got {factors['sleep_hours']['value']:.1f} hours."
            )

        if "sleep_quality" in factors and factors["sleep_quality"]["score"] < 70:
            recommendations.append(
                "Improve sleep quality: avoid screens 1hr before bed, keep room cool and dark."
            )

        if "hrv" in factors and factors["hrv"]["impact"] == "negative":
            recommendations.append(
                "Your HRV is below baseline. Consider light activity or rest today."
            )

        if "resting_hr" in factors and factors["resting_hr"]["impact"] == "negative":
            recommendations.append(
                "Elevated resting HR may indicate incomplete recovery or stress."
            )

        if "training_load" in factors and factors["training_load"]["value"] > 500:
            recommendations.append(
                "High training load this week. Consider a recovery day."
            )

        if "stress" in factors and factors["stress"]["value"] > 6:
            recommendations.append(
                "High stress levels detected. Try meditation or breathing exercises."
            )

        if score >= 80 and not recommendations:
            recommendations.append("Great recovery! You're ready for a challenging workout.")
        elif not recommendations:
            recommendations.append("Maintain consistent sleep and recovery habits.")

        return recommendations

    def calculate_readiness_score(
        self,
        recovery_score: float = 70.0,
        sleep_quality: float = 70.0,
        days_since_hard_workout: int = 2,
        energy_level: float = 7.0,
        muscle_soreness: float = 3.0,
    ) -> ReadinessResult:
        """Calculate training readiness score (0-100).

        Args:
            recovery_score: Current recovery score (0-100)
            sleep_quality: Last night's sleep quality (0-100)
            days_since_hard_workout: Days since last intense session
            energy_level: Subjective energy (1-10)
            muscle_soreness: Muscle soreness level (1-10, lower is better)

        Returns:
            ReadinessResult with score, confidence, intensity recommendation, factors
        """
        factors = {}

        # Recovery score component
        factors["recovery"] = {
            "value": recovery_score,
            "score": recovery_score,
            "impact": "positive" if recovery_score > 70 else "negative"
        }

        # Sleep quality component
        factors["sleep"] = {
            "value": sleep_quality,
            "score": sleep_quality,
            "impact": "positive" if sleep_quality > 70 else "negative"
        }

        # Days since hard workout (sweet spot: 1-3 days)
        if days_since_hard_workout == 0:
            rest_score = 40  # Just trained hard
        elif 1 <= days_since_hard_workout <= 3:
            rest_score = 90
        elif days_since_hard_workout > 5:
            rest_score = 70  # Might be detraining
        else:
            rest_score = 80

        factors["rest_days"] = {
            "value": days_since_hard_workout,
            "score": rest_score,
            "impact": "positive" if 1 <= days_since_hard_workout <= 3 else "neutral"
        }

        # Energy level (scale 1-10 -> 0-100)
        energy_score = (energy_level / 10) * 100
        factors["energy"] = {
            "value": energy_level,
            "score": energy_score,
            "impact": "positive" if energy_level >= 7 else "negative"
        }

        # Muscle soreness (lower is better)
        soreness_score = ((10 - muscle_soreness) / 10) * 100
        factors["soreness"] = {
            "value": muscle_soreness,
            "score": soreness_score,
            "impact": "positive" if muscle_soreness <= 4 else "negative"
        }

        # Calculate weighted score
        score = (
            factors["recovery"]["score"] * self.READINESS_WEIGHTS["recovery_score"] +
            factors["sleep"]["score"] * self.READINESS_WEIGHTS["sleep_quality"] +
            factors["rest_days"]["score"] * self.READINESS_WEIGHTS["days_since_hard_workout"] +
            factors["energy"]["score"] * self.READINESS_WEIGHTS["energy_level"] +
            factors["soreness"]["score"] * self.READINESS_WEIGHTS["muscle_soreness"]
        )

        # Determine recommended intensity
        if score >= 80:
            recommended_intensity = "hard"
            suggested_workouts = ["HIIT", "Strength Training", "Long Run", "Competition"]
        elif score >= 60:
            recommended_intensity = "moderate"
            suggested_workouts = ["Tempo Run", "Circuit Training", "Swimming", "Cycling"]
        elif score >= 40:
            recommended_intensity = "light"
            suggested_workouts = ["Yoga", "Walking", "Light Stretching", "Easy Swim"]
        else:
            recommended_intensity = "rest"
            suggested_workouts = ["Rest", "Meditation", "Gentle Stretching", "Massage"]

        return ReadinessResult(
            score=round(score, 1),
            confidence=0.85,  # Fixed confidence for rule-based model
            recommended_intensity=recommended_intensity,
            factors=factors,
            suggested_workout_types=suggested_workouts,
        )

    def calculate_wellness_score(
        self,
        sleep_score: float = 70.0,
        activity_score: float = 70.0,
        recovery_score: float = 70.0,
        nutrition_score: float = 70.0,
        stress_score: float = 70.0,
        mood_score: float = 70.0,
        baseline_wellness: float = 70.0,
        previous_scores: list[float] | None = None,
    ) -> WellnessResult:
        """Calculate overall wellness score (0-100).

        Args:
            sleep_score: Sleep quality score (0-100)
            activity_score: Physical activity score (0-100)
            recovery_score: Recovery status score (0-100)
            nutrition_score: Nutrition quality score (0-100)
            stress_score: Inverse stress score (0-100, higher = less stress)
            mood_score: Mood/mental health score (0-100)
            baseline_wellness: User's baseline wellness score
            previous_scores: List of recent wellness scores for trend analysis

        Returns:
            WellnessResult with overall score, components, trend, baseline comparison
        """
        components = {
            "sleep": round(sleep_score, 1),
            "activity": round(activity_score, 1),
            "recovery": round(recovery_score, 1),
            "nutrition": round(nutrition_score, 1),
            "stress_management": round(stress_score, 1),
            "mood": round(mood_score, 1),
        }

        # Calculate weighted overall score
        overall_score = (
            sleep_score * self.WELLNESS_WEIGHTS["sleep"] +
            activity_score * self.WELLNESS_WEIGHTS["activity"] +
            recovery_score * self.WELLNESS_WEIGHTS["recovery"] +
            nutrition_score * self.WELLNESS_WEIGHTS["nutrition"] +
            stress_score * self.WELLNESS_WEIGHTS["stress"] +
            mood_score * self.WELLNESS_WEIGHTS["mood"]
        )

        # Determine trend
        trend = "stable"
        if previous_scores and len(previous_scores) >= 3:
            recent_avg = np.mean(previous_scores[-3:])
            older_avg = np.mean(previous_scores[:-3]) if len(previous_scores) > 3 else recent_avg

            if recent_avg > older_avg + 5:
                trend = "improving"
            elif recent_avg < older_avg - 5:
                trend = "declining"

        # Compare to baseline
        comparison_to_baseline = round(overall_score - baseline_wellness, 1)

        return WellnessResult(
            overall_score=round(overall_score, 1),
            components=components,
            trend=trend,
            comparison_to_baseline=comparison_to_baseline,
        )


# Singleton instance for use across the app
predictor = FitnessPredictor()


def get_predictor() -> FitnessPredictor:
    """Get the fitness predictor instance."""
    return predictor
