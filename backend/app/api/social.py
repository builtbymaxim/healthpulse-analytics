"""Social features: Training Partners & Leaderboards."""

import secrets
from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel

from app.auth import get_current_user, CurrentUser
from app.database import get_supabase_client

router = APIRouter()


# --- Models ---

class InviteCodeResponse(BaseModel):
    code: str
    created_at: datetime
    expires_at: datetime | None
    uses_remaining: int | None


class UseInviteRequest(BaseModel):
    challenge_type: str = "general"
    duration_weeks: int | None = None  # None = ongoing


class PartnerSummary(BaseModel):
    id: UUID
    partner_id: UUID
    partner_name: str | None
    partner_avatar: str | None
    status: str
    challenge_type: str
    duration_weeks: int | None
    started_at: datetime | None
    expires_at: datetime | None
    days_remaining: int | None


class LeaderboardEntry(BaseModel):
    rank: int
    user_id: UUID
    display_name: str | None
    avatar_url: str | None
    value: float
    is_current_user: bool = False


# --- Invite Codes ---

@router.post("/invite-codes", response_model=InviteCodeResponse)
async def create_invite_code(
    current_user: CurrentUser = Depends(get_current_user),
):
    """Generate a 6-char invite code valid for 7 days."""
    supabase = get_supabase_client()

    code = secrets.token_hex(3).upper()  # e.g. "A3F2B1"
    expires_at = datetime.now(timezone.utc) + timedelta(days=7)

    result = (
        supabase.table("invite_codes")
        .insert({
            "code": code,
            "created_by": str(current_user.id),
            "max_uses": 1,
            "use_count": 0,
            "expires_at": expires_at.isoformat(),
        })
        .execute()
    )

    row = result.data[0]
    return InviteCodeResponse(
        code=row["code"],
        created_at=row["created_at"],
        expires_at=row["expires_at"],
        uses_remaining=row["max_uses"] - row["use_count"],
    )


@router.get("/invite-codes", response_model=list[InviteCodeResponse])
async def get_my_invite_codes(
    current_user: CurrentUser = Depends(get_current_user),
):
    """List my active (non-expired, not fully used) invite codes."""
    supabase = get_supabase_client()

    result = (
        supabase.table("invite_codes")
        .select("*")
        .eq("created_by", str(current_user.id))
        .gte("expires_at", datetime.now(timezone.utc).isoformat())
        .order("created_at", desc=True)
        .execute()
    )

    codes = []
    for row in result.data:
        remaining = row["max_uses"] - row["use_count"]
        if remaining > 0:
            codes.append(InviteCodeResponse(
                code=row["code"],
                created_at=row["created_at"],
                expires_at=row["expires_at"],
                uses_remaining=remaining,
            ))
    return codes


@router.post("/invite-codes/{code}/use", response_model=PartnerSummary)
async def use_invite_code(
    code: str,
    req: UseInviteRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Use an invite code to propose a training partnership."""
    supabase = get_supabase_client()

    # Find the invite code
    code_result = (
        supabase.table("invite_codes")
        .select("*")
        .eq("code", code.upper())
        .single()
        .execute()
    )
    if not code_result.data:
        raise HTTPException(status_code=404, detail="Invite code not found")

    invite = code_result.data

    # Validate code
    if invite["expires_at"] and datetime.fromisoformat(invite["expires_at"]) < datetime.now(timezone.utc):
        raise HTTPException(status_code=400, detail="Invite code has expired")

    if invite["use_count"] >= invite["max_uses"]:
        raise HTTPException(status_code=400, detail="Invite code has been used")

    inviter_id = invite["created_by"]
    if inviter_id == str(current_user.id):
        raise HTTPException(status_code=400, detail="Cannot use your own invite code")

    # Check for existing partnership
    existing = (
        supabase.table("partnerships")
        .select("id, status")
        .or_(
            f"and(inviter_id.eq.{inviter_id},invitee_id.eq.{current_user.id}),"
            f"and(inviter_id.eq.{current_user.id},invitee_id.eq.{inviter_id})"
        )
        .in_("status", ["pending", "active"])
        .execute()
    )
    if existing.data:
        raise HTTPException(status_code=400, detail="Partnership already exists with this user")

    # Create pending partnership (invitee proposes terms, inviter accepts)
    partnership = {
        "inviter_id": inviter_id,
        "invitee_id": str(current_user.id),
        "status": "pending",
        "challenge_type": req.challenge_type,
        "duration_weeks": req.duration_weeks,
    }

    p_result = (
        supabase.table("partnerships")
        .insert(partnership)
        .execute()
    )

    # Increment use count
    (
        supabase.table("invite_codes")
        .update({"use_count": invite["use_count"] + 1})
        .eq("id", invite["id"])
        .execute()
    )

    # Fetch inviter profile for response
    inviter_profile = (
        supabase.table("profiles")
        .select("id, display_name, avatar_url")
        .eq("id", inviter_id)
        .single()
        .execute()
    )

    p = p_result.data[0]
    profile = inviter_profile.data or {}
    return _build_partner_summary(p, current_user.id, profile)


# --- Partners ---

@router.get("/partners", response_model=list[PartnerSummary])
async def get_partners(
    current_user: CurrentUser = Depends(get_current_user),
):
    """List all partnerships (active + pending)."""
    supabase = get_supabase_client()

    result = (
        supabase.table("partnerships")
        .select("*")
        .or_(
            f"inviter_id.eq.{current_user.id},"
            f"invitee_id.eq.{current_user.id}"
        )
        .in_("status", ["pending", "active"])
        .order("created_at", desc=True)
        .execute()
    )

    if not result.data:
        return []

    # Collect all partner IDs to batch-fetch profiles
    partner_ids = set()
    for p in result.data:
        partner_id = p["invitee_id"] if p["inviter_id"] == str(current_user.id) else p["inviter_id"]
        partner_ids.add(partner_id)

    profiles = {}
    if partner_ids:
        profile_result = (
            supabase.table("profiles")
            .select("id, display_name, avatar_url")
            .in_("id", list(partner_ids))
            .execute()
        )
        for prof in profile_result.data:
            profiles[prof["id"]] = prof

    return [
        _build_partner_summary(p, current_user.id, profiles.get(
            p["invitee_id"] if p["inviter_id"] == str(current_user.id) else p["inviter_id"],
            {}
        ))
        for p in result.data
    ]


@router.put("/partners/{partnership_id}/accept", response_model=PartnerSummary)
async def accept_partnership(
    partnership_id: UUID,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Accept a pending partnership request (inviter accepts invitee's proposal)."""
    supabase = get_supabase_client()

    p_result = (
        supabase.table("partnerships")
        .select("*")
        .eq("id", str(partnership_id))
        .single()
        .execute()
    )
    if not p_result.data:
        raise HTTPException(status_code=404, detail="Partnership not found")

    p = p_result.data
    if p["status"] != "pending":
        raise HTTPException(status_code=400, detail="Partnership is not pending")

    # Only the inviter can accept
    if p["inviter_id"] != str(current_user.id):
        raise HTTPException(status_code=403, detail="Only the inviter can accept")

    now = datetime.now(timezone.utc)
    update_data = {
        "status": "active",
        "started_at": now.isoformat(),
    }
    if p["duration_weeks"]:
        update_data["expires_at"] = (now + timedelta(weeks=p["duration_weeks"])).isoformat()

    result = (
        supabase.table("partnerships")
        .update(update_data)
        .eq("id", str(partnership_id))
        .execute()
    )

    # Fetch partner profile
    partner_id = p["invitee_id"]
    profile_result = (
        supabase.table("profiles")
        .select("id, display_name, avatar_url")
        .eq("id", partner_id)
        .single()
        .execute()
    )

    return _build_partner_summary(result.data[0], current_user.id, profile_result.data or {})


@router.put("/partners/{partnership_id}/decline")
async def decline_partnership(
    partnership_id: UUID,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Decline a pending partnership request."""
    supabase = get_supabase_client()

    p_result = (
        supabase.table("partnerships")
        .select("*")
        .eq("id", str(partnership_id))
        .single()
        .execute()
    )
    if not p_result.data:
        raise HTTPException(status_code=404, detail="Partnership not found")

    p = p_result.data
    if p["status"] != "pending":
        raise HTTPException(status_code=400, detail="Partnership is not pending")

    # Either party can decline
    if p["inviter_id"] != str(current_user.id) and p["invitee_id"] != str(current_user.id):
        raise HTTPException(status_code=403, detail="Not your partnership")

    (
        supabase.table("partnerships")
        .update({"status": "declined"})
        .eq("id", str(partnership_id))
        .execute()
    )

    return {"message": "Partnership declined"}


@router.delete("/partners/{partnership_id}")
async def end_partnership(
    partnership_id: UUID,
    current_user: CurrentUser = Depends(get_current_user),
):
    """End an active partnership."""
    supabase = get_supabase_client()

    p_result = (
        supabase.table("partnerships")
        .select("*")
        .eq("id", str(partnership_id))
        .single()
        .execute()
    )
    if not p_result.data:
        raise HTTPException(status_code=404, detail="Partnership not found")

    p = p_result.data
    if p["inviter_id"] != str(current_user.id) and p["invitee_id"] != str(current_user.id):
        raise HTTPException(status_code=403, detail="Not your partnership")

    (
        supabase.table("partnerships")
        .update({"status": "ended"})
        .eq("id", str(partnership_id))
        .execute()
    )

    return {"message": "Partnership ended"}


# --- Leaderboards ---

@router.get("/leaderboard/{category}", response_model=list[LeaderboardEntry])
async def get_leaderboard(
    category: str,
    current_user: CurrentUser = Depends(get_current_user),
    exercise_name: str | None = Query(None, description="Exercise name for exercise_prs category"),
):
    """Get leaderboard among active training partners."""
    supabase = get_supabase_client()

    # Get active partner IDs
    partner_user_ids = await _get_active_partner_ids(supabase, current_user.id)
    if not partner_user_ids:
        return []

    # Include current user in leaderboard
    all_user_ids = list(partner_user_ids | {str(current_user.id)})

    if category == "exercise_prs":
        entries = _leaderboard_exercise_prs(supabase, all_user_ids, exercise_name)
    elif category == "workout_streaks":
        entries = _leaderboard_workout_streaks(supabase, all_user_ids)
    elif category == "nutrition_consistency":
        entries = _leaderboard_nutrition_consistency(supabase, all_user_ids)
    elif category == "training_consistency":
        entries = _leaderboard_training_consistency(supabase, all_user_ids)
    else:
        raise HTTPException(status_code=400, detail=f"Unknown category: {category}")

    # Mark current user and assign ranks
    entries.sort(key=lambda e: e["value"], reverse=True)
    result = []
    for i, entry in enumerate(entries):
        result.append(LeaderboardEntry(
            rank=i + 1,
            user_id=entry["user_id"],
            display_name=entry["display_name"],
            avatar_url=entry["avatar_url"],
            value=entry["value"],
            is_current_user=entry["user_id"] == str(current_user.id),
        ))

    return result


# --- Helpers ---

def _build_partner_summary(partnership: dict, current_user_id: UUID, partner_profile: dict) -> PartnerSummary:
    """Build a PartnerSummary from a partnership row and partner profile."""
    partner_id = (
        partnership["invitee_id"]
        if partnership["inviter_id"] == str(current_user_id)
        else partnership["inviter_id"]
    )

    days_remaining = None
    if partnership.get("expires_at"):
        expires = datetime.fromisoformat(partnership["expires_at"])
        if expires.tzinfo is None:
            expires = expires.replace(tzinfo=timezone.utc)
        remaining = (expires - datetime.now(timezone.utc)).days
        days_remaining = max(0, remaining)

    return PartnerSummary(
        id=partnership["id"],
        partner_id=partner_id,
        partner_name=partner_profile.get("display_name"),
        partner_avatar=partner_profile.get("avatar_url"),
        status=partnership["status"],
        challenge_type=partnership["challenge_type"],
        duration_weeks=partnership.get("duration_weeks"),
        started_at=partnership.get("started_at"),
        expires_at=partnership.get("expires_at"),
        days_remaining=days_remaining,
    )


async def _get_active_partner_ids(supabase, user_id: UUID) -> set[str]:
    """Get set of user IDs for all active partners."""
    result = (
        supabase.table("partnerships")
        .select("inviter_id, invitee_id")
        .or_(
            f"inviter_id.eq.{user_id},"
            f"invitee_id.eq.{user_id}"
        )
        .eq("status", "active")
        .execute()
    )

    partner_ids = set()
    for p in result.data:
        if p["inviter_id"] == str(user_id):
            partner_ids.add(p["invitee_id"])
        else:
            partner_ids.add(p["inviter_id"])
    return partner_ids


def _leaderboard_exercise_prs(supabase, user_ids: list[str], exercise_name: str | None) -> list[dict]:
    """Rank users by personal record for a given exercise."""
    if not exercise_name:
        return []

    # Find exercise by name
    ex_result = (
        supabase.table("exercises")
        .select("id")
        .ilike("name", exercise_name)
        .limit(1)
        .execute()
    )
    if not ex_result.data:
        return []

    exercise_id = ex_result.data[0]["id"]

    # Get PRs for this exercise across all partner users
    pr_result = (
        supabase.table("personal_records")
        .select("user_id, value")
        .eq("exercise_id", exercise_id)
        .eq("record_type", "weight")
        .in_("user_id", user_ids)
        .execute()
    )

    # Fetch profiles
    profiles = _fetch_profiles(supabase, user_ids)

    entries = []
    for pr in pr_result.data:
        prof = profiles.get(pr["user_id"], {})
        entries.append({
            "user_id": pr["user_id"],
            "display_name": prof.get("display_name"),
            "avatar_url": prof.get("avatar_url"),
            "value": float(pr["value"]),
        })
    return entries


def _leaderboard_workout_streaks(supabase, user_ids: list[str]) -> list[dict]:
    """Rank users by current workout streak (consecutive days with sessions, last 90 days)."""
    cutoff = (datetime.now(timezone.utc) - timedelta(days=90)).isoformat()

    sessions_result = (
        supabase.table("workout_sessions")
        .select("user_id, started_at")
        .in_("user_id", user_ids)
        .gte("started_at", cutoff)
        .order("started_at", desc=True)
        .execute()
    )

    # Group sessions by user and compute streak
    from collections import defaultdict
    user_dates: dict[str, set[str]] = defaultdict(set)
    for s in sessions_result.data:
        date_str = s["started_at"][:10]  # YYYY-MM-DD
        user_dates[s["user_id"]].add(date_str)

    profiles = _fetch_profiles(supabase, user_ids)

    entries = []
    today = datetime.now(timezone.utc).date()
    for uid in user_ids:
        dates = sorted(user_dates.get(uid, set()), reverse=True)
        streak = 0
        check_date = today
        for d_str in dates:
            from datetime import date as date_type
            parts = d_str.split("-")
            d = date_type(int(parts[0]), int(parts[1]), int(parts[2]))
            if d == check_date:
                streak += 1
                check_date -= timedelta(days=1)
            elif d < check_date:
                break

        prof = profiles.get(uid, {})
        entries.append({
            "user_id": uid,
            "display_name": prof.get("display_name"),
            "avatar_url": prof.get("avatar_url"),
            "value": float(streak),
        })
    return entries


def _leaderboard_nutrition_consistency(supabase, user_ids: list[str]) -> list[dict]:
    """Rank users by % of days within ±10% of calorie target (last 30 days)."""
    cutoff = (datetime.now(timezone.utc) - timedelta(days=30)).isoformat()

    # Get nutrition goals
    goals_result = (
        supabase.table("nutrition_goals")
        .select("user_id, calorie_target")
        .in_("user_id", user_ids)
        .execute()
    )
    user_targets = {g["user_id"]: g["calorie_target"] for g in goals_result.data}

    # Get food entries grouped by day
    entries_result = (
        supabase.table("food_entries")
        .select("user_id, logged_at, calories")
        .in_("user_id", user_ids)
        .gte("logged_at", cutoff)
        .execute()
    )

    from collections import defaultdict
    daily_cals: dict[str, dict[str, float]] = defaultdict(lambda: defaultdict(float))
    for e in entries_result.data:
        date_str = e["logged_at"][:10]
        daily_cals[e["user_id"]][date_str] += e["calories"] or 0

    profiles = _fetch_profiles(supabase, user_ids)

    result = []
    for uid in user_ids:
        target = user_targets.get(uid)
        if not target or target == 0:
            result.append({
                "user_id": uid,
                "display_name": profiles.get(uid, {}).get("display_name"),
                "avatar_url": profiles.get(uid, {}).get("avatar_url"),
                "value": 0.0,
            })
            continue

        days = daily_cals.get(uid, {})
        if not days:
            result.append({
                "user_id": uid,
                "display_name": profiles.get(uid, {}).get("display_name"),
                "avatar_url": profiles.get(uid, {}).get("avatar_url"),
                "value": 0.0,
            })
            continue

        consistent_days = sum(
            1 for cal in days.values()
            if abs(cal - target) <= target * 0.1
        )
        pct = (consistent_days / len(days)) * 100

        prof = profiles.get(uid, {})
        result.append({
            "user_id": uid,
            "display_name": prof.get("display_name"),
            "avatar_url": prof.get("avatar_url"),
            "value": round(pct, 1),
        })
    return result


def _leaderboard_training_consistency(supabase, user_ids: list[str]) -> list[dict]:
    """Rank users by training plan adherence % over last 30 days."""
    cutoff = (datetime.now(timezone.utc) - timedelta(days=30)).isoformat()

    # Get active training plans
    plans_result = (
        supabase.table("user_training_plans")
        .select("user_id, schedule")
        .in_("user_id", user_ids)
        .eq("is_active", True)
        .execute()
    )
    user_planned_days = {}
    for plan in plans_result.data:
        schedule = plan.get("schedule") or {}
        days_per_week = len(schedule)
        user_planned_days[plan["user_id"]] = days_per_week

    # Get workout sessions in last 30 days
    sessions_result = (
        supabase.table("workout_sessions")
        .select("user_id, started_at")
        .in_("user_id", user_ids)
        .gte("started_at", cutoff)
        .execute()
    )

    from collections import defaultdict
    user_session_count: dict[str, int] = defaultdict(int)
    for s in sessions_result.data:
        user_session_count[s["user_id"]] += 1

    profiles = _fetch_profiles(supabase, user_ids)

    result = []
    for uid in user_ids:
        planned = user_planned_days.get(uid, 0)
        expected = planned * 4  # ~4 weeks in 30 days
        actual = user_session_count.get(uid, 0)

        if expected > 0:
            pct = min(100.0, (actual / expected) * 100)
        else:
            pct = 0.0

        prof = profiles.get(uid, {})
        result.append({
            "user_id": uid,
            "display_name": prof.get("display_name"),
            "avatar_url": prof.get("avatar_url"),
            "value": round(pct, 1),
        })
    return result


def _fetch_profiles(supabase, user_ids: list[str]) -> dict[str, dict]:
    """Batch-fetch profiles for user IDs."""
    if not user_ids:
        return {}
    result = (
        supabase.table("profiles")
        .select("id, display_name, avatar_url")
        .in_("id", user_ids)
        .execute()
    )
    return {p["id"]: p for p in result.data}
