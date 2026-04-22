"""Tests for DashboardService narrative dashboard in-process TTL cache."""

import pytest
from datetime import datetime, timezone, timedelta, date
from unittest.mock import MagicMock, patch
from uuid import UUID

from app.services.dashboard_service import (
    DashboardService, DashboardResponse, EnhancedRecoveryResponse,
    ProgressSummary, WeeklySummary,
)


USER_ID = UUID("00000000-0000-0000-0000-000000000003")


def _minimal_dashboard(score: float = 70) -> DashboardResponse:
    return DashboardResponse(
        enhanced_recovery=EnhancedRecoveryResponse(score=score, status="good", factors=[], primary_recommendation="Rest"),
        readiness_score=score,
        readiness_intensity="moderate",
        progress=ProgressSummary(
            key_lifts=[],
            total_volume_week=0.0,
            volume_trend_pct=0.0,
            recent_prs=[],
            muscle_balance=[],
        ),
        recommendations=[],
        weekly_summary=WeeklySummary(
            workouts_completed=0,
            workouts_planned=3,
            avg_sleep_score=70.0,
            nutrition_adherence_pct=0.0,
            highlights=[],
        ),
    )


def _db_chain(svc):
    chain = MagicMock()
    chain.select.return_value = chain
    chain.eq.return_value = chain
    chain.gte.return_value = chain
    chain.lt.return_value = chain
    chain.lte.return_value = chain
    chain.limit.return_value = chain
    chain.order.return_value = chain
    chain.execute.return_value = MagicMock(data=[])
    svc.supabase.table.return_value = chain
    return chain


@pytest.fixture
def service():
    svc = DashboardService.__new__(DashboardService)
    svc.supabase = MagicMock()
    svc._plan_schedule_cache = {}
    svc.prediction_service = MagicMock()
    svc.exercise_service = MagicMock()
    svc.sleep_service = MagicMock()
    svc.nutrition_service = MagicMock()
    _db_chain(svc)
    return svc


class TestNarrativeDashboardCache:
    def setup_method(self):
        DashboardService._narrative_cache.clear()

    @pytest.mark.asyncio
    async def test_second_call_within_ttl_uses_cache(self, service):
        """Second call within 60 s must skip re-running DB logic."""
        call_count = 0

        async def counting_get_dashboard(_):
            nonlocal call_count
            call_count += 1
            return _minimal_dashboard()

        with patch.object(service, "get_dashboard", side_effect=counting_get_dashboard):
            await service.get_narrative_dashboard(USER_ID)
            await service.get_narrative_dashboard(USER_ID)

        assert call_count == 1, "get_dashboard should run only once when cache is warm"

    @pytest.mark.asyncio
    async def test_expired_cache_triggers_recompute(self, service):
        """A cache entry older than TTL must not be used."""
        fake_payload = {"readiness_score": 50}
        fake_etag = "staleentry"
        expired = datetime.now(timezone.utc) - timedelta(seconds=1)
        DashboardService._narrative_cache[(str(USER_ID), date.today().isoformat())] = (
            fake_payload, fake_etag, expired
        )

        call_count = 0

        async def counting_get_dashboard(_):
            nonlocal call_count
            call_count += 1
            return _minimal_dashboard(score=80)

        with patch.object(service, "get_dashboard", side_effect=counting_get_dashboard):
            _, etag = await service.get_narrative_dashboard(USER_ID)

        assert call_count == 1, "Expired cache should trigger a fresh DB call"
        assert etag != fake_etag, "ETag must be recomputed for fresh data"

    @pytest.mark.asyncio
    async def test_returns_etag_tuple(self, service):
        """get_narrative_dashboard must return (NarrativeDashboardResponse, str)."""
        with patch.object(service, "get_dashboard", return_value=_minimal_dashboard()):
            result = await service.get_narrative_dashboard(USER_ID)

        assert isinstance(result, tuple) and len(result) == 2
        _, etag = result
        assert isinstance(etag, str) and len(etag) > 0

    @pytest.mark.asyncio
    async def test_same_data_produces_same_etag(self, service):
        """Identical payloads from two separate calls must yield the same ETag."""
        with patch.object(service, "get_dashboard", return_value=_minimal_dashboard()):
            _, etag1 = await service.get_narrative_dashboard(USER_ID)

        DashboardService._narrative_cache.clear()

        with patch.object(service, "get_dashboard", return_value=_minimal_dashboard()):
            _, etag2 = await service.get_narrative_dashboard(USER_ID)

        assert etag1 == etag2, "Deterministic ETag must be stable across calls with same data"
