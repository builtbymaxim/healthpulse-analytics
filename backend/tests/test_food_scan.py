"""Tests for AI food scanning models and service."""

import pytest
from unittest.mock import AsyncMock

from app.models.food_scan import FoodScanRequest, FoodScanResponse, ScannedFoodItem
from app.services.food_scan_service import FoodScanService


class TestFoodScanModels:
    """Test Pydantic model validation."""

    def test_food_scan_request_valid(self):
        req = FoodScanRequest(image_base64="abc123", classification_hints=["pizza"])
        assert req.image_base64 == "abc123"
        assert req.classification_hints == ["pizza"]

    def test_food_scan_request_empty_hints(self):
        req = FoodScanRequest(image_base64="abc123")
        assert req.classification_hints == []

    def test_scanned_food_item_auto_uuid(self):
        item = ScannedFoodItem(
            name="Pizza",
            portion_description="1 slice (~120g)",
            portion_grams=120,
            calories=285,
            protein_g=12,
            carbs_g=36,
            fat_g=10,
            fiber_g=2,
            confidence=0.92,
        )
        assert item.id is not None
        assert item.name == "Pizza"
        assert item.calories == 285

    def test_scanned_food_item_confidence_upper_bound(self):
        with pytest.raises(ValueError):
            ScannedFoodItem(
                name="X",
                portion_description="",
                portion_grams=0,
                calories=0,
                protein_g=0,
                carbs_g=0,
                fat_g=0,
                confidence=1.5,
            )

    def test_scanned_food_item_confidence_lower_bound(self):
        with pytest.raises(ValueError):
            ScannedFoodItem(
                name="X",
                portion_description="",
                portion_grams=0,
                calories=0,
                protein_g=0,
                carbs_g=0,
                fat_g=0,
                confidence=-0.1,
            )

    def test_food_scan_response(self):
        resp = FoodScanResponse(items=[], processing_time_ms=150, provider="gemini")
        assert resp.provider == "gemini"
        assert resp.items == []
        assert resp.processing_time_ms == 150

    def test_food_scan_response_with_items(self):
        item = ScannedFoodItem(
            name="Rice",
            portion_description="1 cup (~200g)",
            portion_grams=200,
            calories=260,
            protein_g=5,
            carbs_g=57,
            fat_g=0.5,
            confidence=0.88,
        )
        resp = FoodScanResponse(items=[item], processing_time_ms=1200, provider="openai")
        assert len(resp.items) == 1
        assert resp.items[0].name == "Rice"


class TestFoodScanService:
    """Test vision service with mocked API calls."""

    @pytest.mark.asyncio
    async def test_analyze_food_returns_items(self):
        mock_provider = AsyncMock()
        mock_provider.analyze_food_image.return_value = {
            "items": [
                {
                    "name": "Chicken Breast",
                    "portion_description": "1 medium (~170g)",
                    "portion_grams": 170,
                    "calories": 280,
                    "protein_g": 53,
                    "carbs_g": 0,
                    "fat_g": 6,
                    "fiber_g": 0,
                    "confidence": 0.95,
                }
            ]
        }

        service = FoodScanService.__new__(FoodScanService)
        service.provider = mock_provider
        service.provider_name = "test"

        result = await service.analyze_food("base64data", ["chicken"])

        assert len(result["items"]) == 1
        assert result["items"][0]["name"] == "Chicken Breast"
        assert result["provider"] == "test"
        assert "processing_time_ms" in result
        assert result["processing_time_ms"] >= 0
        assert "id" in result["items"][0]

    @pytest.mark.asyncio
    async def test_analyze_food_empty_response(self):
        mock_provider = AsyncMock()
        mock_provider.analyze_food_image.return_value = {"items": []}

        service = FoodScanService.__new__(FoodScanService)
        service.provider = mock_provider
        service.provider_name = "test"

        result = await service.analyze_food("", [])
        assert result["items"] == []
        assert result["provider"] == "test"

    @pytest.mark.asyncio
    async def test_analyze_food_provider_error_propagates(self):
        mock_provider = AsyncMock()
        mock_provider.analyze_food_image.side_effect = Exception("API timeout")

        service = FoodScanService.__new__(FoodScanService)
        service.provider = mock_provider
        service.provider_name = "test"

        with pytest.raises(Exception, match="API timeout"):
            await service.analyze_food("base64data", [])

    @pytest.mark.asyncio
    async def test_hints_passed_to_provider(self):
        mock_provider = AsyncMock()
        mock_provider.analyze_food_image.return_value = {"items": []}

        service = FoodScanService.__new__(FoodScanService)
        service.provider = mock_provider
        service.provider_name = "test"

        await service.analyze_food("img", ["pizza", "salad"])
        mock_provider.analyze_food_image.assert_called_once_with("img", ["pizza", "salad"])

    @pytest.mark.asyncio
    async def test_multiple_items_get_uuids(self):
        mock_provider = AsyncMock()
        mock_provider.analyze_food_image.return_value = {
            "items": [
                {
                    "name": "Rice",
                    "portion_description": "1 cup",
                    "portion_grams": 200,
                    "calories": 260,
                    "protein_g": 5,
                    "carbs_g": 57,
                    "fat_g": 0.5,
                    "confidence": 0.9,
                },
                {
                    "name": "Chicken",
                    "portion_description": "1 breast",
                    "portion_grams": 170,
                    "calories": 280,
                    "protein_g": 53,
                    "carbs_g": 0,
                    "fat_g": 6,
                    "confidence": 0.85,
                },
            ]
        }

        service = FoodScanService.__new__(FoodScanService)
        service.provider = mock_provider
        service.provider_name = "test"

        result = await service.analyze_food("img", [])
        assert len(result["items"]) == 2
        # Each item should have a unique UUID
        ids = [item["id"] for item in result["items"]]
        assert len(set(ids)) == 2


class TestNutritionSourceField:
    """Test that source field flows through correctly."""

    def test_food_entry_create_with_source(self):
        from app.models.nutrition import FoodEntryCreate

        entry = FoodEntryCreate(name="Chicken", calories=200, source="ai_scan")
        assert entry.source == "ai_scan"

    def test_food_entry_create_source_defaults_none(self):
        from app.models.nutrition import FoodEntryCreate

        entry = FoodEntryCreate(name="Chicken", calories=200)
        assert entry.source is None

    def test_food_entry_create_source_max_length(self):
        from app.models.nutrition import FoodEntryCreate

        with pytest.raises(ValueError):
            FoodEntryCreate(name="X", calories=0, source="a" * 51)

    def test_food_entry_create_valid_sources(self):
        from app.models.nutrition import FoodEntryCreate

        for src in ["manual", "barcode", "recipe", "meal_plan", "ai_scan"]:
            entry = FoodEntryCreate(name="Test", calories=100, source=src)
            assert entry.source == src
