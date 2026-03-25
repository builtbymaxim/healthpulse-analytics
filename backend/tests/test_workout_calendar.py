"""Tests for Phase 3: Workout History Calendar endpoint aggregation logic."""

import pytest
from datetime import date


# ---------------------------------------------------------------------------
# Helpers (mirror of the endpoint's aggregation logic)
# ---------------------------------------------------------------------------

def build_calendar(freeform_rows, session_rows, pr_rows):
    """Pure-Python version of the calendar aggregation for testing."""
    days: dict[str, dict] = {}

    def _day(d: str) -> dict:
        if d not in days:
            days[d] = {"date": d, "workout_count": 0, "has_pr": False, "best_rating": None}
        return days[d]

    for w in freeform_rows:
        entry = _day(w["start_time"][:10])
        entry["workout_count"] += 1
        r = w.get("overall_rating")
        if r and (entry["best_rating"] is None or r > entry["best_rating"]):
            entry["best_rating"] = r

    for s in session_rows:
        entry = _day(s["started_at"][:10])
        entry["workout_count"] += 1
        r = s.get("overall_rating")
        if r and (entry["best_rating"] is None or r > entry["best_rating"]):
            entry["best_rating"] = r

    for pr in pr_rows:
        _day(pr["achieved_at"][:10])["has_pr"] = True

    return sorted(days.values(), key=lambda x: x["date"])


# ---------------------------------------------------------------------------
# Aggregation logic tests
# ---------------------------------------------------------------------------

class TestCalendarAggregation:

    def test_single_freeform_workout_appears(self):
        result = build_calendar(
            [{"start_time": "2026-03-10T09:00:00", "overall_rating": None}], [], []
        )
        assert len(result) == 1
        assert result[0]["date"] == "2026-03-10"
        assert result[0]["workout_count"] == 1

    def test_freeform_and_session_same_day_add_counts(self):
        result = build_calendar(
            [{"start_time": "2026-03-15T07:00:00", "overall_rating": None}],
            [{"started_at": "2026-03-15T18:00:00", "overall_rating": None}],
            [],
        )
        assert result[0]["workout_count"] == 2

    def test_pr_flag_set_from_personal_records(self):
        result = build_calendar(
            [{"start_time": "2026-03-20T08:00:00", "overall_rating": None}],
            [],
            [{"achieved_at": "2026-03-20T08:30:00"}],
        )
        assert result[0]["has_pr"] is True

    def test_pr_day_without_workout_still_added(self):
        """A PR row with no matching workout row should still create a day entry."""
        result = build_calendar([], [], [{"achieved_at": "2026-03-05T10:00:00"}])
        assert len(result) == 1
        assert result[0]["date"] == "2026-03-05"
        assert result[0]["has_pr"] is True
        assert result[0]["workout_count"] == 0

    def test_best_rating_picks_higher_value(self):
        result = build_calendar(
            [{"start_time": "2026-03-12T06:00:00", "overall_rating": 3}],
            [{"started_at": "2026-03-12T19:00:00", "overall_rating": 5}],
            [],
        )
        assert result[0]["best_rating"] == 5

    def test_none_rating_does_not_overwrite_real_rating(self):
        result = build_calendar(
            [{"start_time": "2026-03-08T07:00:00", "overall_rating": 4},
             {"start_time": "2026-03-08T18:00:00", "overall_rating": None}],
            [],
            [],
        )
        assert result[0]["best_rating"] == 4

    def test_results_sorted_by_date_ascending(self):
        result = build_calendar(
            [
                {"start_time": "2026-03-25T08:00:00", "overall_rating": None},
                {"start_time": "2026-03-03T08:00:00", "overall_rating": None},
                {"start_time": "2026-03-14T08:00:00", "overall_rating": None},
            ],
            [],
            [],
        )
        dates = [r["date"] for r in result]
        assert dates == sorted(dates)

    def test_empty_month_returns_empty_list(self):
        assert build_calendar([], [], []) == []

    def test_multiple_days_correct_counts(self):
        result = build_calendar(
            [
                {"start_time": "2026-03-01T08:00:00", "overall_rating": None},
                {"start_time": "2026-03-01T18:00:00", "overall_rating": None},
                {"start_time": "2026-03-07T08:00:00", "overall_rating": None},
            ],
            [],
            [],
        )
        counts = {r["date"]: r["workout_count"] for r in result}
        assert counts["2026-03-01"] == 2
        assert counts["2026-03-07"] == 1


# ---------------------------------------------------------------------------
# Month boundary helpers (test date parsing logic)
# ---------------------------------------------------------------------------

class TestMonthBoundary:

    def _last_day_of_month(self, year: int, mon: int) -> date:
        from datetime import timedelta
        if mon == 12:
            return date(year + 1, 1, 1) - timedelta(days=1)
        return date(year, mon + 1, 1) - timedelta(days=1)

    def test_march_last_day_is_31(self):
        assert self._last_day_of_month(2026, 3).day == 31

    def test_february_non_leap_year_last_day_is_28(self):
        assert self._last_day_of_month(2025, 2).day == 28

    def test_february_leap_year_last_day_is_29(self):
        assert self._last_day_of_month(2024, 2).day == 29

    def test_december_rolls_to_next_year(self):
        last = self._last_day_of_month(2025, 12)
        assert last == date(2025, 12, 31)
