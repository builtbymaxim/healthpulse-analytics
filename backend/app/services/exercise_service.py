"""Exercise and strength training service."""

from __future__ import annotations

from datetime import datetime, date, timedelta
from uuid import UUID

from app.database import get_supabase_client
from app.models.exercises import (
    Exercise,
    ExerciseCategory,
    WorkoutSet,
    WorkoutSetCreate,
    PersonalRecord,
    PRType,
    ExerciseHistory,
    VolumeAnalytics,
    FrequencyAnalytics,
    MuscleGroupStats,
)


class ExerciseService:
    """Service for exercise library and strength tracking."""

    def __init__(self):
        self.supabase = get_supabase_client()

    # ============================================
    # Exercise Library
    # ============================================

    async def get_exercises(
        self,
        category: ExerciseCategory | None = None,
        equipment: str | None = None,
        search: str | None = None,
    ) -> list[Exercise]:
        """Get exercises from library with optional filters."""
        query = self.supabase.table("exercises").select("*")

        if category:
            query = query.eq("category", category.value)

        if equipment:
            query = query.eq("equipment", equipment)

        if search:
            query = query.ilike("name", f"%{search}%")

        result = query.order("name").execute()
        return [Exercise(**e) for e in result.data] if result.data else []

    async def get_exercise(self, exercise_id: UUID) -> Exercise | None:
        """Get a single exercise by ID."""
        result = (
            self.supabase.table("exercises")
            .select("*")
            .eq("id", str(exercise_id))
            .single()
            .execute()
        )
        return Exercise(**result.data) if result.data else None

    # ============================================
    # Workout Sets
    # ============================================

    async def log_sets(
        self, user_id: UUID, workout_id: UUID | None, sets: list[WorkoutSetCreate]
    ) -> list[WorkoutSet]:
        """Log multiple workout sets and check for PRs.

        If workout_id is None, creates a parent workout automatically so the
        strength workout appears in 'recent workouts'.
        """
        created_sets = []

        # Auto-create a parent workout if not provided
        if workout_id is None and sets:
            # Calculate total duration estimate (3 min per set is rough)
            duration_minutes = max(len(sets) * 3, 15)

            workout_data = {
                "user_id": str(user_id),
                "workout_type": "weight_training",
                "start_time": datetime.utcnow().isoformat(),
                "duration_minutes": duration_minutes,
                "intensity": "moderate",
                "training_load": len(sets) * 10,  # Simple estimate
            }

            workout_result = self.supabase.table("workouts").insert(workout_data).execute()
            if workout_result.data:
                workout_id = UUID(workout_result.data[0]["id"])

        for set_data in sets:
            # Prepare set record
            record = {
                "user_id": str(user_id),
                "workout_id": str(workout_id) if workout_id else None,
                "exercise_id": str(set_data.exercise_id),
                "set_number": set_data.set_number,
                "weight_kg": set_data.weight_kg,
                "reps": set_data.reps,
                "rpe": set_data.rpe,
                "is_warmup": set_data.is_warmup,
                "notes": set_data.notes,
                "performed_at": (set_data.performed_at or datetime.utcnow()).isoformat(),
            }

            # Check for PR before inserting
            is_pr = False
            if not set_data.is_warmup:
                is_pr = await self._check_and_update_pr(
                    user_id, set_data.exercise_id, set_data.weight_kg, set_data.reps
                )

            record["is_pr"] = is_pr

            # Insert set
            result = self.supabase.table("workout_sets").insert(record).execute()

            if result.data:
                # Get exercise name for response
                exercise = await self.get_exercise(set_data.exercise_id)
                set_record = result.data[0]
                set_record["exercise_name"] = exercise.name if exercise else None
                set_record["exercise_category"] = exercise.category.value if exercise else None
                created_sets.append(WorkoutSet(**set_record))

        return created_sets

    async def get_workout_sets(self, user_id: UUID, workout_id: UUID) -> list[WorkoutSet]:
        """Get all sets for a workout."""
        result = (
            self.supabase.table("workout_sets")
            .select("*, exercises(name, category)")
            .eq("user_id", str(user_id))
            .eq("workout_id", str(workout_id))
            .order("set_number")
            .execute()
        )

        sets = []
        for s in result.data or []:
            exercise_info = s.pop("exercises", {}) or {}
            s["exercise_name"] = exercise_info.get("name")
            s["exercise_category"] = exercise_info.get("category")
            sets.append(WorkoutSet(**s))

        return sets

    async def get_exercise_history(
        self, user_id: UUID, exercise_id: UUID, days: int = 90
    ) -> ExerciseHistory:
        """Get user's history for a specific exercise."""
        start_date = date.today() - timedelta(days=days)
        start_30d = date.today() - timedelta(days=30)

        # Get exercise info
        exercise = await self.get_exercise(exercise_id)

        # Get all sets for this exercise
        result = (
            self.supabase.table("workout_sets")
            .select("*")
            .eq("user_id", str(user_id))
            .eq("exercise_id", str(exercise_id))
            .gte("performed_at", start_date.isoformat())
            .order("performed_at", desc=True)
            .execute()
        )

        sets = [WorkoutSet(**s) for s in result.data] if result.data else []

        # Get PRs for this exercise
        prs_result = (
            self.supabase.table("personal_records")
            .select("*")
            .eq("user_id", str(user_id))
            .eq("exercise_id", str(exercise_id))
            .execute()
        )

        prs = [PersonalRecord(**p) for p in prs_result.data] if prs_result.data else []

        # Calculate estimated 1RM from best set
        estimated_1rm = None
        if sets:
            best_estimated = 0
            for s in sets:
                if not s.is_warmup and s.reps > 0:
                    # Epley formula: weight * (1 + reps/30)
                    est = s.weight_kg * (1 + s.reps / 30)
                    if est > best_estimated:
                        best_estimated = est
            estimated_1rm = round(best_estimated, 1) if best_estimated > 0 else None

        # Calculate 30-day stats
        sets_30d = [s for s in sets if s.performed_at.date() >= start_30d]
        total_volume_30d = sum(s.weight_kg * s.reps for s in sets_30d if not s.is_warmup)
        unique_dates = set(s.performed_at.date() for s in sets_30d)

        return ExerciseHistory(
            exercise_id=exercise_id,
            exercise_name=exercise.name if exercise else "Unknown",
            sets=sets[:50],  # Limit returned sets
            personal_records=prs,
            estimated_1rm=estimated_1rm,
            total_volume_30d=total_volume_30d,
            session_count_30d=len(unique_dates),
        )

    # ============================================
    # Personal Records
    # ============================================

    async def _check_and_update_pr(
        self, user_id: UUID, exercise_id: UUID, weight_kg: float, reps: int
    ) -> bool:
        """Check if set is a PR and update records. Returns True if PR."""
        is_pr = False

        # Determine which PR type to check based on reps
        pr_type_map = {1: "1rm", 3: "3rm", 5: "5rm", 10: "10rm"}
        pr_type = pr_type_map.get(reps)

        if pr_type:
            # Check existing PR
            existing = (
                self.supabase.table("personal_records")
                .select("*")
                .eq("user_id", str(user_id))
                .eq("exercise_id", str(exercise_id))
                .eq("record_type", pr_type)
                .limit(1)
                .execute()
            )

            if existing.data:
                current_pr = existing.data[0]
                if weight_kg > current_pr["value"]:
                    # Update PR
                    self.supabase.table("personal_records").update({
                        "previous_value": current_pr["value"],
                        "value": weight_kg,
                        "achieved_at": datetime.utcnow().isoformat(),
                    }).eq("id", current_pr["id"]).execute()
                    is_pr = True
            else:
                # Create new PR
                self.supabase.table("personal_records").insert({
                    "user_id": str(user_id),
                    "exercise_id": str(exercise_id),
                    "record_type": pr_type,
                    "value": weight_kg,
                    "achieved_at": datetime.utcnow().isoformat(),
                }).execute()
                is_pr = True

        return is_pr

    async def get_personal_records(
        self, user_id: UUID, exercise_id: UUID | None = None
    ) -> list[PersonalRecord]:
        """Get user's personal records."""
        query = (
            self.supabase.table("personal_records")
            .select("*, exercises(name, category)")
            .eq("user_id", str(user_id))
        )

        if exercise_id:
            query = query.eq("exercise_id", str(exercise_id))

        result = query.order("achieved_at", desc=True).execute()

        records = []
        for r in result.data or []:
            exercise_info = r.pop("exercises", {}) or {}
            r["exercise_name"] = exercise_info.get("name")
            r["exercise_category"] = exercise_info.get("category")
            records.append(PersonalRecord(**r))

        return records

    # ============================================
    # Analytics
    # ============================================

    async def get_volume_analytics(
        self, user_id: UUID, period: str = "week"
    ) -> VolumeAnalytics:
        """Get volume analytics for a period."""
        days = 7 if period == "week" else 30
        start_date = date.today() - timedelta(days=days)
        prev_start = start_date - timedelta(days=days)

        # Current period sets
        current_result = (
            self.supabase.table("workout_sets")
            .select("*, exercises(name, category)")
            .eq("user_id", str(user_id))
            .eq("is_warmup", False)
            .gte("performed_at", start_date.isoformat())
            .execute()
        )

        # Previous period sets for trend
        prev_result = (
            self.supabase.table("workout_sets")
            .select("weight_kg, reps")
            .eq("user_id", str(user_id))
            .eq("is_warmup", False)
            .gte("performed_at", prev_start.isoformat())
            .lt("performed_at", start_date.isoformat())
            .execute()
        )

        # Calculate volumes
        total_volume = 0
        volume_by_category: dict[str, float] = {}
        volume_by_exercise: dict[str, float] = {}

        for s in current_result.data or []:
            vol = s["weight_kg"] * s["reps"]
            total_volume += vol

            exercise_info = s.get("exercises", {}) or {}
            category = exercise_info.get("category", "other")
            name = exercise_info.get("name", "Unknown")

            volume_by_category[category] = volume_by_category.get(category, 0) + vol
            volume_by_exercise[name] = volume_by_exercise.get(name, 0) + vol

        prev_volume = sum(s["weight_kg"] * s["reps"] for s in prev_result.data or [])
        trend_pct = ((total_volume - prev_volume) / prev_volume * 100) if prev_volume > 0 else 0

        return VolumeAnalytics(
            period=period,
            total_volume=round(total_volume, 1),
            volume_by_category={k: round(v, 1) for k, v in volume_by_category.items()},
            volume_by_exercise={k: round(v, 1) for k, v in sorted(
                volume_by_exercise.items(), key=lambda x: x[1], reverse=True
            )[:10]},
            trend_pct=round(trend_pct, 1),
        )

    async def get_frequency_analytics(
        self, user_id: UUID, period: str = "week"
    ) -> FrequencyAnalytics:
        """Get training frequency analytics."""
        days = 7 if period == "week" else 30
        start_date = date.today() - timedelta(days=days)

        result = (
            self.supabase.table("workout_sets")
            .select("performed_at, set_number, exercises(category)")
            .eq("user_id", str(user_id))
            .gte("performed_at", start_date.isoformat())
            .execute()
        )

        sessions_by_category: dict[str, int] = {}
        sessions_by_day: dict[str, int] = {}
        unique_sessions: set[str] = set()
        total_sets = 0

        for s in result.data or []:
            total_sets += 1
            performed = datetime.fromisoformat(s["performed_at"].replace("Z", "+00:00"))
            session_key = performed.date().isoformat()
            unique_sessions.add(session_key)

            day_name = performed.strftime("%a")
            sessions_by_day[day_name] = sessions_by_day.get(day_name, 0) + 1

            exercise_info = s.get("exercises", {}) or {}
            category = exercise_info.get("category", "other")
            cat_session_key = f"{category}_{session_key}"
            if cat_session_key not in unique_sessions:
                unique_sessions.add(cat_session_key)
                sessions_by_category[category] = sessions_by_category.get(category, 0) + 1

        total_sessions = len([s for s in unique_sessions if "_" not in s])
        avg_sets = total_sets / total_sessions if total_sessions > 0 else 0

        return FrequencyAnalytics(
            period=period,
            total_sessions=total_sessions,
            sessions_by_category=sessions_by_category,
            sessions_by_day=sessions_by_day,
            avg_sets_per_session=round(avg_sets, 1),
        )

    async def get_muscle_group_stats(self, user_id: UUID) -> list[MuscleGroupStats]:
        """Get stats for each muscle group."""
        start_date = date.today() - timedelta(days=7)

        result = (
            self.supabase.table("workout_sets")
            .select("weight_kg, reps, performed_at, exercises(category)")
            .eq("user_id", str(user_id))
            .eq("is_warmup", False)
            .gte("performed_at", start_date.isoformat())
            .execute()
        )

        stats_by_category: dict[str, dict] = {}

        for s in result.data or []:
            exercise_info = s.get("exercises", {}) or {}
            category = exercise_info.get("category", "other")

            if category not in stats_by_category:
                stats_by_category[category] = {
                    "volume": 0,
                    "sets": 0,
                    "last_trained": None,
                }

            vol = s["weight_kg"] * s["reps"]
            stats_by_category[category]["volume"] += vol
            stats_by_category[category]["sets"] += 1

            performed = datetime.fromisoformat(s["performed_at"].replace("Z", "+00:00"))
            if (
                stats_by_category[category]["last_trained"] is None
                or performed > stats_by_category[category]["last_trained"]
            ):
                stats_by_category[category]["last_trained"] = performed

        results = []
        today = datetime.now()

        for cat_str, data in stats_by_category.items():
            try:
                category = ExerciseCategory(cat_str)
            except ValueError:
                category = ExerciseCategory.OTHER

            days_since = None
            if data["last_trained"]:
                days_since = (today - data["last_trained"]).days

            results.append(MuscleGroupStats(
                category=category,
                total_volume_7d=round(data["volume"], 1),
                total_sets_7d=data["sets"],
                last_trained=data["last_trained"],
                days_since_trained=days_since,
            ))

        return sorted(results, key=lambda x: x.total_volume_7d, reverse=True)


# Singleton instance
_service: ExerciseService | None = None


def get_exercise_service() -> ExerciseService:
    """Get or create the exercise service instance."""
    global _service
    if _service is None:
        _service = ExerciseService()
    return _service
