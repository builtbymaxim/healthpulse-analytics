"""AI food scanning service with abstracted vision providers.

Supports Gemini (default), OpenAI, and Claude vision APIs.
Provider is selected via VISION_PROVIDER env var.
"""

import abc
import json
import logging
import re
import time
from uuid import uuid4

import httpx

from app.config import get_settings

logger = logging.getLogger(__name__)

FOOD_ANALYSIS_PROMPT = """Analyze this food photo. For EACH distinct food item visible:
1. Identify the food name
2. Estimate the portion size in grams
3. Provide a human-readable portion description (e.g. "1 medium breast (~170g)")
4. Estimate macronutrients per the estimated portion: calories, protein_g, carbs_g, fat_g, fiber_g
5. Provide a confidence score (0.0-1.0)

{hints_section}

Return ONLY valid JSON in this exact format, no markdown fences:
{{"items": [{{"name": "...", "portion_description": "...", "portion_grams": 0, "calories": 0, "protein_g": 0, "carbs_g": 0, "fat_g": 0, "fiber_g": 0, "confidence": 0.0}}]}}"""


def _build_prompt(hints: list[str]) -> str:
    """Build the analysis prompt with optional classification hints."""
    if hints:
        hints_section = (
            f"On-device classification detected: {', '.join(hints)}. "
            "Use as guidance but verify visually."
        )
    else:
        hints_section = ""
    return FOOD_ANALYSIS_PROMPT.format(hints_section=hints_section)


def _extract_json(text: str) -> dict:
    """Extract JSON from LLM response, stripping markdown fences if present."""
    # Strip markdown code fences
    cleaned = re.sub(r"```(?:json)?\s*", "", text).strip()
    cleaned = re.sub(r"```\s*$", "", cleaned).strip()
    try:
        return json.loads(cleaned)
    except json.JSONDecodeError:
        logger.warning("Could not parse vision response as JSON: %s", cleaned[:200])
        return {"items": []}


class VisionProvider(abc.ABC):
    """Abstract base class for vision API providers."""

    @abc.abstractmethod
    async def analyze_food_image(
        self, image_base64: str, hints: list[str]
    ) -> dict:
        """Analyze a food image and return parsed JSON with 'items' list."""
        ...


class GeminiVisionProvider(VisionProvider):
    """Google Gemini vision provider (default, cheapest)."""

    def __init__(self, api_key: str):
        self.api_key = api_key
        self.model = "gemini-2.5-flash-lite"

    async def analyze_food_image(self, image_base64: str, hints: list[str]) -> dict:
        prompt = _build_prompt(hints)
        url = (
            f"https://generativelanguage.googleapis.com/v1beta/"
            f"models/{self.model}:generateContent?key={self.api_key}"
        )

        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.post(
                url,
                json={
                    "contents": [{
                        "parts": [
                            {
                                "inline_data": {
                                    "mime_type": "image/jpeg",
                                    "data": image_base64,
                                }
                            },
                            {"text": prompt},
                        ]
                    }],
                    "generationConfig": {
                        "temperature": 0.1,
                        "maxOutputTokens": 1024,
                    },
                },
            )
            response.raise_for_status()
            data = response.json()
            text = data["candidates"][0]["content"]["parts"][0]["text"]
            return _extract_json(text)


class OpenAIVisionProvider(VisionProvider):
    """OpenAI GPT-4o-mini vision provider."""

    def __init__(self, api_key: str):
        self.api_key = api_key
        self.model = "gpt-4o-mini"

    async def analyze_food_image(self, image_base64: str, hints: list[str]) -> dict:
        prompt = _build_prompt(hints)

        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.post(
                "https://api.openai.com/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": self.model,
                    "max_tokens": 1024,
                    "temperature": 0.1,
                    "messages": [{
                        "role": "user",
                        "content": [
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:image/jpeg;base64,{image_base64}",
                                    "detail": "low",
                                },
                            },
                            {"type": "text", "text": prompt},
                        ],
                    }],
                },
            )
            response.raise_for_status()
            data = response.json()
            text = data["choices"][0]["message"]["content"]
            return _extract_json(text)


class ClaudeVisionProvider(VisionProvider):
    """Anthropic Claude vision provider."""

    def __init__(self, api_key: str):
        self.api_key = api_key
        self.model = "claude-haiku-4-5-20251001"

    async def analyze_food_image(self, image_base64: str, hints: list[str]) -> dict:
        prompt = _build_prompt(hints)

        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.post(
                "https://api.anthropic.com/v1/messages",
                headers={
                    "x-api-key": self.api_key,
                    "anthropic-version": "2023-06-01",
                    "content-type": "application/json",
                },
                json={
                    "model": self.model,
                    "max_tokens": 1024,
                    "messages": [{
                        "role": "user",
                        "content": [
                            {
                                "type": "image",
                                "source": {
                                    "type": "base64",
                                    "media_type": "image/jpeg",
                                    "data": image_base64,
                                },
                            },
                            {"type": "text", "text": prompt},
                        ],
                    }],
                },
            )
            response.raise_for_status()
            data = response.json()
            text = data["content"][0]["text"]
            return _extract_json(text)


class FoodScanService:
    """Service for analyzing food photos using vision AI."""

    def __init__(self):
        settings = get_settings()
        provider_name = settings.vision_provider.lower()

        if provider_name == "openai":
            self.provider = OpenAIVisionProvider(settings.openai_api_key)
        elif provider_name == "claude":
            self.provider = ClaudeVisionProvider(settings.anthropic_api_key)
        else:
            self.provider = GeminiVisionProvider(settings.gemini_api_key)

        self.provider_name = provider_name

    async def analyze_food(
        self, image_base64: str, hints: list[str]
    ) -> dict:
        """Analyze a food photo and return identified items with macros.

        Args:
            image_base64: Base64-encoded JPEG image
            hints: On-device classification labels for guidance

        Returns:
            Dict with items, processing_time_ms, and provider
        """
        start = time.monotonic()
        try:
            result = await self.provider.analyze_food_image(image_base64, hints)
            elapsed_ms = int((time.monotonic() - start) * 1000)

            # Add UUIDs to items if missing
            for item in result.get("items", []):
                if "id" not in item:
                    item["id"] = str(uuid4())

            return {
                "items": result.get("items", []),
                "processing_time_ms": elapsed_ms,
                "provider": self.provider_name,
            }
        except Exception:
            logger.error("Food scan analysis failed", exc_info=True)
            raise


# Module-level singleton
_food_scan_service: FoodScanService | None = None


def get_food_scan_service() -> FoodScanService:
    """Get or create the food scan service singleton."""
    global _food_scan_service
    if _food_scan_service is None:
        _food_scan_service = FoodScanService()
    return _food_scan_service
