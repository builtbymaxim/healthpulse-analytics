"""Tests for the recently logged foods feature."""

import pytest
from unittest.mock import MagicMock, patch
from uuid import UUID

from app.services.nutrition_service import NutritionService


USER_ID = UUID("00000000-0000-0000-0000-000000000001")

# Raw rows as Supabase would return them
SAMPLE_ENTRIES = [
    {"name": "Chicken Breast", "calories": 165.0, "protein_g": 31.0, "carbs_g": 0.0, "fat_g": 3.6, "fiber_g": 0.0, "logged_at": "2026-03-24T12:00:00"},
    {"name": "White Rice",    "calories": 130.0, "protein_g": 2.7,  "carbs_g": 28.0, "fat_g": 0.3, "fiber_g": 0.4, "logged_at": "2026-03-24T11:00:00"},
    {"name": "Chicken Breast", "calories": 165.0, "protein_g": 31.0, "carbs_g": 0.0, "fat_g": 3.6, "fiber_g": 0.0, "logged_at": "2026-03-23T12:00:00"},
    {"name": "Oats",           "calories": 389.0, "protein_g": 17.0, "carbs_g": 66.0, "fat_g": 7.0, "fiber_g": 10.0, "logged_at": "2026-03-23T08:00:00"},
    {"name": "chicken breast", "calories": 165.0, "protein_g": 31.0, "carbs_g": 0.0, "fat_g": 3.6, "fiber_g": 0.0, "logged_at": "2026-03-22T12:00:00"},
]


@pytest.fixture
def service():
    svc = NutritionService.__new__(NutritionService)
    svc.calculator = MagicMock()
    svc.supabase = MagicMock()
    return svc


class TestGetRecentFoods:
    """Tests for NutritionService.get_recent_foods."""

    @pytest.mark.asyncio
    async def test_deduplicates_by_name_case_insensitive(self, service):
        """'Chicken Breast' and 'chicken breast' should collapse into one entry."""
        service.supabase.table.return_value.select.return_value \
            .eq.return_value.order.return_value.limit.return_value \
            .execute.return_value.data = SAMPLE_ENTRIES

        result = await service.get_recent_foods(USER_ID)

        names = [r["name"] for r in result]
        assert names.count("Chicken Breast") == 1, "Duplicate names should be collapsed"

    @pytest.mark.asyncio
    async def test_frequency_counts_all_occurrences(self, service):
        """Chicken Breast appears 3 times (two exact + one lowercase)."""
        service.supabase.table.return_value.select.return_value \
            .eq.return_value.order.return_value.limit.return_value \
            .execute.return_value.data = SAMPLE_ENTRIES

        result = await service.get_recent_foods(USER_ID)

        chicken = next(r for r in result if r["name"] == "Chicken Breast")
        assert chicken["frequency"] == 3

    @pytest.mark.asyncio
    async def test_respects_limit(self, service):
        """Result length should not exceed the requested limit."""
        service.supabase.table.return_value.select.return_value \
            .eq.return_value.order.return_value.limit.return_value \
            .execute.return_value.data = SAMPLE_ENTRIES

        result = await service.get_recent_foods(USER_ID, limit=2)
        assert len(result) <= 2

    @pytest.mark.asyncio
    async def test_returns_most_recent_first(self, service):
        """First result should be the most recently logged distinct food."""
        service.supabase.table.return_value.select.return_value \
            .eq.return_value.order.return_value.limit.return_value \
            .execute.return_value.data = SAMPLE_ENTRIES

        result = await service.get_recent_foods(USER_ID)
        assert result[0]["name"] == "Chicken Breast"

    @pytest.mark.asyncio
    async def test_empty_history_returns_empty_list(self, service):
        """No food entries should return an empty list without error."""
        service.supabase.table.return_value.select.return_value \
            .eq.return_value.order.return_value.limit.return_value \
            .execute.return_value.data = []

        result = await service.get_recent_foods(USER_ID)
        assert result == []

    @pytest.mark.asyncio
    async def test_macro_values_are_floats(self, service):
        """All macro fields should be floats, not strings."""
        service.supabase.table.return_value.select.return_value \
            .eq.return_value.order.return_value.limit.return_value \
            .execute.return_value.data = SAMPLE_ENTRIES

        result = await service.get_recent_foods(USER_ID)
        for food in result:
            assert isinstance(food["calories_per_100g"], float)
            assert isinstance(food["protein_g_per_100g"], float)
            assert isinstance(food["carbs_g_per_100g"], float)
            assert isinstance(food["fat_g_per_100g"], float)
