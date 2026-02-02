"""Sleep tracking and analysis service."""

from __future__ import annotations

from datetime import datetime, date, timedelta
from uuid import UUID
from pydantic import BaseModel

from app.database import get_supabase_client


class SleepEntry(BaseModel):
    """A single night's sleep data."""
    date: str
    duration_hours: float
    quality: float | None = None
    deep_sleep_hours: float | None = None
    rem_sleep_hours: float | None = None
    light_sleep_hours: float | None = None
    awake_time_minutes: float | None = None
    sleep_score: float | None = None


class SleepSummary(BaseModel):
    """Daily sleep summary."""
    date: str
    duration_hours: float
    quality: float
    deep_sleep_hours: float
    rem_sleep_hours: float
    light_sleep_hours: float
    sleep_score: float
    target_hours: float = 8.0
    duration_vs_target_pct: float
    quality_trend: str  # up, down, stable


class SleepAnalytics(BaseModel):
    """Sleep analytics over a period."""
    period_days: int
    avg_duration_hours: float
    avg_quality: float
    avg_deep_sleep_hours: float
    avg_rem_sleep_hours: float
    avg_sleep_score: float
    total_sleep_debt_hours: float
    best_night: SleepEntry | None
    worst_night: SleepEntry | None
    consistency_score: float  # How consistent sleep/wake times are
    trend: str  # improving, declining, stable


class SleepService:
    """Service for sleep tracking and analysis."""

    def __init__(self):
        self.supabase = get_supabase_client()

    async def get_sleep_summary(self, user_id: UUID, target_date: date | None = None) -> SleepSummary | None:
        """Get sleep summary for a specific date. Returns None if no sleep data exists."""
        target = target_date or date.today()
        # Sleep data is usually logged for the previous night
        prev_day = target - timedelta(days=1)

        # Fetch sleep metrics for this date range
        metrics = await self._get_sleep_metrics(user_id, target, target)

        # If no sleep data exists, return None instead of defaults
        if not metrics or "sleep_duration" not in metrics:
            return None

        # Get previous 7 days for trend
        week_ago = target - timedelta(days=7)
        historical = await self._get_sleep_metrics(user_id, week_ago, prev_day)

        # Calculate values
        duration = metrics.get("sleep_duration", 0)
        quality = metrics.get("sleep_quality", 70.0)
        deep = metrics.get("deep_sleep", duration * 0.2)  # Default 20% deep
        rem = metrics.get("rem_sleep", duration * 0.25)   # Default 25% REM
        light = max(0, duration - deep - rem)

        # Calculate sleep score
        sleep_score = self._calculate_sleep_score(duration, quality, deep, rem)

        # Calculate trend
        avg_historical_quality = 70.0
        if historical and "sleep_quality" in historical:
            avg_historical_quality = historical["sleep_quality"]

        trend = "stable"
        if quality > avg_historical_quality + 5:
            trend = "up"
        elif quality < avg_historical_quality - 5:
            trend = "down"

        target_hours = 8.0
        duration_vs_target = (duration / target_hours) * 100

        return SleepSummary(
            date=target.isoformat(),
            duration_hours=round(duration, 1),
            quality=round(quality, 1),
            deep_sleep_hours=round(deep, 2),
            rem_sleep_hours=round(rem, 2),
            light_sleep_hours=round(light, 2),
            sleep_score=round(sleep_score, 1),
            target_hours=target_hours,
            duration_vs_target_pct=round(duration_vs_target, 1),
            quality_trend=trend,
        )

    async def get_sleep_history(self, user_id: UUID, days: int = 7) -> list[SleepEntry]:
        """Get sleep history for the past N days."""
        end_date = date.today()
        start_date = end_date - timedelta(days=days)

        entries = []
        current = start_date

        while current <= end_date:
            metrics = await self._get_sleep_metrics(user_id, current, current)

            duration = metrics.get("sleep_duration", 0)
            if duration > 0:
                quality = metrics.get("sleep_quality")
                deep = metrics.get("deep_sleep")
                rem = metrics.get("rem_sleep")

                sleep_score = None
                if duration and quality:
                    sleep_score = self._calculate_sleep_score(duration, quality, deep or 0, rem or 0)

                entries.append(SleepEntry(
                    date=current.isoformat(),
                    duration_hours=round(duration, 1),
                    quality=quality,
                    deep_sleep_hours=deep,
                    rem_sleep_hours=rem,
                    sleep_score=sleep_score,
                ))

            current += timedelta(days=1)

        return entries

    async def get_sleep_analytics(self, user_id: UUID, days: int = 30) -> SleepAnalytics:
        """Get comprehensive sleep analytics."""
        history = await self.get_sleep_history(user_id, days)

        if not history:
            return SleepAnalytics(
                period_days=days,
                avg_duration_hours=0,
                avg_quality=0,
                avg_deep_sleep_hours=0,
                avg_rem_sleep_hours=0,
                avg_sleep_score=0,
                total_sleep_debt_hours=0,
                best_night=None,
                worst_night=None,
                consistency_score=0,
                trend="stable",
            )

        # Calculate averages
        durations = [e.duration_hours for e in history]
        qualities = [e.quality for e in history if e.quality is not None]
        deep_sleeps = [e.deep_sleep_hours for e in history if e.deep_sleep_hours is not None]
        rem_sleeps = [e.rem_sleep_hours for e in history if e.rem_sleep_hours is not None]
        scores = [e.sleep_score for e in history if e.sleep_score is not None]

        avg_duration = sum(durations) / len(durations) if durations else 0
        avg_quality = sum(qualities) / len(qualities) if qualities else 70
        avg_deep = sum(deep_sleeps) / len(deep_sleeps) if deep_sleeps else avg_duration * 0.2
        avg_rem = sum(rem_sleeps) / len(rem_sleeps) if rem_sleeps else avg_duration * 0.25
        avg_score = sum(scores) / len(scores) if scores else 70

        # Calculate sleep debt (assuming 8 hour target)
        target = 8.0
        total_debt = sum(max(0, target - d) for d in durations)

        # Find best and worst nights
        best = max(history, key=lambda e: e.sleep_score or 0, default=None)
        worst = min(history, key=lambda e: e.sleep_score or 100, default=None)

        # Calculate consistency (lower std dev = more consistent)
        import statistics
        consistency = 100
        if len(durations) >= 2:
            std_dev = statistics.stdev(durations)
            consistency = max(0, 100 - (std_dev * 20))  # Higher std = lower consistency

        # Calculate trend
        if len(history) >= 7:
            recent = history[-7:]
            earlier = history[:-7] if len(history) > 7 else history[:3]

            recent_avg = sum(e.quality or 70 for e in recent) / len(recent)
            earlier_avg = sum(e.quality or 70 for e in earlier) / len(earlier)

            trend = "stable"
            if recent_avg > earlier_avg + 5:
                trend = "improving"
            elif recent_avg < earlier_avg - 5:
                trend = "declining"
        else:
            trend = "stable"

        return SleepAnalytics(
            period_days=days,
            avg_duration_hours=round(avg_duration, 1),
            avg_quality=round(avg_quality, 1),
            avg_deep_sleep_hours=round(avg_deep, 2),
            avg_rem_sleep_hours=round(avg_rem, 2),
            avg_sleep_score=round(avg_score, 1),
            total_sleep_debt_hours=round(total_debt, 1),
            best_night=best,
            worst_night=worst,
            consistency_score=round(consistency, 1),
            trend=trend,
        )

    async def log_sleep(
        self,
        user_id: UUID,
        duration_hours: float,
        quality: float | None = None,
        deep_sleep_hours: float | None = None,
        rem_sleep_hours: float | None = None,
        logged_for: date | None = None,
    ) -> dict:
        """Log sleep data manually."""
        target_date = logged_for or date.today()
        timestamp = datetime.combine(target_date, datetime.min.time())

        metrics_to_log = [
            {"metric_type": "sleep_duration", "value": duration_hours, "unit": "hours"},
        ]

        if quality is not None:
            metrics_to_log.append({"metric_type": "sleep_quality", "value": quality, "unit": "percent"})

        if deep_sleep_hours is not None:
            metrics_to_log.append({"metric_type": "deep_sleep", "value": deep_sleep_hours, "unit": "hours"})

        if rem_sleep_hours is not None:
            metrics_to_log.append({"metric_type": "rem_sleep", "value": rem_sleep_hours, "unit": "hours"})

        for metric in metrics_to_log:
            self.supabase.table("health_metrics").insert({
                "user_id": str(user_id),
                "metric_type": metric["metric_type"],
                "value": metric["value"],
                "unit": metric["unit"],
                "timestamp": timestamp.isoformat(),
                "source": "manual",
            }).execute()

        return {"message": "Sleep logged successfully", "date": target_date.isoformat()}

    async def _get_sleep_metrics(self, user_id: UUID, start: date, end: date) -> dict:
        """Get sleep metrics for a date range."""
        result = (
            self.supabase.table("health_metrics")
            .select("metric_type, value, timestamp")
            .eq("user_id", str(user_id))
            .in_("metric_type", ["sleep_duration", "sleep_quality", "deep_sleep", "rem_sleep"])
            .gte("timestamp", start.isoformat())
            .lte("timestamp", (end + timedelta(days=1)).isoformat())
            .execute()
        )

        # Group by metric type, take most recent
        metrics: dict[str, float] = {}
        for m in result.data or []:
            mtype = m["metric_type"]
            if mtype not in metrics:
                metrics[mtype] = m["value"]

        return metrics

    def _calculate_sleep_score(
        self, duration: float, quality: float, deep: float, rem: float
    ) -> float:
        """Calculate overall sleep score (0-100)."""
        # Duration component (35%): Optimal is 7-9 hours
        if 7 <= duration <= 9:
            duration_score = 100
        elif duration < 7:
            duration_score = max(0, (duration / 7) * 100)
        else:
            duration_score = max(0, 100 - (duration - 9) * 20)

        # Quality component (35%): Direct from quality metric
        quality_score = min(100, quality)

        # Deep sleep component (15%): Optimal is 1.5-2 hours / 20% of sleep
        optimal_deep = duration * 0.2
        if deep >= optimal_deep * 0.8:
            deep_score = 100
        else:
            deep_score = (deep / (optimal_deep * 0.8)) * 100

        # REM component (15%): Optimal is 1.5-2 hours / 25% of sleep
        optimal_rem = duration * 0.25
        if rem >= optimal_rem * 0.8:
            rem_score = 100
        else:
            rem_score = (rem / (optimal_rem * 0.8)) * 100

        return (
            duration_score * 0.35 +
            quality_score * 0.35 +
            deep_score * 0.15 +
            rem_score * 0.15
        )


# Singleton instance
_service: SleepService | None = None


def get_sleep_service() -> SleepService:
    """Get or create the sleep service instance."""
    global _service
    if _service is None:
        _service = SleepService()
    return _service
