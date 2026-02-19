"""Pydantic models for AI food scanning."""

from uuid import UUID, uuid4
from typing import Optional

from pydantic import BaseModel, Field


class FoodScanRequest(BaseModel):
    """Request to analyze a food photo."""
    image_base64: str = Field(description="Base64-encoded JPEG image")
    classification_hints: list[str] = Field(
        default=[], description="On-device CoreML classification labels"
    )


class ScannedFoodItem(BaseModel):
    """A single identified food item with estimated macros."""
    id: UUID = Field(default_factory=uuid4)
    name: str
    portion_description: str = Field(description="e.g. '1 medium breast (~170g)'")
    portion_grams: float
    calories: float
    protein_g: float
    carbs_g: float
    fat_g: float
    fiber_g: float = 0
    confidence: float = Field(ge=0, le=1, description="Classification confidence")


class FoodScanResponse(BaseModel):
    """Response from food photo analysis."""
    items: list[ScannedFoodItem]
    processing_time_ms: int
    provider: str = Field(description="Vision API provider used: gemini, openai, or claude")
