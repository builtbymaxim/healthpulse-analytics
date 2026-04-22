"""Tests for DashboardService._build_daily_actions query count."""

from unittest.mock import MagicMock
from uuid import UUID

import pytest

from app.services.dashboard_service import DashboardService


USER_ID = UUID("00000000-0000-0000-0000-000000000002")


@pytest.fixture
def service():
    """DashboardService with all external dependencies mocked."""
    svc = DashboardService.__new__(DashboardService)
    svc.supabase = MagicMock()
    svc._plan_schedule_cache = {}  # noqa: SLF001
    svc.prediction_service = MagicMock()
    svc.exercise_service = MagicMock()
    svc.sleep_service = MagicMock()
    svc.nutrition_service = MagicMock()
    chain = MagicMock()
    for attr in ("select", "eq", "gte", "lt", "limit", "order"):
        getattr(chain, attr).return_value = chain
    chain.execute.return_value = MagicMock(data=[])
    svc.supabase.table.return_value = chain
    return svc


class TestBuildDailyActions:
    """Tests for DashboardService._build_daily_actions."""

    @pytest.mark.asyncio
    async def test_exactly_three_supabase_queries(self, service):
        """_build_daily_actions must issue exactly 3 Supabase table queries."""
        await service._build_daily_actions(USER_ID, today_workout=None)  # noqa: SLF001

        assert service.supabase.table.call_count == 3

    @pytest.mark.asyncio
    async def test_queries_correct_tables(self, service):
        """Queries must target food_entries, workout_sessions, health_metrics."""
        await service._build_daily_actions(USER_ID, today_workout=None)  # noqa: SLF001

        queried = [c.args[0] for c in service.supabase.table.call_args_list]
        assert "food_entries" in queried
        assert "workout_sessions" in queried
        assert "health_metrics" in queried

    @pytest.mark.asyncio
    async def test_no_workout_action_without_plan(self, service):
        """No workout action should appear when today_workout is None."""
        actions = await service._build_daily_actions(USER_ID, today_workout=None)  # noqa: SLF001

        assert "log_workout" not in {a.id for a in actions}

    @pytest.mark.asyncio
    async def test_workout_action_present_with_plan(self, service):
        """Workout action should appear when a plan name is provided."""
        actions = await service._build_daily_actions(USER_ID, today_workout="Bench Press")  # noqa: SLF001

        assert "log_workout" in {a.id for a in actions}
