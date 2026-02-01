"""Prediction service that combines user data with ML models."""

from __future__ import annotations

from datetime import datetime, date, timedelta
from uuid import UUID

from app.database import get_supabase_client
from app.ml.ml_models import get_predictor, RecoveryResult, ReadinessResult, WellnessResult


class PredictionService:
    """Service for generating ML predictions from user data."""

    def __init__(self):
        self.predictor = get_predictor()
        self.supabase = get_supabase_client()

    async def get_recovery_prediction(self, user_id: UUID) -> RecoveryResult:
        """Get recovery score for a user based on their recent data."""
        # Fetch recent metrics
        today = date.today()
        week_ago = today - timedelta(days=7)

        # Get latest sleep data
        sleep_data = (
            self.supabase.table("health_metrics")
            .select("*")
            .eq("user_id", str(user_id))
            .eq("metric_type", "sleep_duration")
            .gte("timestamp", week_ago.isoformat())
            .order("timestamp", desc=True)
            .limit(1)
            .execute()
        )

        # Get latest HRV data
        hrv_data = (
            self.supabase.table("health_metrics")
            .select("*")
            .eq("user_id", str(user_id))
            .eq("metric_type", "hrv")
            .gte("timestamp", week_ago.isoformat())
            .order("timestamp", desc=True)
            .limit(1)
            .execute()
        )

        # Get latest resting HR
        rhr_data = (
            self.supabase.table("health_metrics")
            .select("*")
            .eq("user_id", str(user_id))
            .eq("metric_type", "resting_hr")
            .gte("timestamp", week_ago.isoformat())
            .order("timestamp", desc=True)
            .limit(1)
            .execute()
        )

        # Get latest stress level
        stress_data = (
            self.supabase.table("health_metrics")
            .select("*")
            .eq("user_id", str(user_id))
            .eq("metric_type", "stress")
            .gte("timestamp", week_ago.isoformat())
            .order("timestamp", desc=True)
            .limit(1)
            .execute()
        )

        # Calculate 7-day training load from workouts
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

        # Extract values with defaults
        sleep_hours = 7.0
        sleep_quality = 70.0
        hrv = None
        resting_hr = None
        stress_level = 5.0

        if sleep_data.data:
            sleep_hours = sleep_data.data[0].get("value", 7.0)

        # Get sleep quality separately
        sleep_quality_data = (
            self.supabase.table("health_metrics")
            .select("value")
            .eq("user_id", str(user_id))
            .eq("metric_type", "sleep_quality")
            .order("timestamp", desc=True)
            .limit(1)
            .execute()
        )
        if sleep_quality_data.data:
            sleep_quality = sleep_quality_data.data[0].get("value", 70.0)

        if hrv_data.data:
            hrv = hrv_data.data[0].get("value")

        if rhr_data.data:
            resting_hr = rhr_data.data[0].get("value")

        if stress_data.data:
            stress_level = stress_data.data[0].get("value", 5.0)

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
        # First get recovery score
        recovery = await self.get_recovery_prediction(user_id)

        # Get latest sleep quality
        sleep_data = (
            self.supabase.table("health_metrics")
            .select("*")
            .eq("user_id", str(user_id))
            .eq("metric_type", "sleep_duration")
            .order("timestamp", desc=True)
            .limit(1)
            .execute()
        )

        sleep_quality = 70.0
        # Get sleep quality as separate metric
        sleep_quality_data = (
            self.supabase.table("health_metrics")
            .select("value")
            .eq("user_id", str(user_id))
            .eq("metric_type", "sleep_quality")
            .order("timestamp", desc=True)
            .limit(1)
            .execute()
        )
        if sleep_quality_data.data:
            sleep_quality = sleep_quality_data.data[0].get("value", 70.0)

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

        # Get energy and soreness from daily scores or metrics
        energy_data = (
            self.supabase.table("health_metrics")
            .select("value")
            .eq("user_id", str(user_id))
            .eq("metric_type", "energy_level")
            .order("timestamp", desc=True)
            .limit(1)
            .execute()
        )

        soreness_data = (
            self.supabase.table("health_metrics")
            .select("value")
            .eq("user_id", str(user_id))
            .eq("metric_type", "soreness")
            .order("timestamp", desc=True)
            .limit(1)
            .execute()
        )

        energy_level = energy_data.data[0]["value"] if energy_data.data else 7.0
        muscle_soreness = soreness_data.data[0]["value"] if soreness_data.data else 3.0

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
