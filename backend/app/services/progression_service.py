#
# progression_service.py
#
# Computes weight suggestions for progressive overload based on
# the user's recent workout session history.
#

from uuid import UUID
from supabase import Client


# Upper body increment: +2.5kg, Lower body: +5kg
UPPER_INCREMENT = 2.5
LOWER_INCREMENT = 5.0
DELOAD_FACTOR = 0.9  # -10%

# Categories classified as lower body
LOWER_CATEGORIES = {"legs"}


async def get_suggestions(
    supabase: Client, user_id: UUID, exercise_names: list[str]
) -> dict[str, dict]:
    """
    For each exercise name, analyze recent workout sessions and return
    a weight suggestion with progression status.

    Returns {exercise_name: {suggested_weight_kg, last_weight_kg, last_reps, last_rpe, status, reason}}
    """
    if not exercise_names:
        return {}

    # Fetch recent workout sessions (last 10, most recent first)
    result = (
        supabase.table("workout_sessions")
        .select("exercises, started_at")
        .eq("user_id", str(user_id))
        .order("started_at", desc=True)
        .limit(10)
        .execute()
    )

    sessions = result.data or []

    # Build a lookup of exercise category for upper/lower classification
    exercise_categories = await _get_exercise_categories(supabase, exercise_names)

    suggestions = {}
    for name in exercise_names:
        suggestions[name] = _compute_suggestion(name, sessions, exercise_categories.get(name))

    return suggestions


async def _get_exercise_categories(
    supabase: Client, exercise_names: list[str]
) -> dict[str, str]:
    """Fetch exercise categories from the exercises table by name."""
    if not exercise_names:
        return {}

    result = (
        supabase.table("exercises")
        .select("name, category")
        .in_("name", exercise_names)
        .execute()
    )

    return {row["name"]: row["category"] for row in (result.data or [])}


def _compute_suggestion(
    exercise_name: str,
    sessions: list[dict],
    category: str | None,
) -> dict:
    """Compute weight suggestion for a single exercise from session history."""

    # Extract this exercise's data from each session
    exercise_sessions = []
    for session in sessions:
        exercises = session.get("exercises") or []
        for ex in exercises:
            if ex.get("name") == exercise_name:
                sets = ex.get("sets", [])
                if sets:
                    exercise_sessions.append(sets)
                break

    # No history — new exercise
    if not exercise_sessions:
        return {
            "suggested_weight_kg": None,
            "last_weight_kg": None,
            "last_reps": None,
            "last_rpe": None,
            "status": "new",
            "reason": "No previous data",
        }

    # Analyze the most recent session
    latest_sets = exercise_sessions[0]
    working_sets = _get_working_sets(latest_sets)

    if not working_sets:
        return {
            "suggested_weight_kg": None,
            "last_weight_kg": None,
            "last_reps": None,
            "last_rpe": None,
            "status": "new",
            "reason": "No working sets found",
        }

    last_weight = max(s.get("weight", 0) for s in working_sets)
    last_reps = next(
        (s.get("reps", 0) for s in working_sets if s.get("weight", 0) == last_weight),
        0,
    )

    # Average RPE across working sets (default 7 if not tracked)
    rpe_values = [s.get("rpe") for s in working_sets if s.get("rpe") is not None]
    avg_rpe = sum(rpe_values) / len(rpe_values) if rpe_values else 7.0

    # Determine increment based on upper/lower
    is_lower = (category or "").lower() in LOWER_CATEGORIES
    increment = LOWER_INCREMENT if is_lower else UPPER_INCREMENT

    # Check for deload condition: 2+ consecutive sessions at same/lower weight with high RPE
    needs_deload = _check_deload(exercise_sessions, last_weight)

    if needs_deload and avg_rpe >= 9:
        deloaded = round(last_weight * DELOAD_FACTOR / 2.5) * 2.5  # Round to nearest 2.5
        return {
            "suggested_weight_kg": deloaded,
            "last_weight_kg": last_weight,
            "last_reps": last_reps,
            "last_rpe": round(avg_rpe, 1),
            "status": "deload",
            "reason": f"-10% deload ({last_weight}kg → {deloaded}kg)",
        }

    if avg_rpe <= 8 and last_reps >= 1:
        suggested = last_weight + increment
        body_label = "lower body" if is_lower else "upper body"
        return {
            "suggested_weight_kg": suggested,
            "last_weight_kg": last_weight,
            "last_reps": last_reps,
            "last_rpe": round(avg_rpe, 1),
            "status": "increase",
            "reason": f"+{increment}kg ({body_label} progression)",
        }

    # Maintain
    return {
        "suggested_weight_kg": last_weight,
        "last_weight_kg": last_weight,
        "last_reps": last_reps,
        "last_rpe": round(avg_rpe, 1),
        "status": "maintain",
        "reason": "RPE high — maintain current weight",
    }


def _get_working_sets(sets: list[dict]) -> list[dict]:
    """Filter to working sets only (exclude warmups)."""
    if not sets:
        return []

    # Find max weight to identify warmups (< 50% of max = likely warmup)
    max_weight = max((s.get("weight", 0) for s in sets), default=0)
    if max_weight <= 0:
        return sets

    threshold = max_weight * 0.5
    return [s for s in sets if s.get("weight", 0) >= threshold]


def _check_deload(exercise_sessions: list[list[dict]], current_max: float) -> bool:
    """Check if the last 2+ sessions show stagnation (same or lower max weight)."""
    if len(exercise_sessions) < 2:
        return False

    for session_sets in exercise_sessions[1:3]:  # Check 2nd and 3rd most recent
        working = _get_working_sets(session_sets)
        if not working:
            return False
        session_max = max(s.get("weight", 0) for s in working)
        if session_max < current_max:
            # Weight went down — not a plateau, could be intentional
            continue
        if session_max > current_max:
            return False  # Previously lifted more — not stagnating

    return True  # All checked sessions at same or lower weight
