"""Tests for Phase 4: PATCH /training-plans/{plan_id}/schedule — schedule patching logic."""

from uuid import UUID, uuid4

NEW_EXERCISES = [
    {"name": "Bench Press", "sets": 4, "reps": "5", "notes": None, "is_key_lift": True},
    {"name": "Overhead Press", "sets": 3, "reps": "8", "notes": None, "is_key_lift": False},
]


# ---------------------------------------------------------------------------
# Pure logic tests (no HTTP, no Supabase)
# ---------------------------------------------------------------------------

def _apply_patch(schedule: dict, day_of_week: int, exercises: list) -> dict:
    """Mirror of the endpoint's JSONB patch logic."""
    day_key = str(day_of_week)
    if day_key in schedule:
        schedule[day_key]["exercises"] = exercises
    return schedule


class TestPatchLogic:

    def test_exercises_updated_when_day_exists(self):
        schedule = {"2": {"name": "Push", "exercises": [{"name": "Old Exercise"}]}}
        result = _apply_patch(schedule, 2, NEW_EXERCISES)
        assert result["2"]["exercises"] == NEW_EXERCISES

    def test_other_days_untouched(self):
        schedule = {
            "1": {"name": "Pull", "exercises": [{"name": "Deadlift"}]},
            "2": {"name": "Push", "exercises": [{"name": "Old"}]},
        }
        result = _apply_patch(schedule, 2, NEW_EXERCISES)
        assert result["1"]["exercises"] == [{"name": "Deadlift"}]

    def test_day_not_in_schedule_is_noop(self):
        """If the day key doesn't exist, no KeyError — schedule unchanged."""
        schedule = {"1": {"name": "Pull", "exercises": []}}
        result = _apply_patch(schedule, 3, NEW_EXERCISES)
        assert "3" not in result
        assert result["1"]["exercises"] == []

    def test_empty_exercises_list_clears_day(self):
        schedule = {"5": {"name": "Legs", "exercises": [{"name": "Squat"}]}}
        result = _apply_patch(schedule, 5, [])
        assert result["5"]["exercises"] == []

    def test_workout_name_and_focus_preserved(self):
        """Patching exercises must not overwrite name/focus/estimatedMinutes."""
        schedule = {
            "3": {
                "name": "Push Day",
                "focus": "Chest & Shoulders",
                "estimatedMinutes": 60,
                "exercises": [],
            }
        }
        result = _apply_patch(schedule, 3, NEW_EXERCISES)
        assert result["3"]["name"] == "Push Day"
        assert result["3"]["focus"] == "Chest & Shoulders"
        assert result["3"]["estimatedMinutes"] == 60
