"""Tests for Phase 2: Ad-Hoc Sports Logging — MET calorie estimation."""

import pytest
from unittest.mock import MagicMock, patch, AsyncMock
from uuid import UUID

# Import the MET tables directly from the module
from app.api.workouts import _MET_VALUES, _INTENSITY_MET_FALLBACK


# ---------------------------------------------------------------------------
# MET table correctness
# ---------------------------------------------------------------------------

class TestMetTable:
    """Validate the MET value lookup tables."""

    def test_all_sport_types_have_met_values(self):
        sport_types = ["soccer", "basketball", "tennis", "martial_arts",
                       "dancing", "badminton", "volleyball"]
        for sport in sport_types:
            assert sport in _MET_VALUES, f"Missing MET value for {sport}"

    def test_sport_met_values_are_positive(self):
        sport_types = ["soccer", "basketball", "tennis", "martial_arts",
                       "dancing", "badminton", "volleyball"]
        for sport in sport_types:
            assert _MET_VALUES[sport] > 0

    def test_martial_arts_has_highest_met_among_sports(self):
        """Martial arts (10.3 MET) should be the most intense sport."""
        sport_mets = {k: v for k, v in _MET_VALUES.items()
                      if k in ["soccer", "basketball", "tennis",
                               "martial_arts", "dancing", "badminton", "volleyball"]}
        assert max(sport_mets, key=sport_mets.get) == "martial_arts"

    def test_intensity_fallback_has_all_levels(self):
        for level in ["light", "moderate", "hard", "very_hard"]:
            assert level in _INTENSITY_MET_FALLBACK

    def test_intensity_fallback_increases_with_effort(self):
        assert (_INTENSITY_MET_FALLBACK["light"]
                < _INTENSITY_MET_FALLBACK["moderate"]
                < _INTENSITY_MET_FALLBACK["hard"]
                < _INTENSITY_MET_FALLBACK["very_hard"])


# ---------------------------------------------------------------------------
# Calorie estimation arithmetic
# ---------------------------------------------------------------------------

class TestCalorieEstimation:
    """Validate MET-based calorie formula: calories = MET × weight_kg × hours."""

    def _estimate(self, workout_type: str, weight_kg: float, duration_minutes: int) -> int:
        met = _MET_VALUES.get(workout_type, 5.0)
        return round(met * weight_kg * (duration_minutes / 60.0))

    def test_soccer_60min_70kg(self):
        # 7.0 MET × 70 kg × 1 h = 490
        assert self._estimate("soccer", 70.0, 60) == 490

    def test_basketball_45min_80kg(self):
        # 6.5 × 80 × 0.75 = 390
        assert self._estimate("basketball", 80.0, 45) == 390

    def test_tennis_90min_65kg(self):
        # 7.3 × 65 × 1.5 = 712 (rounded)
        assert self._estimate("tennis", 65.0, 90) == 712

    def test_martial_arts_30min_75kg(self):
        # 10.3 × 75 × 0.5 = 386 (rounded)
        assert self._estimate("martial_arts", 75.0, 30) == 386

    def test_heavier_user_burns_more_calories(self):
        light = self._estimate("soccer", 60.0, 60)
        heavy = self._estimate("soccer", 90.0, 60)
        assert heavy > light

    def test_longer_duration_burns_more_calories(self):
        short = self._estimate("basketball", 70.0, 30)
        long_ = self._estimate("basketball", 70.0, 60)
        assert long_ > short

    def test_unknown_type_uses_5_met_fallback(self):
        # "other" maps to 5.0 MET
        expected = round(5.0 * 70.0 * (60 / 60.0))
        assert self._estimate("other", 70.0, 60) == expected
