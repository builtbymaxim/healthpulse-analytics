# HealthPulse v1.0 — TestFlight PRD

**Status:** Locked for TestFlight beta. No scope additions permitted.
**Last updated:** 2026-03-05

---

## Core Value Proposition

HealthPulse is the **Actionable AI Companion** for serious athletes and health-optimizers. It doesn't just aggregate metrics — it synthesizes them into a daily readiness verdict and tells you exactly what to do with your body today. The core insight: your fitness data is only valuable when it changes your behavior. Every feature either reduces friction to logging or makes an actionable recommendation.

**One-line pitch:** *"Your personal coach who has read all your health data."*

---

## Target TestFlight Audience

**Primary segment:** 25–40 year old health-optimizing professionals

- Trains 3–5x/week (strength-focused, some cardio)
- Already wearing an Apple Watch; uses HealthKit passively
- Currently splits data across 2–4 apps (Whoop/Garmin for recovery, MFP for food, Strong for workouts)
- Frustrated nothing talks to each other; craves a single verdict
- Comfortable with beta software; values insight over polish

**Pilot size:** 50–100 testers, closed invite via in-app social invite code system.

**Recruitment:** Founder network first, then r/fitness and fitness Twitter/X.

---

## v1.0 Feature Scope (locked)

### Health & Recovery
- HealthKit auto-sync: steps, heart rate, HRV, resting HR, active calories
- Readiness & recovery scoring (ML model: scikit-learn + XGBoost)
- AI Narrative Dashboard: plain-English daily briefing with push/recovery verdict
- Burnout Horizon: trajectory prediction (overtraining risk)
- What-If Sandbox: simulate behavioral changes before committing

### Workouts
- Strength workout logging with 100+ exercise library
- Running workouts with GPS tracking + Live Activity widget
- Training plan management with progressive overload weight suggestions
- Personal records tracking

### Nutrition
- Manual food logging with calorie + macro tracking (protein, carbs, fat)
- AI Food Scanner: CoreML on-device → Gemini cloud fallback
- Barcode scanner
- Meal plans + recipe library (34 recipes, 12 templates)
- Metabolic readiness synthesis: macro targets adjusted to recovery state

### Sleep
- Manual sleep logging + quality scoring
- 30-day analytics (debt, consistency, trend)

### Insights & Experiments
- Correlation engine: surfaces statistical relationships in user's own data
- Experiment Tracks: structured n=1 hypothesis testing with outcome tracking
- Silent Correlation Feed: passive hypothesis surfacing

### Social
- Accountability partnerships
- Leaderboards (steps, calories, workouts)
- Invite code system for controlled beta recruitment

### Platform
- Calendar sync (EventKit) for workouts and meal plans
- GDPR: data export (JSON, all 18 table categories) + full account deletion
- Offline detection with animated banner + request retry logic
- Firebase Crashlytics crash reporting

### Explicitly out of v1.0
- Android
- ~~Apple Watch native app~~ — Basic companion shipped in V1.1 (workout mirror + set completion). Standalone workouts, complications, and readiness glance deferred to V1.2.
- OAuth integrations (Strava, Garmin, Oura, Whoop) — "Coming Soon" only
- In-app purchases / paywall — all features unlocked for beta testers

---

## Core User Journey

| Day | Moment | Experience |
|-----|--------|------------|
| 0 | First launch | 3-min onboarding: age, weight, goal, activity level |
| 1 | Morning | Dashboard: Readiness score + narrative — *"Recovery Day: HRV down 12%, slept 5.5h"* |
| 1 | Lunch | Scan food → AI identifies meal, populates macros in ~3 seconds |
| 1 | Evening | Log strength workout → progressive overload suggestion per exercise |
| 3 | Morning | Commitment strip shows today's training slot based on recovery state |
| 7 | Insights tab | First correlation surfaces: *"Your HRV is 18% higher after 7h+ sleep"* |
| 10 | Experiments | User creates n=1 test: *"Does creatine improve my recovery score?"* |
| 14 | In-app prompt | NPS survey + "Would you pay for this?" question fires |

---

## Beta Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Day 7 retention | ≥ 60% | Firebase Analytics (daily active / first open) |
| Core loop completion in week 1 (workout log + food scan + dashboard check) | ≥ 40% of testers | Backend event logs |
| Crash-free sessions | ≥ 98% | Firebase Crashlytics |
| Day 14 NPS | ≥ 40 | In-app survey prompt |
| "Would pay for this" | ≥ 50% | TestFlight survey |
| Food scanner acceptance rate | ≥ 75% | `scan_confirmed` backend events |
| Narrative dashboard p95 latency | < 3s | Railway structured logs |

**The single number that matters most:** Day 7 retention ≥ 60%. If the AI insights don't create a daily habit within a week, everything else is irrelevant.

---

## Open Items Before TestFlight Submission

| Item | Owner | Blocking? |
|------|-------|-----------|
| Add `GoogleService-Info.plist` to Xcode project | Dev | Yes |
| Configure dSYM upload build phase in Xcode | Dev | Yes |
| Backend: startup secret validation on Railway | Dev | Recommended |
| Backend: Supabase query timeouts (asyncio.wait_for) | Dev | Recommended |
| Backend: document/enforce max image size for food scan | Dev | Recommended |
| Privacy policy hosted at stable public URL | Dev | App Store (not TestFlight) |
| Certificate pinning (SPKI hash) | Dev | App Store (not TestFlight) |
| Shannon AI pentest | Dev | App Store (not TestFlight) |
| App Store privacy nutrition labels filed | Dev | App Store (not TestFlight) |
