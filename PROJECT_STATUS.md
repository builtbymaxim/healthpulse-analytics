# HealthPulse Analytics — Project Status

> Last updated: 2026-02-27

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
- Profile & Goals view with live calorie/macro target preview

### Phase 2.5 — Training Plans & Workout Integration
- Exercise library (100+ exercises across chest, back, shoulders, arms, legs, core)
- Training plan templates: Full Body Strength, Upper/Lower, PPL, Home Bodyweight, Couch to 5K, Hybrid
- Plan setup flow: goal → modality → equipment → schedule → plan suggestion
- Workout execution view with set-by-set logging (weight, reps, RPE)
- Key lift vs accessory distinction with section headers
- Personal record (PR) detection and celebration
- Rest timer with haptic feedback
- Unified workouts table (plan-based + standalone)
- Workout detail view with edit/delete
- Exercise input types (weight+reps, reps-only, time-only, distance+time)
- Plan editing (schedule customization, exercise swaps)

### Phase 3 — User Testing Feedback Fixes
- Input field "0 stays" fix (optional values with overlay placeholders)
- RPE explanation sheet (info button with 1-10 scale guide)
- Key lift vs accessory section headers for clarity
- Sleep page N+1 query optimization (67 queries → batch fetch)
- Training plan editing/customization via EditScheduleSheet + PUT endpoint

### Phase 4 — Smart Dashboard
- Composite `/predictions/dashboard` endpoint (replaces 4 individual API calls)
- Enhanced Recovery Card with contributing factors (sleep, HRV, training load)
- Progress Dashboard: key lift progress, recent PRs, muscle balance grid
- Smart Recommendations: personalized cards based on recovery/readiness/training data
- Weekly Summary Card: workouts completed, avg sleep, nutrition adherence

### Phase 5 — Background Execution, Live Activities & Notifications
- Background location tracking for running workouts (survives phone lock)
- State persistence via ActiveWorkoutManager (survives app termination)
- Live Activities: lock screen + Dynamic Island showing time/distance/pace
- Notification system: meal reminders (adjustable times), workout day reminders, weekly/monthly reviews
- Notification preferences UI with per-type toggles and meal time pickers

### Phase 6 — Calendar Integration
- Dedicated "HealthPulse" calendar via EventKit (iCloud preferred, green color)
- Auto-create events for next 4 weeks when plan is activated or edited
- Events include workout name, exercise list, estimated duration, 30-min alarm
- Preferred workout time picker during plan activation flow
- Calendar conflict checking (shows overlapping events per training day)
- Conflict indicators in EditScheduleSheet when calendar sync is enabled
- Calendar settings page: toggle sync, change workout time, "Sync Now" button
- Weekly auto-refresh (re-syncs every 7 days on app foreground)
- Clean removal of events on plan deactivation, full calendar cleanup on logout
- iOS 17 `requestFullAccessToEvents()` with iOS 16 fallback

### Phase 7 — Progressive Overload
- Backend-driven weight suggestion system (progression_service.py)
- Auto-suggest next weight based on completed sets and RPE from recent sessions
- Linear progression: +2.5kg upper body / +5kg lower body per session (RPE ≤ 8)
- Maintain current weight when RPE is 9-10 or reps fall below target
- Deload detection: auto-reduce -10% after 2+ consecutive stagnant sessions with high RPE
- Suggestions shown inline in both plan workout and standalone strength logging views
- Pre-fills empty weight fields with suggested weight when workout starts

---

## Current Features

### Authentication & Profile
- Email/password sign-up/sign-in via Supabase Auth
- JWT token verification (ES256 via JWKS + HS256 fallback)
- Token stored in iOS Keychain (migrated from UserDefaults)
- User profile: age, height, weight, gender, activity level, fitness goal
- Dietary preferences: diet type, allergies, meals per day, fasting window
- Training experience level + motivation + optional body fat %
- Baseline settings: HRV baseline, resting HR baseline, target sleep, step goal
- Unit preferences (metric/imperial)

### Dashboard (TodayView)
- Readiness header with score ring, greeting context ("Push Day" / "Recovery Day"), and narrative text
- "Now / Next / Tonight" commitment strip with load modifier badges
- Welcome checklist for new users
- Dynamic card ordering based on readiness score (high → workout first; low → recovery first)
- Today's planned workout card
- Nutrition progress (calorie ring + macro bars)
- Smart recommendations (personalized based on data)
- Weekly summary (workouts, sleep, nutrition adherence)
- Causal recovery card with inline annotation ("mainly because sleep was 5h 40m")
- Progress section (key lifts, PRs, muscle balance)
- Last workout performance card
- Social rank card (when opted in) — shows leaderboard rank + active partners, pushes to SocialView
- Nutrition adherence chart (7-day)
- Quick stats (steps, sleep, resting HR)
- Graceful fallback to static card order when narrative endpoint unavailable

### Workouts
- Running workout with GPS tracking, live pace, background execution
- Live Activities on lock screen + Dynamic Island during runs
- Strength workout logging with set-by-set tracking
- Exercise picker with category filters and search
- Auto-fill previous weights, PR detection
- Rest timer between sets
- Cancel confirmation dialog
- Completion celebration screen with motivational messages + workout summary
- Save error alert with retry option
- Progressive overload: auto-suggested weights based on recent session history
- Inline suggestion hints (increase/maintain/deload) with tap-to-fill
- Workout detail view with history
- Training plan integration (plan workouts + ad-hoc)

### Training Plans
- 10 plan templates (Full Body, Upper/Lower, PPL, Home Bodyweight, C25K, Hybrid, Time-Crunched, Glute & Hypertrophy, Longevity & Mobility, Athletic Performance)
- Plan setup wizard: goal → modality → equipment → schedule
- Weekly schedule view with workout cards
- Plan editing (swap exercises, change days) with calendar conflict indicators
- Exercise swap sheet with muscle-group-matched alternatives
- Experience-level auto-filtering (beginner/intermediate/advanced)
- Difficulty badges on template cards (color-coded)
- Deactivate plan with confirmation
- Today's workout card linking to execution
- Calendar sync: auto-create events in dedicated HealthPulse calendar (4 weeks rolling)
- Plan activation sheet: time picker + conflict checking before activating

### Nutrition
- Daily calorie and macro tracking
- Food logging with meal type (breakfast/lunch/dinner/snack)
- Swipe-to-delete and tap-to-edit on food entries
- Animated calorie progress ring and macro progress bars
- Dual BMR: Mifflin-St Jeor + Katch-McArdle (when body fat % known)
- Calorie/macro cycling: training day +10% kcal (higher carbs), rest day compensating (higher protein)
- Goal-setting guardrails with safe rate validation and calorie floors
- Custom calorie target override
- Custom recipe creation (user-owned recipes)
- Dietary preference filtering (vegan/vegetarian/keto/pescatarian + allergen exclusion)
- Pull-to-refresh without hiding content

### Sleep
- Sleep logging (bed time, wake time, quality, optional stages)
- Sleep stages visualization (deep, REM, light) with horizontal bar
- Sleep history chart (7/14/30 days)
- 30-day sleep analytics (avg duration, avg score, sleep debt, consistency)
- Trend indicators (improving/declining/stable)

### Insights
- AI-generated insights from API (recommendations, trends, achievements)
- Correlation analysis (sleep↔recovery, stress↔HRV, exercise↔mood)
- Empty state cards when insufficient data

### Notifications
- Meal reminders with user-adjustable times (breakfast, lunch, dinner)
- Workout day reminders (8 AM on training days)
- Weekly review (Sunday 6 PM)
- Monthly review (1st of month, 10 AM)
- Per-type toggles in settings
- OS-level notification status check with "Open Settings" fallback

### Trends
- Historical data visualization powered by real API data
- Metric selection with pull-to-refresh
- Chart views using Swift Charts

---

## Architecture

### Backend API Routers

| Router | Prefix | Key Endpoints |
|--------|--------|---------------|
| `auth.py` | `/api/v1/auth` | POST `/login`, `/register`, `/refresh` |
| `users.py` | `/api/v1/users` | GET/PUT `/me`, `/me/settings`, `/me/weight` |
| `metrics.py` | `/api/v1/metrics` | POST `/`, `/batch`; GET `/` |
| `workouts.py` | `/api/v1/workouts` | POST/GET/DELETE `/`; GET `/sets` |
| `exercises.py` | `/api/v1/exercises` | GET `/`, `/analytics/volume`, `/analytics/muscle-groups`; POST `/sets` |
| `nutrition.py` | `/api/v1/nutrition` | POST/GET `/food`, `/goal`; GET `/summary`, `/summary/weekly` |
| `sleep.py` | `/api/v1/sleep` | POST/GET `/`; GET `/summary`, `/history`, `/analytics` |
| `predictions.py` | `/api/v1/predictions` | GET `/dashboard`, `/dashboard/narrative`, `/recovery`, `/readiness` |
| `training_plans.py` | `/api/v1/training-plans` | GET `/templates`, `/today`; POST `/activate`, `/suggestions`; PUT `/{id}` |
| `social.py` | `/api/v1/social` | POST/GET `/invite-codes`; GET `/partners`, `/leaderboard/{category}`; PUT `/partners/{id}/accept` |
| `meal_plans.py` | `/api/v1/meal-plans` | GET `/recipes`, `/templates`, `/suggestions`, `/barcode/{code}`; POST `/quick-add`; CRUD `/weekly-plans` (13 endpoints) |
| `health.py` | `/` | GET `/health`, `/ready` |

### Backend Services

| Service | Purpose |
|---------|---------|
| `dashboard_service.py` | Composite dashboard data aggregation |
| `prediction_service.py` | ML predictions (recovery, readiness, trends) |
| `nutrition_calculator.py` | Dual BMR (Mifflin-St Jeor + Katch-McArdle), TDEE, calorie/macro cycling, goal guardrails |
| `nutrition_service.py` | Food entry CRUD, daily summaries, daily cycling-aware targets |
| `exercise_service.py` | Exercise library + strength analytics |
| `progression_service.py` | Progressive overload weight suggestions |
| `sleep_service.py` | Sleep metrics + scoring |
| `wellness_calculator.py` | Wellness/recovery/readiness scoring |
| `meal_plan_service.py` | Recipe library, meal plan templates, barcode lookup (Open Food Facts) |

### iOS Views

| View | Purpose |
|------|---------|
| `ContentView` | Root tab navigation + greeting overlay |
| `AuthView` | Login/signup |
| `OnboardingView` | Profile setup wizard (15 steps incl. name, dietary profile, experience) |
| `GreetingView` | Animated daily greeting splash on app open |
| `TodayView` | Smart dashboard (500+ lines) |
| `WorkoutTabView` | Workout hub (today's plan + ad-hoc + history) |
| `WorkoutExecutionView` | Live workout logging |
| `RunningWorkoutView` | GPS-tracked running with Live Activities |
| `StrengthWorkoutLogView` | Set-by-set strength logging |
| `WorkoutDetailView` | Past workout details |
| `TrainingPlanView` | Plan management |
| `NutritionView` | Daily nutrition + food log |
| `FoodLogView` | Food entry form |
| `SleepView` | Sleep tracking + analytics |
| `InsightsView` | AI insights + correlations |
| `TrendsView` | Historical trend charts |
| `SocialView` | Social features (partners, invites, leaderboards) — pushed from dashboard |
| `RecipeLibraryView` | Recipe browsing, filtering, detail + quick-add |
| `MealPlanBrowseView` | Meal plan templates, detail + shopping list |
| `BarcodeScannerView` | Camera barcode scan + Open Food Facts lookup |
| `WeeklyMealPlanView` | 7-day meal planner grid + macro balance + calendar sync |
| `ProfileView` | Settings, baseline config, notifications, about |
| `LogView` | Daily check-in + metric logging |

### iOS Services

| Service | Purpose |
|---------|---------|
| `APIService` | HTTP client for all backend calls |
| `AuthService` | Auth state, session management, Keychain tokens |
| `HealthKitService` | Apple Health read/write |
| `KeychainService` | Secure token storage (SecItem) |
| `NotificationService` | Local notification scheduling + preferences |
| `CalendarSyncService` | EventKit calendar sync + conflict checking |
| `ActiveWorkoutManager` | Workout state persistence for background execution |
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

## Audit Status

### Comprehensive Audit (3 parallel agents)

Audited the entire codebase across backend APIs, iOS services, and iOS views. Found **117 total issues** (23 CRITICAL, 43 WARNING, 51 IMPROVEMENT).

### Batch 1 — Completed (commit `ccaef9e`)
10 fixes across 16 files:

| Fix | Category |
|-----|----------|
| NotificationService compilation error (called private method) | Bug |
| RunningWorkoutView 100Hz timer → 10Hz | Performance |
| Time format MM:SS:CC → H:MM:SS / MM:SS.CC | UX |
| AuthView timer memory leak (missing invalidate) | Bug |
| TrendsView random data → real API data | Bug |
| WorkoutExecutionView cancel confirmation dialog | UX |
| TrainingPlanView deactivate confirmation dialog | UX |
| TodayViewModel sequential → parallel loading (async let) | Performance |
| Backend: refresh token moved to body, PR upsert race condition | Security/Bug |
| NSAllowsArbitraryLoads removed, deprecated onChange fixed, day abbreviations disambiguated, dead code removed | Security/UX/Cleanup |

### Batch 2 — Completed (commit `94fc0f7`)
7 fixes across 8 files:

| Fix | Category |
|-----|----------|
| JWT ES256 signature verification via Supabase JWKS | CRITICAL Security |
| Auth tokens moved from UserDefaults to iOS Keychain | CRITICAL Security |
| NutritionView: keep content visible during pull-to-refresh | UX |
| SleepView: guard against division by zero in sleep stages | Bug |
| BaselineSettingsView: show loading spinner instead of defaults | UX |
| InsightsView: remove demo data flash, load only from API | UX |
| FilterChip color blue → green for consistency | UX |

### Batch 3 — Completed (commit `b673daf` + build fix)
5 fixes across 7 files:

| Fix | Category |
|-----|----------|
| RunLocationManager: wrapped @Published mutations in DispatchQueue.main.async | CRITICAL Bug |
| NotificationService: added @MainActor, import Combine, fixed async center.add() | Threading |
| Token refresh: store refresh token in Keychain, silent 401 retry with TokenRefreshCoordinator actor | Security/UX |
| Dashboard N+1: batched _get_key_lift_progress (15→3 queries) and _get_nutrition_adherence (7→1 query) | Performance |
| DailyCheckin/MetricLog: replaced stubs with real API calls (logMetricsBatch, logMetric) | Bug |

### Workout Completion UX Fix

| Fix | Category |
|-----|----------|
| "Complete Workout" button: rounded corners, hint text when disabled | UX |
| Workout completion celebration screen with animated checkmark + motivational messages | UX |
| Workout summary stats (duration, exercises, sets) on completion | UX |
| Save error: alert with retry instead of silent toast | UX/Bug |
| Timer restarts on save failure so workout isn't lost | Bug |

### Backend Bug Fix — Personal Records

| Fix | Category |
|-----|----------|
| `_check_and_update_prs`: use `exercise_id` instead of non-existent `exercise_name` column | CRITICAL Bug |
| Remove non-existent `workout_session_id` from PR upsert data | Bug |
| Batch-lookup exercise IDs by name before PR checking | Performance |

### Phase 8A — Display Name & Personalized Greetings

| Change | Details |
|--------|---------|
| Onboarding name step | New step after welcome: "What should we call you?" with text field |
| Backend onboarding | `display_name` accepted in `POST /me/onboarding` |
| Animated greeting splash | Full-screen daily rotating motivational message + name on app open (~2s animation) |
| Background data prefetch | Dashboard loads behind greeting overlay — zero-spinner transition |
| TodayView greeting | "Good morning/afternoon/evening, {name}!" in welcome checklist |
| Workout celebration | Personalized messages: "Crushed it, {name}!" mixed with generic ones |

### Phase 8B — Social Features (Training Partners & Leaderboards)
- Training Partnerships: time-bound, challenge-based connections with mutual consent
- Invite code system (6-char hex codes, 7-day expiry, single use)
- Partnership terms: both users agree on challenge type + duration before connecting
- Challenge types: General, Strength, Consistency, Weight Loss
- Duration options: 4 weeks, 8 weeks, 3 months, 6 months, ongoing
- Social view: accessed via dashboard rank card (no dedicated tab)
- Social opt-in during onboarding (step 11) + toggle in Profile settings
- 4 Leaderboard categories among active partners:
  - Exercise PRs (per exercise, ranked by 1RM)
  - Workout Streaks (consecutive training days)
  - Nutrition Consistency (% days within calorie target)
  - Training Consistency (% plan adherence)
- New DB tables: `partnerships`, `invite_codes`
- Backend social router: 8 endpoints (invite codes, partners, leaderboards)
- All cross-user queries server-side (backend uses service key, no RLS changes on existing tables)

### Phase 9 — Meal Plans, Recipes & Barcode Scanning
- Recipe library: ~65 pre-seeded recipes with ingredients, instructions, macros per serving
- Recipes tagged by category (breakfast/lunch/dinner/snack/dessert/shake) and goal type
- 12 meal plan templates (3 per goal: lose_weight, build_muscle, maintain, general_health)
- Quick-add: one-tap recipe → food_entry with correct macros (`source="recipe"`)
- Barcode scanning via Open Food Facts API (4M+ products, free, open source)
- Scan any packaged product → auto-fill nutrition per 100g → log to food diary (`source="barcode"`)
- Shopping/ingredient list: consolidated ingredients from meal plan templates
- Goal-aligned recipe suggestions based on user's nutrition goal
- New DB tables: `recipes`, `meal_plan_templates`, `meal_plan_items`
- Backend meal_plans router: 8 endpoints (recipes, templates, quick-add, barcode, shopping list)
- iOS views: RecipeLibraryView, MealPlanBrowseView, BarcodeScannerView

### Phase 9A — Weekly Meal Planner
- Weekly meal planner: 7-day × 4-meal-type grid (tap to place/swap/remove recipes)
- Auto-fill from template (repeat same meals daily or rotate across the week)
- Macro balance view: per-day cal/P/C/F vs user targets with color indicators
- Recurring plans with copy-to-next-week
- Weekly shopping list: consolidated ingredients across all 7 days with share/export
- Apply to food log: batch-insert today's or full week's meals as food_entries (`source="meal_plan"`)
- Calendar sync: meal events in HealthPulse iOS calendar (breakfast 8:00, lunch 12:30, dinner 19:00, snack 15:30)
- Scoped calendar event management (meal events coexist with workout events via notes prefix)
- New DB tables: `user_weekly_meal_plans`, `user_weekly_plan_items`
- Backend: 13 new endpoints (weekly plan CRUD, auto-fill, macros, apply, shopping list, copy)
- iOS: WeeklyMealPlanView (grid + macro balance + recipe picker + template filler + shopping list)

### Phase 10 — App Distribution & GDPR Compliance
- iOS deployment target lowered from 26.0 (beta) to 17.0 for TestFlight compatibility
- Info.plist cleaned: removed dev-only keys (local networking, Bonjour, inaccurate HealthKit write description)
- Complete account deletion: cascading profile delete + `auth.admin.delete_user()` to remove auth record
- Data export endpoint: `GET /users/me/export` returns all 18 user-data table categories as JSON
- Two-step delete confirmation in ProfileView (alert → second confirmation → delete + sign out)
- Export My Data in ProfileView → JSON file → iOS share sheet via `UIActivityViewController`
- Privacy policy document (`docs/privacy-policy.md`) covering GDPR Articles 15, 17, 20
- Dynamic app version display in About screen via `Bundle.main.infoDictionary`

### Production Bug Fixes & Database Migrations
- Applied 3 database migrations to production Supabase (7 missing tables causing 500 errors):
  - Meal plans: `recipes` (34 seed recipes), `meal_plan_templates` (12 templates), `meal_plan_items`
  - Social: `partnerships`, `invite_codes`
  - Weekly meal plans: `user_weekly_meal_plans`, `user_weekly_plan_items`
- Fixed BarcodeScannerView crash: added missing `NSCameraUsageDescription` to Info.plist
- Fixed BarcodeScannerView build error: changed `selectedMealType` from `String` to `MealType` enum
- Fixed missing `import UIKit` in BarcodeScannerView (UIColor/UILabel) and ProfileView (UIActivityViewController)
- Fixed missing `import Combine` in WeeklyMealPlanView (ObservableObject/Published)

### UX, Session & Audit Fixes

**UX & Session (5 fixes):**

| Fix | Category |
|-----|----------|
| Onboarding flash fix: cache `isOnboardingComplete` in UserDefaults so logged-in users skip onboarding | UX |
| Proactive token refresh: schedule refresh at 80% of expiry via `Task.sleep`, persist across app launches | Session |
| AppLogo dark mode: fixed `Contents.json` mapping dark variant to `"value": "dark"` (was backwards) | UX |
| Onboarding button tap targets: added `.contentShape(Rectangle())` to all option cards | UX |
| Keyboard dismissal on name step: `@FocusState` binding + dismiss on Continue tap | UX |

**Audit (6 fixes):**

| Fix | Category |
|-----|----------|
| `CLLocationManager` main thread init: deferred creation with `DispatchQueue.main.sync` fallback | CRITICAL Bug |
| Health readiness check: real DB query instead of hardcoded `"ok"` | HIGH Bug |
| Empty catch blocks → error states with retry UI in MealPlanBrowseView + RecipeLibraryView | MEDIUM Bug |
| Backend `print()` → `logging` in users.py (15 statements) | MEDIUM Quality |
| Silent backend exceptions: added `logger.warning/exception` in predictions, nutrition, dashboard, meal plan services | MEDIUM Quality |
| OAuth buttons → "Coming Soon" labels for Strava/Garmin/Oura/Whoop | LOW UX |

### Social Tab → Dashboard Card Consolidation
- Removed Social from tab bar — now 5 tabs: Dashboard, Nutrition, Workout, Sleep, Profile
- Removed WorkoutStreakCard from dashboard (redundant with Last Workout card)
- Added SocialRankCard on dashboard (visible when social opted in): shows workout streak rank + active partners count
- Tapping SocialRankCard pushes SocialView via NavigationStack (single back arrow, no double-navigation confusion)
- Social hidden entirely from dashboard when opted out

### Phase 12 — AI Food Scanner (Hybrid CoreML + Cloud Vision)
- **On-device classification:** CoreML Food-101 model for instant local classification
- **Cloud vision fallback:** When CoreML confidence < 70%, falls back to Gemini 2.5 Flash Lite
- **USDA macro lookup:** High-confidence CoreML results skip cloud API, use free USDA FoodData Central
- **Provider abstraction:** Supports Gemini (default), OpenAI GPT-4o-mini, and Claude Haiku via env var
- **Gemini activated:** End-to-end tested — image → food identification → macros in ~1s
- **Graceful error handling:** Non-parseable vision responses return empty items instead of 502
- **iOS flow:** Camera → CoreML hints → cloud scan (if needed) → review/edit → log to food diary
- New files: `FoodClassificationService.swift`, `FoodScannerView.swift`, `FoodScanModels.swift`, `food_scan_service.py`
- Endpoint: `POST /api/v1/nutrition/food/scan`

### Dashboard Column Bug Fix
- Fixed `workout_sessions.date` → `started_at` (timestamptz range filter) in `_build_daily_actions`
- Fixed `food_entries.entry_date` → `logged_at` (timestamptz range filter) in `_get_nutrition_adherence` and `_build_daily_actions`
- Both columns were referenced by non-existent names causing PostgREST `42703` errors on the narrative dashboard

### Supabase Performance & Security Hardening
Single database migration addressing all Supabase advisor lint warnings:

| Category | Count | Fix |
|----------|-------|-----|
| RLS `auth.uid()` re-evaluation | 40 policies | Replaced `auth.uid()` with `(select auth.uid())` — prevents per-row function call overhead |
| Duplicate permissive policies | 2 | Dropped redundant SELECT on `daily_scores` (covered by ALL) and `recipes` (duplicate authenticated read) |
| Unindexed foreign keys | 7 | Added indexes on `exercise_progress.exercise_id`, `food_entries.user_id`, `invite_codes.created_by`, `personal_records.workout_set_id`, `user_training_plans.template_id`, `workout_sessions.plan_id`, `workouts.plan_id` |
| Mutable function search_path | 3 | Recreated `set_updated_at`, `handle_new_user`, `update_updated_at` with `SET search_path = ''` |

Post-migration advisor results: 0 WARN-level performance issues, 0 WARN-level security issues (except leaked password protection which requires dashboard toggle).

### Logo & App Icon Updates
- Asset catalog swap: light mode → dark logo variant, dark mode → bright logo variant
- In-app logo size: 240/280pt → 320pt (OnboardingView + AuthView)
- App icon glyph: scaled from 26% to 57% canvas width (Pillow LANCZOS)

### Security Hardening & Runtime Robustness

Full security and robustness pass across backend and iOS. 15 issues addressed across 5 batches (~25 files modified, 8 new files).

**Backend Security (Batch 1):**

| Fix | Details |
|-----|---------|
| CORS lockdown | `allow_origins` no longer defaults to `"*"` — empty in prod, localhost-only in debug; restricted to explicit methods/headers |
| Rate limiting | `slowapi` added; auth endpoints (signup/signin/refresh) capped at 5/min, all others at 60/min |
| Error sanitization | All 3 auth endpoints now return generic messages (`"Authentication failed. Please try again."`); real exception logged server-side |
| `social.py` f-string safety | Extracted PostgREST `.or_()` filter to named variables with explicit comment explaining why UUID-validated interpolation is safe |

**Backend Resilience (Batch 2):**

| Fix | Details |
|-----|---------|
| Retry utility | `utils/retry.py`: `retry_with_backoff` decorator + `call_with_retry()` — exponential backoff (1s/2s/4s), configurable attempts/exceptions |
| Circuit breaker | `utils/circuit_breaker.py`: closed → open (after N failures) → half-open (after cooldown); stops hammering failing services |
| External API resilience | Barcode lookup (Open Food Facts): 3 retries + circuit breaker (5 failures → 120s cooldown); JWKS fetch: 3 retries + circuit breaker (3 failures → 60s cooldown, falls back to cached keys) |
| Structured JSON logging | `logging_config.py`: every log line is JSON with `timestamp`, `level`, `logger`, `message`, `request_id` |
| Request ID middleware | `middleware/request_id.py`: generates/reads `X-Request-ID` header, stored in `contextvars.ContextVar`, echoed in response |
| Health check improvements | 5s timeout on DB probe, 3s on JWKS check, 10s result cache, per-check breakdown (`database` + `external_services`) |

**iOS Security (Batch 3):**

| Fix | Details |
|-----|---------|
| Force unwrap removal | TodayView streak calc (`calendar.date(...)!` × 2) and SleepView bed-time default (`!` × 2) replaced with `guard let` / `??` |
| URLSession timeout | Custom `URLSessionConfiguration`: 30s request timeout, 60s resource timeout, `waitsForConnectivity = true` — replaces all 7 `URLSession.shared` call sites |
| Certificate pinning | `PinningDelegate` using `CryptoKit.SHA256` for SPKI hash comparison. Ships with empty hash set (passthrough). Activate by adding hashes for Railway prod cert. Skipped for local dev builds. |

**iOS Robustness (Batch 4):**

| Fix | Details |
|-----|---------|
| Retry with backoff | `requestWithRetry<T>()` on APIService: retries on 5xx and `URLError.timedOut/.networkConnectionLost` with 1s/2s/4s backoff; 4xx/auth/offline throw immediately |
| Offline detection | `NetworkMonitor` (`NWPathMonitor`): `@Published isConnected`, `nonisolated var isCurrentlyConnected` for thread-safe API guard |
| Offline UI banner | Red "No Internet Connection" banner overlaid at top of `ContentView` when offline; animated in/out |
| `APIError.offline` | New case thrown at the top of `request<T>()` and `optionalRequest<T>()` before any network call |
| Background task registration | `ActiveWorkoutManager`: `beginBackgroundTask()` / `endBackgroundTask()` via `UIApplication`; called on `startWorkout()`, `clearWorkout()`, and scene phase changes |

**Backend Logging (Batch 5):**

Structured `logger.info/debug/error` added to all service and API files that lacked coverage:
- Services: `nutrition_service`, `exercise_service`, `sleep_service`, `prediction_service`, `progression_service`, `wellness_calculator`
- API routers: `workouts`, `metrics`, `sleep`, `training_plans`, `exercises`
- Pattern: `info` for mutations, `debug` for calculations, `error(exc_info=True)` in catch blocks. No passwords, tokens, or email addresses logged.

**New files:**

| File | Purpose |
|------|---------|
| `backend/app/rate_limit.py` | Shared slowapi `Limiter` instance |
| `backend/app/utils/retry.py` | Exponential backoff retry decorator + helper |
| `backend/app/utils/circuit_breaker.py` | Circuit breaker (closed/open/half-open) |
| `backend/app/middleware/request_id.py` | Request ID middleware + context var |
| `backend/app/logging_config.py` | JSON log formatter + `setup_logging()` |
| `ios/.../Services/NetworkMonitor.swift` | `NWPathMonitor`-based connectivity observer |

**New dependency:** `slowapi==0.1.9`

**Pending pre-production step — Shannon pentest:**
[Shannon](https://github.com/KeygraphHQ/shannon) (open-source AGPL-3.0, requires Anthropic API key) is an AI-powered autonomous white-box pentester. Run it against the local backend after deployment to validate that hardening holds up against real exploit attempts. Estimated cost: ~$5–20 in API credits per full scan. Command:
```bash
./shannon start URL=http://localhost:8000 REPO=/path/to/healthpulse-analytics
```
Results written to `audit-logs/`. Fix any high/critical findings before public launch.

### Phase 8C — Sports Science Overhaul

**Batch 1: Core Science & CRUD Fixes**

| # | Area | What Shipped |
|---|------|-------------|
| 1 | Nutrition Engine | Dual BMR (Mifflin-St Jeor + Katch-McArdle when body fat % known), calorie/macro cycling (training +10% kcal, rest day compensating), `GET /daily-targets` endpoint, protein floor 1.6 g/kg, goal-specific macro splits |
| 2 | Goal-Setting Guardrails | Timeline step in onboarding (step 5), safe rate validation (0.5-1% BW/week loss, 0.25-0.5% gain), calorie floors (1200F/1500M), color-coded safety indicators (green/yellow/orange/red), auto-recalc on profile change |
| 3 | Unified Workout History | `GET /workouts/unified` merging `workouts` + `workout_sessions`, planId threading fix in WorkoutTabView, unified history feed with source discriminator |
| 4 | Meal Editing & Deletion | `PUT /food/{entry_id}` endpoint, swipe-to-delete on food entries, tap-to-edit with pre-filled FoodLogView |

**Batch 2: Personalization & Content Expansion**

| # | Area | What Shipped |
|---|------|-------------|
| 5 | User Profiling | 2 new onboarding steps (dietary preferences: omnivore/vegetarian/vegan/pescatarian/keto + allergies multi-select; experience/motivation/body fat %), post-onboarding editing in ProfileView |
| 6 | Recipe & Meal Plan Alignment | Dietary preference filtering in recipe suggestions, per-meal calorie budgeting, macro comparison overlay in weekly plan macros, custom recipe CRUD (create/list/update/delete), 30 new seed recipes (vegan, keto, pescatarian, gluten-free, bulking) |
| 7 | Training Plan Expansion | 4 new templates (Time-Crunched Professional, Glute & Hypertrophy Focus, Longevity & Mobility Base, Athletic Performance), exercise swap UI with muscle-group-matched alternatives, experience-level auto-filtering, difficulty badges |

### App Icon & Landing Page Rebrand

| Change | Details |
|--------|---------|
| New app icon | Replaced homescreen icon with production waveform design (green pulse on dark background, 1024×1024, no alpha) |
| Video landing page | Auth screen background replaced with looping Sora-generated waveform video (`LoopingVideoBackground` using `AVQueuePlayer` + `AVPlayerLooper` via `layerClass` override) |
| Logo removed | Static `Image("AppLogo")` + bloom ring animation removed from auth screen; video provides full visual identity |
| Frosted glass form card | Auth form card uses `ultraThinMaterial` + dark overlay for readability over video; white-tinted input fields with bright borders |
| Tagline retained | "Track. Train. Transform." displayed below the form card |
| Simplified entrance animation | Removed logo fade/bloom/typewriter; form fields slide up with staggered spring animation (0.3s delay) |

**New files:**

| File | Purpose |
|------|---------|
| `ios/.../Views/Components/LoopingVideoBackground.swift` | `UIViewRepresentable` wrapping `AVQueuePlayer` for gapless looping video backgrounds |

---

## Roadmap

> Strategic pivot: HealthPulse is evolving from a passive data tracker into an **Actionable AI
> Companion** — a system that synthesizes every data stream into a daily causal story and surfaces
> empathetic, personalized guidance at exactly the right moment.

---

### Phase 11 — Visual Polish & Daily Causal Story Dashboard (COMPLETED)

#### 11A — Motion Polish
- **Centralized motion tokens:** `MotionTokens` enum (primary, snappy, micro, form, entrance, ring) replacing all inline spring values across the app
- **Custom tab bar:** Spring bounce animation via `.symbolEffect(.bounce)` on tab icons; glass-style background with `ultraThinMaterial`; selection haptics on every tab tap
- **Numeric text transitions:** `.contentTransition(.numericText())` on all stat counters (nutrition adherence %, sleep consistency %, recovery scores, key lift weights)

#### 11B — The Daily Causal Story Dashboard
- **Narrative dashboard endpoint:** `GET /predictions/dashboard/narrative` returns causal annotations, commitment slots, card priority order, readiness narrative, and greeting context as a superset of the existing dashboard response
- **Causal annotations:** Each metric shows its primary driver ("mainly because sleep was 5h 40m") with driver factor and impact percentage
- **"Now / Next / Tonight" commitment framework:** Three time-based action slots driven by readiness score and time of day:
  - **Now** — workout (high readiness), active recovery (low readiness), or nutrition fallback
  - **Next** — nutrition/prep focus based on what Now suggested
  - **Tonight** — always sleep/recovery focused, with sleep deficit awareness
- **Load modifier badges:** Visual "EASE OFF" (orange) / "PUSH IT" (green) indicators on workout commitment cards based on readiness thresholds
- **Readiness-driven card reordering:** Dashboard cards dynamically reorder based on physiological state — high readiness (≥70) surfaces training; moderate (40-69) surfaces recovery; low (<40) surfaces recovery + sleep
- **Readiness header:** Compact score ring (52pt) + greeting context label (e.g. "PUSH DAY" / "RECOVERY DAY") + narrative text explaining the score
- **Graceful fallback:** If narrative endpoint is unavailable, app seamlessly falls back to legacy `/dashboard` endpoint with static card order — no crashes, no blank screens
- **New backend methods:** `get_narrative_dashboard()` + 9 helpers (`_build_causal_annotations`, `_build_commitments`, `_compute_now/next/tonight_slot`, `_compute_card_priority`, `_get_greeting_context`, `_build_readiness_narrative`)
- **New iOS components:** `ReadinessHeaderView`, `CommitmentStripView`, `CommitmentCard`, `LoadModifierBadge`, `CausalRecoveryCard`, `DashboardCardRouter`
- **New iOS models:** `CausalAnnotation`, `CommitmentSlot`, `PrioritizedCard`, `NarrativeDashboardResponse`

### Phase 11C — Dashboard Overhaul, Profile Editing & Auth Hardening (COMPLETED)

#### Profile Editing & Account Management
- **EditProfileView:** Display name editing, avatar picker with 4 categories (Fitness, Animals, Power, Vibes — 30+ SF Symbols)
- **Account management:** Change email + change password flows via `backend/app/api/account.py` endpoints
- **Profile page upgrade:** NavigationLink to edit profile + data sources section

#### Dashboard Improvements
- **Training-plan-aware commitments:** NOW slot checks active training plan schedule for today's workout
- **Daily actions system:** Established users see real-time checklist (workout, meals, sleep) instead of static new-user checklist
- **Greeting standalone:** Personalized greeting moved to standalone position at top of dashboard
- **Tappable commitments:** CommitmentStripView cards route to relevant tabs with press animation
- **Filtered recommendations:** "For You" section filters by `actionRoute` to avoid duplication with commitment cards
- **Streak fix:** Rest-day tolerance — Mon/Wed/Fri training counts as 3-day streak (allows 1 rest day between sessions)
- **Reduced card redundancy:** Removed `streak`, `weekly`, and `adherence` card types from priority order
- **Stabilized loading:** Dashboard cards render consistently on refresh

#### Social Tab Avatars
- Partner cards and leaderboard entries display user's chosen SF Symbol avatar

#### Auth Flow Hardening
- `isRestoringSession` guard prevents flash of AuthView/OnboardingView on app launch
- Splash screen in ContentView during session restore
- Foreground resume token refresh via `willEnterForegroundNotification`
- `loadProfile()` no longer resets `isOnboardingComplete` on network failure
- `.preferredColorScheme(.dark)` on auth screen for text visibility over video
- `AVAudioSession.ambient` prevents login video from stopping background music

#### Nutrition Enhancements
- **Text-based food search:** Open Food Facts search via `GET /meal-plans/food-search?query=...` — debounced search bar in FoodLogView with result pre-fill
- **Recipe shopping list:** `GET /meal-plans/recipes/{id}/shopping-list?servings=N` — button in RecipeDetailSheet shows scaled ingredient list
- **Backend:** `search_food()` and `get_recipe_shopping_list()` methods in `meal_plan_service.py`

#### Workout Tab Improvements
- **Tappable recent workouts:** Unified workout rows now navigate to WorkoutDetailView on tap
- **PR celebration scroll:** PRCelebrationView uses ScrollView with fixed header/button, expandable `.medium`/`.large` detent

---

### Phase 12B — Metabolic Readiness Synthesis (Core)

**Milestone:** Make nutrition actionable by linking daily macro targets to recovery/readiness data, with a live deficit radar and one-tap recipe fix flow.

**Completed (Core):**
- **Recovery-adjusted targets:** `recovery_adjusted_targets()` in `nutrition_calculator.py` — protein/carb/calorie shifts based on readiness score, sleep deficit, 7-day training load, and yesterday's workout type
- **Readiness targets endpoint:** `GET /nutrition/readiness-targets` — combines cycling-aware base targets with recovery adjustments and live deficit status (urgency: on_track/behind/critical based on time of day)
- **Deficit-fix recipes endpoint:** `GET /meal-plans/suggestions/deficit-fix?deficit_kcal=X&deficit_protein_g=Y` — protein-dense recipes filtered by dietary preferences/allergies within calorie range
- **iOS models:** `ReadinessTargetsResponse`, `DailyTargetsDetail`, `AdjustmentReason`, `DeficitStatus` in Models.swift
- **iOS API:** `getReadinessTargets()` and `getDeficitFixRecipes()` in APIService.swift
- **DeficitRadarCard:** Dashboard card showing recovery-adjusted calorie/protein progress, adjustment badges, urgency indicator, and "Fix My Deficit" CTA button
- **DeficitFixView:** Sheet with recipe suggestions showing deficit coverage percentages per recipe
- **TodayView integration:** DeficitRadarCard replaces NutritionProgressCard when readiness data is available (graceful fallback to existing card on failure)

**Deferred to Phase 12C:**
- Post-workout synthesis window notification (30-min anabolic window alert)
- Scan intelligence upgrade (recovery context banner on AI scan review screen)
- NutritionView deficit radar integration (currently only in TodayView)

---

### Phase 13 — Experiment Tracks & Silent Correlation Feed

**Milestone:** Transform the existing correlation engine from a passive insight display into a
guided, empathetic system for personal n=1 experimentation — the scientific method made human.

#### 13A — Silent Correlation Feed
- **Passive surfacing:** Correlations appear as quiet, non-interruptive cards at the bottom of
  the Insights tab — no push notifications, no alerts, just observations waiting to be discovered
- **Empathetic language layer:** All correlations reframed from statistical statements to
  first-person narrative: "We noticed something interesting: on weeks when you sleep more than
  7h 30m, your squat tends to be about 4% heavier. Curious?"
- **Confidence gating:** Correlations only surface after minimum data thresholds (≥21 data
  points, r ≥ 0.35) — prevents noise and false pattern recognition
- **Tap-to-experiment:** Every correlation card has a single CTA — "Turn this into an
  experiment" — connecting directly to the Experiment Tracks system

#### 13B — Experiment Tracks
- **Hypothesis builder:** Guided 3-step flow: pick a variable to change (sleep target, protein
  intake, rest days per week) → pick a metric to watch (readiness, squat performance, mood) →
  set duration (2, 4, or 6 weeks)
- **Pre-built experiment library:** Curated hypotheses based on common health patterns:
  - "Does 8h sleep improve my strength output?" (sleep vs. key lift weight)
  - "Does daily protein ≥ 150g correlate with faster recovery?" (nutrition vs. recovery score)
  - "Is my Monday fatigue from weekend habits?" (weekend behavior vs. Monday readiness)
- **Silent tracking:** Once an experiment is active, the app collects data without prompting the
  user — no check-ins, no reminders to "stay on track"
- **Results presentation:** At experiment end, results are shown as a simple visual comparison
  (before/after period), not a statistical report. Confidence level in plain English:
  "The data suggests this connection is real — but you'd need 4 more weeks to be certain."
- **Backend:** `experiment_service.py` with hypothesis tracking, data window isolation, and
  correlation delta calculation; new `experiments` table in Supabase
- **iOS:** `ExperimentTracksView` embedded in `InsightsView`; experiment progress indicator on
  dashboard; results celebration screen with before/after chart

---

### Phase 14 — Burnout Horizon & What-If Sandbox

**Milestone:** Make HealthPulse predictive, not just reactive — show users the consequences of
their current trajectory and let them simulate the impact of behavioral changes before committing.

#### 14A — Burnout Horizon
- **Readiness forecast curve:** 14-day projected readiness score based on current training load,
  sleep trend, and nutrition adherence — visualized as a continuous line chart with a confidence
  band (not point predictions)
- **Burnout risk indicator:** When forecast shows readiness dipping below 50% for 3+ consecutive
  days, a "Burnout Horizon" warning surfaces: "At your current pace, your readiness is projected
  to reach 42% by March 4th. Here's why."
- **Causal breakdown:** Horizon warning always shows the 2–3 primary drivers pulling readiness
  down (training load, sleep debt, nutrition deficit) with their individual projected contribution
- **Protected Recovery Days:** System recommends inserting a strategic rest day before the
  horizon — "Adding a recovery day on Wednesday could raise your Friday readiness from 44% to 67%"
- **Training plan integration:** If the forecast conflicts with a planned heavy training day,
  proactively surface a load modification suggestion in the workout card

#### 14B — What-If Sandbox
- **Behavior simulation:** Interactive sliders in a dedicated "Sandbox" view let users adjust
  hypothetical inputs for the next 7 days: sleep target (+/- 1h increments), training sessions
  (add/remove), calorie surplus/deficit, rest days — and instantly see the projected readiness
  curve update
- **Scenario comparison:** Save up to 3 named scenarios ("Current pace", "More sleep", "Deload
  week") and view them as overlapping curves on a single chart
- **Decision support, not prescription:** The sandbox is explicitly framed as exploration —
  "This is a simulation based on your patterns. Real results will vary."
- **Backend:** New `forecast_service.py` using XGBoost regression on rolling 30-day window;
  `/predictions/burnout-horizon` and `/predictions/whatif` endpoints; sandbox scenarios stored
  in-session only (no persistence required)
- **iOS:** `BurnoutHorizonView` as a section in `TrendsView`; `WhatIfSandboxView` as a sheet;
  forecast curve integrated into `TodayView` for users with ≥ 30 days of data

---

### Phase 15 — Android App

**Milestone:** Expand to Android after the iOS UX has been refined and the Actionable AI core
(Phases 11–14) is proven in production.

- Kotlin / Jetpack Compose native app
- Feature parity: auth, Daily Causal Story dashboard, workouts, nutrition, sleep, training plans,
  Metabolic Readiness Synthesis, Experiment Tracks, Burnout Horizon
- Shared backend — all API endpoints are already platform-agnostic
- Health Connect integration (Android equivalent of HealthKit)
- Google Calendar integration (Android equivalent of EventKit)
- Material Design 3 / Material You theming aligned with the Emerald Night palette
- Google Play Store distribution

---

## Future Ideas

> Filtered for the **Actionable AI Companion** philosophy: features retained must either surface
> a meaningful action, deepen personalization, or reduce friction in a healthy behavior.
> Passive tracking for its own sake, social vanity features, and one-time utilities have been
> removed.

### Intelligence & Coaching

| Feature | Description | Complexity |
|---------|-------------|------------|
| **Conversational AI Coach** | In-app chat assistant grounded in the user's own data — "How's my recovery?", "What should I eat before my workout?", "Am I overtraining?" Answers use real metrics, not generic advice. | High |
| **Smart Deload Detection** | Detect fatigue accumulation across mesocycles from training load + recovery trends; suggest a programmed deload week before performance declines. Feeds directly into Burnout Horizon. | Medium |
| **Supplement Impact Tracking** | Log supplements (creatine, magnesium, ashwagandha, caffeine) and silently correlate with recovery score and sleep quality over time. Surfaces findings via the Correlation Feed. | Medium |
| **Injury-Aware Plan Modification** | Log an injury with affected muscle groups; training plan automatically substitutes exercises that avoid those muscles for the logged recovery period. | Medium |

### Nutrition Intelligence

| Feature | Description | Complexity |
|---------|-------------|------------|
| **Hydration Recovery Optimization** | Track daily water intake; correlate hydration with HRV and sleep quality via Correlation Feed; surface recovery-adjusted hydration targets alongside macro targets in Metabolic Readiness. | Low |
| **Contextual Meal Timing** | Surface meal timing suggestions based on workout schedule and circadian data — "Eat your largest carb meal within 2h of your 6 PM workout for optimal glycogen replenishment." | Medium |

### Training Intelligence

| Feature | Description | Complexity |
|---------|-------------|------------|
| **1RM Calculator & %-based Programming** | Estimate 1RM from logged sets using Epley/Brzycki formula; auto-calculate daily working weights as a % of estimated 1RM. Feeds progressive overload system. | Medium |
| **Periodization Engine** | Multi-week mesocycle planning with auto-progression phases (accumulation → intensification → deload). Works in concert with Burnout Horizon predictions. | High |
| **Heart Rate Zone Training** | Real-time cardio zone overlay during runs using HealthKit HR data; zone-based pacing coach; post-run zone distribution summary. | Medium |
| **AI Form Check** | ML-based exercise form analysis via device camera during live workouts. Actionable cue delivery ("Knees are caving — push them out"). | High |
| **Warmup/Cooldown Generator** | AI-generated stretching and mobility sequences based on today's targeted muscle groups and yesterday's soreness signals. | Medium |

### Social & Behavioral

| Feature | Description | Complexity |
|---------|-------------|------------|
| **Time-bound Challenges** | Structured partner challenges with defined metrics and duration ("30-day consistency", "Squat PR race"). Ties into existing partnership system. | Medium |
| **Achievements & Milestones** | Meaningful, non-gamified milestone recognition — streak badges, PR milestones, nutrition consistency awards. Tied to real behavioral change, not engagement loops. | Medium |
| **Siri Shortcuts** | Voice-activated actions: "Hey Siri, start my chest workout" / "Log 200g chicken breast" / "What's my readiness today?" | Medium |

### Platform Expansion

| Feature | Description | Complexity |
|---------|-------------|------------|
| **Apple Watch App** | Surfaces "Now / Next / Tonight" commitments on wrist; quick set logging during workouts; real-time readiness score; rest timer; synthesis window notification. Highest-impact platform addition. | High |
| **Home Screen Widgets** | WidgetKit: Daily Causal Story summary (readiness + one key action); calorie deficit/surplus ring; active experiment progress; workout streak. | Medium |
| **iPad Layout** | Multi-column dashboard (causal story left / commitment actions right); side-by-side workout logging; expanded What-If Sandbox with larger chart canvas. | Medium |
| **Strava Sync** | Bi-directional: import Strava runs into workout history; export HealthPulse sessions to Strava. Enriches training load data for Burnout Horizon forecasting. | Medium |

---

> **Deliberately removed from Future Ideas:**
> - ~~Workout Sharing Cards~~ — social vanity, not aligned with AI Companion philosophy
> - ~~Activity Feed~~ — passive social consumption, increases noise without action
> - ~~Apple Music integration~~ — entertainment feature, not health-actionable
> - ~~MyFitnessPal Import~~ — one-time migration utility, not a product feature
> - ~~Custom Exercise Builder~~ — pure CRUD, no AI or actionable angle
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
│   │   │   ├── wellness_calculator.py, meal_plan_service.py, data_generator.py
│   │   └── models/              # Pydantic models + DB config
│   ├── requirements.txt
│   ├── Procfile, railway.json
│   └── tests/
├── ios/
│   └── HealthPulse/HealthPulse/HealthPulse/
│       ├── HealthPulseApp.swift  # App entry point
│       ├── Views/               # All SwiftUI views (24 files)
│       ├── Services/            # API, Auth, HealthKit, Keychain, etc.
│       ├── Models/              # Codable models
│       └── Info.plist           # Permissions + capabilities
├── docs/
│   ├── database-schema.sql
│   ├── migration-exercises.sql
│   ├── migration-social.sql
│   ├── migration-meal-plans.sql
│   ├── migration-weekly-meal-plans.sql
│   ├── seed-plan-templates.sql
│   └── privacy-policy.md
└── PROJECT_STATUS.md            # This file
```
