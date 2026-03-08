"""Prediction service that combines user data with ML models."""

from __future__ import annotations

import logging
from datetime import datetime, date, timedelta
from uuid import UUID

from app.database import get_supabase_client
from app.ml.ml_models import get_predictor, RecoveryResult, ReadinessResult, WellnessResult

logger = logging.getLogger(__name__)


class PredictionService:
    """Service for generating ML predictions from user data."""

    def __init__(self):
        self.predictor = get_predictor()
        self.supabase = get_supabase_client()

    def _get_latest_metrics_batch(self, user_id: UUID, metric_types: list[str], since: str | None = None) -> dict[str, dict]:
        """Fetch latest value for multiple metric types in one query.

        Returns dict keyed by metric_type with the latest row for each.
        """
        query = (
            self.supabase.table("health_metrics")
            .select("*")
            .eq("user_id", str(user_id))
            .in_("metric_type", metric_types)
            .order("timestamp", desc=True)
        )
        if since:
            query = query.gte("timestamp", since)
        result = query.limit(len(metric_types) * 3).execute()  # fetch enough rows

        # Keep only the latest per metric_type
        latest: dict[str, dict] = {}
        for row in result.data or []:
            mt = row["metric_type"]
            if mt not in latest:
                latest[mt] = row
        return latest

    async def get_recovery_prediction(self, user_id: UUID) -> RecoveryResult:
        """Get recovery score for a user based on their recent data."""
        logger.debug("Generating recovery prediction for user %s", user_id)
        today = date.today()
        week_ago = today - timedelta(days=7)
        month_ago = today - timedelta(days=30)

        # Batch fetch all health metrics — use 30-day window so users who
        # haven't logged recently still get their most recent data
        metrics = self._get_latest_metrics_batch(
            user_id,
            ["sleep_duration", "hrv", "resting_hr", "stress", "sleep_quality"],
            since=month_ago.isoformat(),
        )

        # Calculate 7-day training load from workouts (keep 7-day window for load)
        workouts = (
            self.supabase.table("workouts")
            .select("training_load")
            .eq("user_id", str(user_id))
            .gte("start_time", week_ago.isoformat())
            .execute()
        )

        training_load_7d = sum(w.get("training_load", 0) or 0 for w in workouts.data) if workouts.data else 0

        # Get user profile for baselines
        profile = (
            self.supabase.table("profiles")
            .select("*")
            .eq("id", str(user_id))
            .single()
            .execute()
        )

        # Extract values — optional metrics default to None so the model
        # skips them rather than using fake data for missing entries
        sleep_hours = metrics.get("sleep_duration", {}).get("value", 7.0)
        sleep_quality = metrics.get("sleep_quality", {}).get("value")  # None if missing
        hrv = metrics.get("hrv", {}).get("value") if "hrv" in metrics else None
        resting_hr = metrics.get("resting_hr", {}).get("value") if "resting_hr" in metrics else None
        stress_level = metrics.get("stress", {}).get("value")  # None if missing

        # Get baselines from profile settings or use defaults
        hrv_baseline = 50.0
        rhr_baseline = 60.0
        if profile.data and profile.data.get("settings"):
            settings = profile.data["settings"]
            hrv_baseline = settings.get("hrv_baseline", 50.0)
            rhr_baseline = settings.get("rhr_baseline", 60.0)

        return self.predictor.calculate_recovery_score(
            sleep_hours=sleep_hours,
            sleep_quality=sleep_quality,
            hrv=hrv,
            resting_hr=resting_hr,
            training_load_7d=training_load_7d,
            stress_level=stress_level,
            hrv_baseline=hrv_baseline,
            rhr_baseline=rhr_baseline,
        )

    async def get_readiness_prediction(self, user_id: UUID) -> ReadinessResult:
        """Get training readiness score for a user."""
        logger.debug("Generating readiness prediction for user %s", user_id)
        # First get recovery score
        recovery = await self.get_recovery_prediction(user_id)

        # Batch fetch readiness-specific metrics in ONE query (was 4 separate)
        metrics = self._get_latest_metrics_batch(
            user_id,
            ["sleep_quality", "energy_level", "soreness"],
        )

        sleep_quality = metrics.get("sleep_quality", {}).get("value")   # None if missing
        energy_level = metrics.get("energy_level", {}).get("value")     # None if missing
        muscle_soreness = metrics.get("soreness", {}).get("value")      # None if missing

        # Find days since last hard workout
        hard_workouts = (
            self.supabase.table("workouts")
            .select("start_time")
            .eq("user_id", str(user_id))
            .in_("intensity", ["hard", "very_hard"])
            .order("start_time", desc=True)
            .limit(1)
            .execute()
        )

        days_since_hard = 3  # Default
        if hard_workouts.data:
            last_hard = datetime.fromisoformat(hard_workouts.data[0]["start_time"].replace("Z", "+00:00"))
            days_since_hard = (datetime.now(last_hard.tzinfo) - last_hard).days

        return self.predictor.calculate_readiness_score(
            recovery_score=recovery["score"],
            sleep_quality=sleep_quality,
            days_since_hard_workout=days_since_hard,
            energy_level=energy_level,
            muscle_soreness=muscle_soreness,
        )

    async def get_wellness_score(self, user_id: UUID, target_date: date | None = None) -> WellnessResult:
        """Get wellness score for a user on a specific date."""
        target = target_date or date.today()
        logger.debug("Fetching wellness score for user %s date=%s", user_id, target)

        # Try to get existing daily score
        existing_score = (
            self.supabase.table("daily_scores")
            .select("*")
            .eq("user_id", str(user_id))
            .eq("date", target.isoformat())
            .limit(1)
            .execute()
        )

        if existing_score.data:
            logger.debug("Returning cached wellness score for user %s date=%s", user_id, target)
            data = existing_score.data[0]
            return WellnessResult(
                wellness_score=data.get("wellness_score", 70.0),
                components={
                    "sleep": data.get("sleep_score", 70.0),
                    "activity": data.get("activity_score", 70.0),
                    "recovery": data.get("recovery_score", 70.0),
                    "nutrition": data.get("nutrition_score", 70.0),
                    "stress_management": data.get("stress_score", 70.0),
                    "mood": data.get("mood_score", 70.0),
                },
                trend=data.get("trend", "stable"),
                comparison_to_baseline=data.get("wellness_score", 70.0) - 70.0,
            )

        # Calculate from metrics if no daily score exists
        recovery = await self.get_recovery_prediction(user_id)

        # Get component scores from metrics
        metrics = (
            self.supabase.table("health_metrics")
            .select("metric_type, value")
            .eq("user_id", str(user_id))
            .gte("timestamp", target.isoformat())
            .lt("timestamp", (target + timedelta(days=1)).isoformat())
            .execute()
        )

        sleep_score = 70.0
        activity_score = 70.0
        nutrition_score = 70.0
        stress_score = 70.0
        mood_score = 70.0

        for metric in metrics.data or []:
            mtype = metric.get("metric_type")
            value = metric.get("value", 0)

            if mtype == "sleep_quality":
                sleep_score = value
            elif mtype == "steps":
                # Convert steps to score (10k steps = 100)
                activity_score = min(100, (value / 10000) * 100)
            elif mtype == "calories_in":
                # Nutrition score based on meeting calorie goals
                nutrition_score = min(100, value / 20)  # Simplified
            elif mtype == "stress":
                # Invert stress (lower stress = higher score)
                stress_score = max(0, (10 - value) / 10 * 100)
            elif mtype == "mood":
                mood_score = (value / 10) * 100

        # Get historical scores for trend
        history = (
            self.supabase.table("daily_scores")
            .select("wellness_score")
            .eq("user_id", str(user_id))
            .lt("date", target.isoformat())
            .order("date", desc=True)
            .limit(7)
            .execute()
        )

        previous_scores = [s["wellness_score"] for s in history.data] if history.data else None

        return self.predictor.calculate_wellness_score(
            sleep_score=sleep_score,
            activity_score=activity_score,
            recovery_score=recovery["score"],
            nutrition_score=nutrition_score,
            stress_score=stress_score,
            mood_score=mood_score,
            previous_scores=previous_scores,
        )

    async def get_wellness_history(self, user_id: UUID, days: int = 30) -> list[dict]:
        """Get wellness score history for a user."""
        start_date = date.today() - timedelta(days=days)

        history = (
            self.supabase.table("daily_scores")
            .select("*")
            .eq("user_id", str(user_id))
            .gte("date", start_date.isoformat())
            .order("date", desc=True)
            .execute()
        )

        results = []
        for record in history.data or []:
            results.append({
                "date": record["date"],
                "wellness_score": record.get("wellness_score", 70.0),
                "components": {
                    "sleep": record.get("sleep_score", 70.0),
                    "activity": record.get("activity_score", 70.0),
                    "recovery": record.get("recovery_score", 70.0),
                    "nutrition": record.get("nutrition_score", 70.0),
                    "stress_management": record.get("stress_score", 70.0),
                    "mood": record.get("mood_score", 70.0),
                },
                "trend": record.get("trend", "stable"),
                "comparison_to_baseline": record.get("wellness_score", 70.0) - 70.0,
            })

        return results

    async def analyze_correlations(self, user_id: UUID) -> list[dict]:
        """Analyze correlations in user's health data."""
        logger.debug("Analyzing health correlations for user %s", user_id)
        # Get last 30 days of metrics
        start_date = date.today() - timedelta(days=30)

        metrics = (
            self.supabase.table("health_metrics")
            .select("metric_type, value, timestamp")
            .eq("user_id", str(user_id))
            .gte("timestamp", start_date.isoformat())
            .order("timestamp")
            .execute()
        )

        if not metrics.data or len(metrics.data) < 10:
            return []

        # Group by metric type
        import numpy as np
        from collections import defaultdict

        by_type = defaultdict(list)
        for m in metrics.data:
            by_type[m["metric_type"]].append(m["value"])

        correlations = []

        # Calculate correlations between metric pairs
        metric_types = list(by_type.keys())
        for i, type_a in enumerate(metric_types):
            for type_b in metric_types[i + 1:]:
                values_a = by_type[type_a]
                values_b = by_type[type_b]

                # Ensure same length
                min_len = min(len(values_a), len(values_b))
                if min_len < 5:
                    continue

                arr_a = np.array(values_a[:min_len])
                arr_b = np.array(values_b[:min_len])

                # Calculate Pearson correlation
                if np.std(arr_a) > 0 and np.std(arr_b) > 0:
                    corr = np.corrcoef(arr_a, arr_b)[0, 1]

                    if abs(corr) > 0.3:  # Only report meaningful correlations
                        insight = self._generate_correlation_insight(type_a, type_b, corr)
                        correlations.append({
                            "factor_a": type_a,
                            "factor_b": type_b,
                            "correlation": round(corr, 3),
                            "insight": insight,
                            "data_points": min_len,
                            "confidence": min(0.95, min_len / 30),
                        })

        # Sort by absolute correlation strength
        correlations.sort(key=lambda x: abs(x["correlation"]), reverse=True)
        return correlations[:10]  # Top 10 correlations

    def _generate_correlation_insight(self, factor_a: str, factor_b: str, corr: float) -> str:
        """Generate human-readable insight from correlation."""
        strength = "strong" if abs(corr) > 0.7 else "moderate"
        direction = "positive" if corr > 0 else "negative"

        factor_names = {
            "sleep": "sleep quality",
            "hrv": "heart rate variability",
            "resting_hr": "resting heart rate",
            "steps": "daily steps",
            "stress": "stress levels",
            "mood": "mood",
            "energy": "energy levels",
            "weight": "body weight",
        }

        name_a = factor_names.get(factor_a, factor_a)
        name_b = factor_names.get(factor_b, factor_b)

        if direction == "positive":
            return f"There's a {strength} positive relationship between your {name_a} and {name_b}. When one increases, the other tends to increase too."
        else:
            return f"There's a {strength} negative relationship between your {name_a} and {name_b}. When one increases, the other tends to decrease."


# Singleton instance
_service: PredictionService | None = None


def get_prediction_service() -> PredictionService:
    """Get or create the prediction service instance."""
    global _service
    if _service is None:
        _service = PredictionService()
    return _service
