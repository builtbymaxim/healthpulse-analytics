# HealthPulse Analytics — Project Status

> Last updated: 2026-02-13

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
- Baseline settings: HRV baseline, resting HR baseline, target sleep, step goal
- Unit preferences (metric/imperial)

### Dashboard (TodayView)
- Welcome checklist for new users
- Today's planned workout card
- Nutrition progress (calorie ring + macro bars)
- Smart recommendations (personalized based on data)
- Weekly summary (workouts, sleep, nutrition adherence)
- Enhanced recovery card with contributing factors
- Progress section (key lifts, PRs, muscle balance)
- Workout streak + last workout
- Nutrition adherence chart (7-day)
- Quick stats (steps, sleep, resting HR)
- Readiness score

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
- 6 plan templates (Full Body, Upper/Lower, PPL, Home Bodyweight, C25K, Hybrid)
- Plan setup wizard: goal → modality → equipment → schedule
- Weekly schedule view with workout cards
- Plan editing (swap exercises, change days) with calendar conflict indicators
- Deactivate plan with confirmation
- Today's workout card linking to execution
- Calendar sync: auto-create events in dedicated HealthPulse calendar (4 weeks rolling)
- Plan activation sheet: time picker + conflict checking before activating

### Nutrition
- Daily calorie and macro tracking
- Food logging with meal type (breakfast/lunch/dinner/snack)
- Animated calorie progress ring and macro progress bars
- Nutrition goal calculation based on profile (BMR/TDEE)
- Custom calorie target override
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
| `predictions.py` | `/api/v1/predictions` | GET `/dashboard`, `/recovery`, `/readiness` |
| `training_plans.py` | `/api/v1/training-plans` | GET `/templates`, `/today`; POST `/activate`, `/suggestions`; PUT `/{id}` |
| `social.py` | `/api/v1/social` | POST/GET `/invite-codes`; GET `/partners`, `/leaderboard/{category}`; PUT `/partners/{id}/accept` |
| `meal_plans.py` | `/api/v1/meal-plans` | GET `/recipes`, `/templates`, `/suggestions`, `/barcode/{code}`; POST `/quick-add`; CRUD `/weekly-plans` (13 endpoints) |
| `health.py` | `/` | GET `/health`, `/ready` |

### Backend Services

| Service | Purpose |
|---------|---------|
| `dashboard_service.py` | Composite dashboard data aggregation |
| `prediction_service.py` | ML predictions (recovery, readiness, trends) |
| `nutrition_calculator.py` | BMR/TDEE + macro target calculations |
| `nutrition_service.py` | Food entry CRUD + daily summaries |
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
| `OnboardingView` | Profile setup wizard (12 steps incl. name) |
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
| `SocialView` | Social tab (partners, invites, leaderboards) |
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

### Lower-Priority (not yet scheduled)

- `CLLocationManager` should be created on main thread
- Health readiness check hardcodes `"database": "ok"` instead of verifying
- Various minor UX polish items from audit

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
- Social tab (6th tab): conditional display — only visible when user opts in
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
- Recipe library: ~35 pre-seeded recipes with ingredients, instructions, macros per serving
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

---

## Roadmap

### Phase 11 — Android App
- Kotlin Multiplatform or native Jetpack Compose app
- Feature parity with iOS: auth, dashboard, workouts, nutrition, sleep, training plans, meal plans, social
- Shared backend — all API endpoints already platform-agnostic
- Health Connect integration (Android equivalent of HealthKit)
- Google Calendar integration (Android equivalent of EventKit)
- Material Design 3 / Material You theming
- Google Play Store distribution

### Phase 12 (Optional) — Body Composition
- Body measurement tracking (chest, waist, hips, arms, legs)
- Progress photo capture with date overlay
- Before/after comparison view
- Body fat estimation from measurements (Navy method)

---

## Future Ideas

| Feature | Description | Complexity |
|---------|-------------|------------|
| **Home Screen Widgets** | WidgetKit widgets for daily stats, workout reminder, nutrition progress | Medium |
| **Apple Watch** | WatchOS companion for workout tracking and quick stats | High |
| **Strava Integration** | Import/export workouts with Strava API | Medium |
| **Data Export** | Export health data as CSV/PDF reports | Low |

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
