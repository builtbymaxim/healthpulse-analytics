# HealthPulse Analytics — Project Status

> Last updated: 2026-04-22

## Overview

HealthPulse is a personal fitness and wellness companion app. It combines an iOS app (SwiftUI) with a Python backend (FastAPI) and Supabase (PostgreSQL) to deliver health tracking, nutrition management, workout logging, training plans, sleep analysis, and AI-powered insights.

### Tech Stack

| Layer | Technology |
|-------|-----------|
| **iOS App** | Swift / SwiftUI, HealthKit, EventKit, ActivityKit (Live Activities), Keychain |
| **Backend API** | Python 3.11, FastAPI, Pydantic v2, Uvicorn |
| **Database** | Supabase (PostgreSQL with RLS + Auth) |
| **ML** | scikit-learn, XGBoost, pandas, numpy |
| **Deployment** | Railway (auto-deploy on push to main) |

---

## Completed Phases

### Phase 1 — Health Data Sync & Core Infrastructure
- Supabase auth (email/password) with JWT tokens
- User profiles with onboarding flow (age, height, weight, gender, activity level, fitness goal)
- HealthKit integration: steps, heart rate, HRV, resting HR, active calories
- Core API structure: health metrics, daily scores, predictions
- Dashboard (TodayView) with welcome checklist for new users

### Phase 2 — Nutrition Tracking
- Food logging with calorie and macro tracking (protein, carbs, fat)
- Nutrition goals with BMR/TDEE calculation (Mifflin-St Jeor)
- Daily nutrition summary with calorie progress ring and macro bars
- Meal-type grouping (breakfast, lunch, dinner, snack)

### Phase 2.5 — Training Plans & Workout Integration
- Exercise library (100+ exercises across chest, back, shoulders, arms, legs, core)
- Training plan templates: Full Body Strength, Upper/Lower, PPL, Home Bodyweight (4 templates; Couch to 5K and Hybrid planned for V1.3+)
- Workout execution view with set-by-set logging (weight, reps, RPE)
- Personal record (PR) detection and celebration; rest timer with haptic feedback
- Exercise input types (weight+reps, reps-only, time-only, distance+time)

### Phase 3 — User Testing Feedback Fixes
- Input field fixes, RPE explanation sheet, sleep N+1 query optimization, training plan editing

### Phase 4 — Smart Dashboard
- Composite `/predictions/dashboard` endpoint replacing 4 individual API calls
- Enhanced Recovery Card, Progress Dashboard, Smart Recommendations, Weekly Summary

### Phase 5 — Background Execution, Live Activities & Notifications
- Background location tracking, state persistence via ActiveWorkoutManager
- Live Activities on lock screen + Dynamic Island
- Notification system: meal reminders, workout day reminders, weekly/monthly reviews

### Phase 6 — Calendar Integration
- Dedicated "HealthPulse" calendar via EventKit with auto-created workout events
- Conflict checking, preferred workout time picker, weekly auto-refresh

### Phase 7 — Progressive Overload
- Backend-driven weight suggestion system (`progression_service.py`)
- Linear progression (+2.5kg upper / +5kg lower), deload detection, inline suggestions

### Phase 8 — Sports Science, Social & Display Names
- Dual BMR (Mifflin-St Jeor + Katch-McArdle), calorie/macro cycling, goal-setting guardrails
- 4 new training plan templates, exercise swap UI, experience-level filtering
- Training partnerships, invite codes, 4 leaderboard categories
- Personalized greeting splash, display name, avatar picker

### Phase 9 — Meal Plans, Recipes & Barcode Scanning
- Recipe library (~65 recipes), 12 meal plan templates, barcode scanning via Open Food Facts
- Weekly meal planner (7-day grid), macro balance view, shopping list, calendar sync

### Phase 10 — App Distribution & GDPR
- iOS 17.0 deployment target, account deletion, data export, privacy policy

### Phase 11 — Visual Polish & Daily Causal Story Dashboard
- `MotionTokens` enum, custom glass tab bar, numeric text transitions
- Narrative dashboard endpoint with causal annotations, "Now / Next / Tonight" commitment framework, readiness-driven card reordering
- Profile editing (EditProfileView, avatar picker), training-plan-aware commitments, daily actions checklist
- Dashboard fixed layout, skeleton loading, stale-while-revalidate, double-load guard

### Phase 12 — AI Food Scanner + Metabolic Readiness
- Hybrid CoreML (Food-101) + Gemini 2.5 Flash Lite food scanner; USDA macro lookup
- Recovery-adjusted nutrition targets (`recovery_adjusted_targets()`), DeficitRadarCard, DeficitFixView
- Backend security hardening: CORS lockdown, rate limiting (slowapi), circuit breakers, retry utility, structured JSON logging, certificate pinning scaffold
- Comprehensive audit: 117 issues resolved (JWT JWKS verification, Keychain token storage, threading fixes, N+1 query eliminations)

### V1.1 — Workout UX Overhaul, Push Notifications, Watch Companion & Performance
- Focus Mode UI (FocusModeView, barbell weight picker, live workout bar, pre-workout overview)
- APNs push notifications with deep linking via TabRouter
- Apple Watch companion: workout mirror, "Hit it!" set completion, rest timer (Live Activity)
- In-memory response cache with event-driven invalidation; 2 Uvicorn workers
- Onboarding 15→11 steps, new logo + app icon, food search improvements
- All production database migrations applied (7 tables); JWT TTL fixed to 7 days

### V1.2 — Watch Readiness, Recovery Metrics & Sleep Analysis
- Watch readiness glance: score ring, intensity chip, narrative line, top causal factor
- Watch commitments display: Now / Next / Tonight slots from iPhone
- Watch health tracking: HKWorkoutSession, live heart rate, active calories, haptic feedback (rest-end, set-complete, workout start/stop)
- Rest timer alarm: UNUserNotificationCenter notification on Watch
- iPhone mini-player: rest state displayed during active workout
- Sleep analysis overhaul: legacy sleep identifier support (Oura/Whoop/older watchOS `.asleep`/`.inBed`), 72-hour lookback, stage breakdown (deep/REM/core/awake)

### V1.2.1 — Patch: Performance, Cache Fixes & Watch Build Blocker
- **Client caching:** Stale-while-revalidate pattern in APIService with disk-backed cache (Application Support/api_cache/)
  - `/predictions/dashboard*`: 120s fresh / 600s stale
  - `/nutrition/summary*`: 60s fresh / 900s stale
  - `/training-plans/today`: 300s fresh / 3600s stale
  - Cold start: UI renders from last-known snapshot on disk
- **Backend caching:** ETag + 60s in-process TTL cache on `/dashboard/narrative` endpoint
- **Nutrition refresh bug fix:** Mutations (logFood, updateFood, deleteFood, logSleep, logWorkout) now invalidate cache at source — all callers benefit without per-site changes
- **Sleep empty-state:** 3 distinct states (permission denied → link to Health app, permission granted but no data → "Log manually", never tracked → "Log your first night")
- **SleepView tab switch:** removed forced refetch on every tab visit — SWR layer manages freshness
- **Dashboard horizontal drift:** ThemedBackground glow circles have `.clipped()` to prevent scroll container expansion
- **Watch AppIcon build blocker:** Contents.json fix (`"platform": "watchos"` removed) unblocks simulator rebuild
- **Watch workout connectivity:** Bug fixes for message delivery (1) startTimer now calls updateLiveActivity immediately, (2) sendMessage falls back to transferUserInfo when Watch screen is off

---

## Architecture

### Backend API Routers

| Router | Prefix | Key Endpoints |
|--------|--------|---------------|
| `auth.py` | `/api/v1/auth` | POST `/login`, `/register`, `/refresh` |
| `users.py` | `/api/v1/users` | GET/PUT `/me`, `/me/settings`, `/me/weight`; POST `/me/device-token` |
| `metrics.py` | `/api/v1/metrics` | POST `/`, `/batch`; GET `/` |
| `workouts.py` | `/api/v1/workouts` | POST/GET/DELETE `/`; GET `/sets` |
| `exercises.py` | `/api/v1/exercises` | GET `/`, `/analytics/volume`, `/analytics/muscle-groups`; POST `/sets` |
| `nutrition.py` | `/api/v1/nutrition` | POST/GET `/food`, `/goal`; GET `/summary`, `/summary/weekly` |
| `sleep.py` | `/api/v1/sleep` | POST/GET `/`; GET `/summary`, `/history`, `/analytics` |
| `predictions.py` | `/api/v1/predictions` | GET `/dashboard`, `/dashboard/narrative`, `/recovery`, `/readiness` |
| `training_plans.py` | `/api/v1/training-plans` | GET `/templates`, `/today`; POST `/activate`, `/suggestions`; PUT `/{id}` |
| `social.py` | `/api/v1/social` | POST/GET `/invite-codes`; GET `/partners`, `/leaderboard/{category}`; PUT `/partners/{id}/accept` |
| `meal_plans.py` | `/api/v1/meal-plans` | GET `/recipes`, `/templates`, `/suggestions`, `/barcode/{code}`; POST `/quick-add`; CRUD `/weekly-plans` |
| `health.py` | `/` | GET `/health`, `/ready` |

### Backend Services

| Service | Purpose |
|---------|---------|
| `dashboard_service.py` | Composite dashboard data aggregation |
| `prediction_service.py` | ML predictions (recovery, readiness, trends) |
| `nutrition_calculator.py` | Dual BMR, TDEE, calorie/macro cycling, goal guardrails |
| `nutrition_service.py` | Food entry CRUD, daily summaries, cycling-aware targets |
| `exercise_service.py` | Exercise library + strength analytics |
| `progression_service.py` | Progressive overload weight suggestions |
| `sleep_service.py` | Sleep metrics + scoring |
| `wellness_calculator.py` | Wellness/recovery/readiness scoring |
| `meal_plan_service.py` | Recipe library, meal plan templates, barcode lookup |
| `push_service.py` | APNs push notifications via PyAPNs2 |

### iOS Views

| View | Purpose |
|------|---------|
| `ContentView` | Root tab navigation + greeting overlay |
| `AuthView` | Login/signup |
| `OnboardingView` | Profile setup wizard (11 steps) |
| `TodayView` | Smart dashboard |
| `WorkoutTabView` | Workout hub (today's plan + ad-hoc + history) |
| `WorkoutExecutionView` | Live workout logging |
| `RunningWorkoutView` | GPS-tracked running with Live Activities |
| `TrainingPlanView` | Plan management |
| `NutritionView` | Daily nutrition + food log |
| `SleepView` | Sleep tracking + analytics |
| `InsightsView` | AI insights + correlations |
| `TrendsView` | Historical trend charts |
| `SocialView` | Social features (partners, invites, leaderboards) |
| `RecipeLibraryView` | Recipe browsing, filtering, detail + quick-add |
| `WeeklyMealPlanView` | 7-day meal planner grid |
| `BarcodeScannerView` | Camera barcode scan + Open Food Facts lookup |
| `FoodScannerView` | AI food scanner (CoreML + cloud vision) |
| `FocusModeView` | Full-screen single-exercise workout focus |
| `LiveWorkoutBar` | Persistent bottom bar during active workout |
| `ProfileView` | Settings, baseline config, notifications, about |
| `LogView` | Daily check-in + metric logging |
| `WeightTrackingView` | Weight log + trend chart |
| `ReviewView` | Weekly/monthly review |
| `PRDetailView` | Exercise weight progression chart |

### iOS Services

| Service | Purpose |
|---------|---------|
| `APIService` | HTTP client for all backend calls (with retry + cache) |
| `AuthService` | Auth state, session management, Keychain tokens |
| `HealthKitService` | Apple Health read/write |
| `NotificationService` | Local notification scheduling + preferences |
| `CalendarSyncService` | EventKit calendar sync + conflict checking |
| `ActiveWorkoutManager` | Workout state persistence for background execution |
| `WatchConnectivityService` | Bi-directional iPhone ↔ Watch communication |
| `NetworkMonitor` | NWPathMonitor connectivity observer |
| `TabRouter` | Programmatic tab navigation |

### Database Tables (Supabase)

**Core:** `profiles`, `health_metrics`, `daily_scores`, `predictions`, `insights`
**Workouts:** `workouts`, `workout_sets`, `workout_sessions`, `exercises`, `exercise_progress`, `personal_records`
**Training:** `plan_templates`, `user_training_plans`
**Nutrition:** `nutrition_goals`, `food_entries`
**Meal Plans:** `recipes`, `meal_plan_templates`, `meal_plan_items`, `user_weekly_meal_plans`, `user_weekly_plan_items`
**Social:** `partnerships`, `invite_codes`

All tables have RLS enabled. User data is private; exercise library and plan templates are public read.

---

## Roadmap

> Strategic pivot: HealthPulse is evolving from a passive data tracker into an **Actionable AI Companion** — a system that synthesizes every data stream into a daily causal story and surfaces empathetic, personalized guidance at exactly the right moment.

### V1.3 — Watch Dashboard, Charts & HealthKit Expansion (in progress)

#### ✅ COMPLETED — HealthKit Expansion & Data Layer
- **New authorized + fetched (7 types):**
  - `vo2Max`, `respiratoryRate`, `oxygenSaturation`, `basalEnergyBurned` (iOS 17+)
  - `.heartRate` (historical), `.distanceWalkingRunning`, `.bodyMass` (already authorized, now fetching)
- **HealthKitService enhancements:**
  - 6 new `@Published` properties: `bodyMass`, `todayDistance`, `vo2Max`, `respiratoryRate`, `oxygenSaturation`, `basalEnergyBurned`
  - 6 new `fetch*()` methods, all wired into `refreshTodayData()` (parallel execution)
  - Added `ChartDataPoint` struct for graph serialization
  - `fetchStepHistory(period:)` — HKStatisticsCollectionQuery with hourly/daily/monthly bucketing
  - `fetchHRVHistory(days:)` — HKSampleQuery with date predicate, returns chronological array
  - `fetchDistanceHistory(period:)` — HKStatisticsCollectionQuery with hourly/daily/monthly bucketing
- **Build status:** ✅ BUILD SUCCEEDED, no breaking changes

#### ✅ COMPLETED — Watch Dashboard Foundation & 6-Tab Layout
- **WatchMessage protocol expansion:**
  - New enum case: `.dailySnapshotUpdate(WatchDailySnapshot)`
  - `WatchDailySnapshot` struct: nutrition (calories/macros/goals), sleep (hours/stages), steps, HR/HRV, training metadata, recovery score
  - `WatchConnectivityService.pushDailySnapshot()` — transfers snapshot to Watch via background message
- **Watch views (3 new glances):**
  - **NutritionGlanceView:** calorie progress ring, macro bars (protein/carbs/fat)
  - **SleepGlanceView:** sleep hours (large), stage breakdown bars (deep/REM/core)
  - **HealthMetricsView:** steps progress ring, RHR/HRV/VO2Max metric cards
- **6-tab TabView layout (auto-jump to tab 5 on workout start):**
  - Tab 0: ReadinessGlanceView
  - Tab 1: NutritionGlanceView (NEW)
  - Tab 2: SleepGlanceView (NEW)
  - Tab 3: HealthMetricsView (NEW)
  - Tab 4: CommitmentsView
  - Tab 5: WorkoutView/IdleView
- **WatchWorkoutStore:** added `snapshot: WatchDailySnapshot?` property, handles `.dailySnapshotUpdate` messages
- **Build status:** ✅ BUILD SUCCEEDED

#### ✅ COMPLETED — iPhone Detail Views
- **StepDetailView:** hourly/daily/monthly bar chart with goal overlay
  - Period selector (Today/7 Days/30 Days), normalized bar visualization
  - Total + average stats, entry point ready for Dashboard card + TrendsView wiring
- **HRVDetailView:** HRV trend summary with status indicator
  - 7/14/30 day period selector, normalized bar visualization
  - Current/average/status stats with color-coded health status (green/blue/orange)
  - Healthy zone reference (40–100 ms)
- **Build status:** ✅ BUILD SUCCEEDED

#### 🔄 PENDING — iPhone Integration & Watch Data Push
- **Dashboard card interactions:** Make step/HRV cards tappable → open detail sheets
- **TrendsView wiring:** Connect `steps` and `hrv` chips to detail views
- **TodayViewModel.pushWatchSnapshot():** Call after `loadDashboardData()`, on food mutations, on Watch `requestRefresh`
- **Complete data pipeline:** HealthKitService → TodayViewModel → WatchConnectivityService → Watch displays

#### Other V1.3 Items (from previous phase decisions)
- Sport pill grid: 2-row horizontal with Football/Basketball/Tennis + Other pill (1-tap access)
- Cycling → GPS tracker: route Cycling pill to RunningWorkoutView with `.cycling` mode (labeling, pace unit, km/h)
- "Manage Plan" CTA on top workout card → direct jump to plan editor
- Calories burned: Dashboard shows HealthKit `activeEnergyBurned` for today; workout history rows show per-session `calories_burned`
- Theme toggle in ProfileView: "Appearance: System / Light / Dark" → `@AppStorage("preferredColorScheme")`
- Light-mode QA pass: GlassCard opacity/shadow, WCAG AA contrast, chart colors, pill/chip accents, empty-state illustrations
- Weekly Weigh-In Prompt: UNUserNotificationCenter (Mon + Thu 08:00), in-app card on Today tab, auto-cancel for week after weight logged
- Plan-matching uses onboarding data: `modality` + `days_per_week` + `experience_level` + `fitness_goal`

#### Testing
- XCTest unit target (iPhone, `HealthPulseTests`) for pure-Swift tests: WatchMessage encode/decode roundtrip, sendMessage reachability fallback, step bucketing, HRV sorting
- Watch-side UAT on paired simulator (no unit test target for watchOS)

---

### Phase 13 — Experiment Tracks & Silent Correlation Feed (V1.4+)

#### 13A — Silent Correlation Feed
- Passive surfacing: correlations appear as quiet, non-interruptive cards at the bottom of the Insights tab
- Empathetic language: "We noticed something interesting: on weeks when you sleep more than 7h 30m, your squat tends to be about 4% heavier."
- Confidence gating: ≥21 data points, r ≥ 0.35; tap-to-experiment CTA

#### 13B — Experiment Tracks
- Hypothesis builder: 3-step flow (variable → metric → duration); pre-built experiment library
- Silent tracking — no check-ins; results shown as before/after visual at experiment end
- Backend: `experiment_service.py`, `experiments` table; iOS: `ExperimentTracksView` in InsightsView

---

### V2.0 — Localization & International Rollout

- Multi-language support: Spanish (es), French (fr), German (de) — fitness app market strongholds in Europe
- SwiftUI string extraction: `String(localized:)` / `LocalizedStringKey` for new UI (no retrofitting existing strings until feature stability reached)
- **Blocking issue:** AI-generated narrative text in backend requires language parameter through entire `dashboard_service.py` pipeline + multi-language prompt engineering + per-language QA — deferred until V1.3 feature set is frozen
- RTL support (Arabic/Hebrew) deferred to post-V2.0

### Phase 14 — Burnout Horizon & What-If Sandbox (V2.1+)

#### 14A — Burnout Horizon
- 14-day readiness forecast curve with confidence band; burnout risk indicator when readiness < 50% for 3+ days
- Causal breakdown of top 2–3 drivers; Protected Recovery Day recommendation
- Training plan integration: load modification suggestions surfaced in workout card

#### 14B — What-If Sandbox
- Interactive sliders: sleep target, training sessions, calorie surplus, rest days → instant readiness projection
- Scenario comparison: save up to 3 named scenarios as overlapping curves
- Backend: `forecast_service.py` (XGBoost regression on 30-day window), `/predictions/burnout-horizon` + `/predictions/whatif`

---

### Phase 15 — Android App (V2.1+)

- Kotlin / Jetpack Compose, feature parity with iOS (auth, dashboard, workouts, nutrition, sleep, training plans)
- Health Connect integration, Google Calendar, Material Design 3 / Material You theming
- Google Play Store distribution

---

## Future Ideas

> Filtered for the **Actionable AI Companion** philosophy.

### Intelligence & Coaching

| Feature | Description | Complexity |
|---------|-------------|------------|
| **Conversational AI Coach** | In-app chat grounded in user's own data — "How's my recovery?", "What should I eat before my workout?" | High |
| **Smart Deload Detection** | Detect fatigue accumulation from training load + recovery trends; suggest deload before performance declines. | Medium |
| **Supplement Impact Tracking** | Log supplements; silently correlate with recovery score and sleep quality via Correlation Feed. | Medium |
| **Injury-Aware Plan Modification** | Log injury + affected muscles; plan auto-substitutes exercises for recovery period. | Medium |

### Nutrition Intelligence

| Feature | Description | Complexity |
|---------|-------------|------------|
| **Hydration Recovery Optimization** | Track water intake; correlate with HRV and sleep; surface recovery-adjusted hydration targets. | Low |
| **Contextual Meal Timing** | Meal timing suggestions based on workout schedule and circadian data. | Medium |

### Training Intelligence

| Feature | Description | Complexity |
|---------|-------------|------------|
| **1RM Calculator & %-based Programming** | Estimate 1RM via Epley/Brzycki; auto-calculate working weights as % of 1RM. | Medium |
| **Periodization Engine** | Multi-week mesocycle planning with auto-progression phases. Works with Burnout Horizon. | High |
| **Heart Rate Zone Training** | Real-time cardio zone overlay during runs; zone-based pacing coach. | Medium |
| **AI Form Check** | ML-based form analysis via camera during live workouts. | High |
| **Warmup/Cooldown Generator** | AI-generated sequences based on targeted muscle groups and soreness signals. | Medium |

### Social & Behavioral

| Feature | Description | Complexity |
|---------|-------------|------------|
| **Time-bound Challenges** | Structured partner challenges with defined metrics and duration. | Medium |
| **Achievements & Milestones** | PR milestones, streak badges, nutrition consistency awards. | Medium |
| **Siri Shortcuts** | "Hey Siri, start my chest workout" / "Log 200g chicken breast" / "What's my readiness today?" | Medium |

### Platform Expansion

| Feature | Description | Complexity |
|---------|-------------|------------|
| **Apple Watch App** | V1.1: workout mirror + "Hit it!" set completion + rest timer (Live Activity). V1.2: readiness glance, commitments display, HKWorkoutSession HR/calories, rest timer alarm, haptics. V1.2.1: connectivity fixes (startTimer pushes state immediately, message fallback on screen-off). V1.3: full dashboard (nutrition/sleep/health metrics, 6-tab layout). Standalone workout start on Watch + complications deferred to V1.4. | High |
| **Weekly Weigh-In Prompt** | Periodic reminder (Mon + Thu 08:00) to log weight via UNUserNotificationCenter + in-app card on Today tab. Cancels for week after weight logged. V1.3 feature. | Low |
| **Exercise Auto-Detection (V2.0)** | CoreML Activity Classification trained on Watch accelerometer + gyroscope data. Requires ~500+ labeled reps/exercise, CreateML training, on-device inference. Deferred — data collection effort + accuracy risks for serious athletes. | Very High |
| **Home Screen Widgets** | WidgetKit: readiness summary, calorie ring, workout streak. | Medium |
| **iPad Layout** | Multi-column dashboard, side-by-side workout logging, expanded What-If Sandbox. | Medium |
| **Strava Sync** | Bi-directional: import Strava runs + export HealthPulse sessions. | Medium |

---

> **Deliberately removed from Future Ideas:**
> - ~~Workout Sharing Cards~~ — social vanity
> - ~~Activity Feed~~ — passive social consumption
> - ~~Apple Music integration~~ — entertainment, not health-actionable
> - ~~MyFitnessPal Import~~ — one-time migration utility
> - ~~Custom Exercise Builder~~ — pure CRUD, no AI angle
> - ~~Android App~~ — promoted to Phase 15 Roadmap

---

## Repository Structure

```
healthpulse-analytics/
├── backend/
│   ├── app/
│   │   ├── main.py              # FastAPI app + router registration
│   │   ├── auth.py              # JWT verification (ES256 JWKS + HS256)
│   │   ├── config.py            # Settings (env vars)
│   │   ├── api/                 # Route handlers
│   │   │   ├── auth.py, users.py, metrics.py, workouts.py
│   │   │   ├── exercises.py, nutrition.py, sleep.py
│   │   │   ├── predictions.py, training_plans.py, social.py, meal_plans.py, health.py
│   │   ├── services/            # Business logic
│   │   │   ├── dashboard_service.py, prediction_service.py
│   │   │   ├── nutrition_service.py, nutrition_calculator.py
│   │   │   ├── exercise_service.py, sleep_service.py
│   │   │   ├── wellness_calculator.py, meal_plan_service.py, push_service.py
│   │   └── models/              # Pydantic models + DB config
│   ├── requirements.txt
│   ├── Procfile, railway.json
│   └── tests/
├── ios/
│   └── HealthPulse/HealthPulse/HealthPulse/
│       ├── HealthPulseApp.swift  # App entry point
│       ├── Views/               # All SwiftUI views (30+ files)
│       │   ├── DashboardCards/  # Extracted dashboard card components
│       │   └── Components/      # Reusable UI components (AppTheme, GlassCard, etc.)
│       ├── ViewModels/          # TodayViewModel, WorkoutExecutionViewModel, etc.
│       ├── Services/            # API, Auth, HealthKit, Keychain, TabRouter, WatchConnectivity, etc.
│       ├── Models/              # Codable models
│       └── Info.plist           # Permissions + capabilities
│   └── HealthPulseWatch Watch App/   # Apple Watch companion app
├── docs/
│   ├── database-schema.sql
│   ├── migration-*.sql
│   ├── seed-plan-templates.sql
│   └── privacy-policy.md
└── PROJECT_STATUS.md            # This file
```
