"""Tests for ETag computation in the narrative dashboard service."""

from unittest.mock import MagicMock, patch
from uuid import UUID

import pytest

from app.services.dashboard_service import (
    DashboardService, DashboardResponse, EnhancedRecoveryResponse,
    ProgressSummary, WeeklySummary,
)


USER_ID = UUID("00000000-0000-0000-0000-000000000004")


def _minimal_dashboard(score: float = 70) -> DashboardResponse:
    return DashboardResponse(
        enhanced_recovery=EnhancedRecoveryResponse(
            score=score, status="good", factors=[], primary_recommendation="Rest"
        ),
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


@pytest.fixture
def service():
    """DashboardService with all external dependencies mocked."""
    svc = DashboardService.__new__(DashboardService)
    svc.supabase = MagicMock()
    svc._plan_schedule_cache = {}  # noqa: SLF001
    for attr in ("prediction_service", "exercise_service", "sleep_service", "nutrition_service"):
        setattr(svc, attr, MagicMock())
    chain = MagicMock()
    for m in ("select", "eq", "gte", "lt", "lte", "limit", "order"):
        getattr(chain, m).return_value = chain
    chain.execute.return_value = MagicMock(data=[])
    svc.supabase.table.return_value = chain
    return svc


@pytest.fixture(autouse=True)
def clear_cache():
    DashboardService._narrative_cache.clear()  # noqa: SLF001
    yield
    DashboardService._narrative_cache.clear()  # noqa: SLF001


class TestNarrativeETag:
    """Tests for ETag computation and stability."""

    @pytest.mark.asyncio
    async def test_returns_non_empty_etag(self, service):
        """get_narrative_dashboard must return a non-empty ETag string."""
        with patch.object(service, "get_dashboard", return_value=_minimal_dashboard()):
            _, etag = await service.get_narrative_dashboard(USER_ID)

        assert isinstance(etag, str) and len(etag) > 0

    @pytest.mark.asyncio
    async def test_etag_is_deterministic(self, service):
        """Same payload across two cold calls must produce identical ETags."""
        with patch.object(service, "get_dashboard", return_value=_minimal_dashboard()):
            _, etag1 = await service.get_narrative_dashboard(USER_ID)

        DashboardService._narrative_cache.clear()  # noqa: SLF001

        with patch.object(service, "get_dashboard", return_value=_minimal_dashboard()):
            _, etag2 = await service.get_narrative_dashboard(USER_ID)

        assert etag1 == etag2

    @pytest.mark.asyncio
    async def test_etag_changes_when_data_changes(self, service):
        """Different readiness scores must produce different ETags."""
        with patch.object(service, "get_dashboard", return_value=_minimal_dashboard(score=60)):
            _, etag_a = await service.get_narrative_dashboard(USER_ID)

        DashboardService._narrative_cache.clear()  # noqa: SLF001

        with patch.object(service, "get_dashboard", return_value=_minimal_dashboard(score=90)):
            _, etag_b = await service.get_narrative_dashboard(USER_ID)

        assert etag_a != etag_b

    @pytest.mark.asyncio
    async def test_cached_call_returns_same_etag(self, service):
        """A cache-hit call must return the same ETag as the original population call."""
        with patch.object(service, "get_dashboard", return_value=_minimal_dashboard()):
            _, etag_first = await service.get_narrative_dashboard(USER_ID)
            _, etag_cached = await service.get_narrative_dashboard(USER_ID)

        assert etag_first == etag_cached
