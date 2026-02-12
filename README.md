# HealthPulse

**AI-Powered Fitness & Health Intelligence Platform**

[![Python](https://img.shields.io/badge/python-3.11%2B-blue.svg)](https://www.python.org/downloads/)
[![FastAPI](https://img.shields.io/badge/fastapi-0.109-green.svg)](https://fastapi.tiangolo.com/)
[![SwiftUI](https://img.shields.io/badge/swiftui-iOS%2017%2B-orange.svg)](https://developer.apple.com/xcode/swiftui/)
[![Supabase](https://img.shields.io/badge/supabase-PostgreSQL-3ecf8e.svg)](https://supabase.com/)

A personal fitness and wellness companion combining an iOS app (SwiftUI) with a Python backend (FastAPI) and Supabase (PostgreSQL). Features health tracking, nutrition management, workout logging, training plans, sleep analysis, and ML-powered predictions.

## Features

### Health & Wellness
- **HealthKit Integration** — sync steps, heart rate, HRV, resting HR, active calories, sleep
- **Wellness Score** — daily 0-100 composite score from sleep, activity, recovery, nutrition, stress, and mood
- **Recovery Prediction** — ML-powered recovery status with contributing factors and recommendations
- **Training Readiness** — recommended workout intensity based on recovery, sleep, energy, and soreness
- **Correlation Discovery** — Pearson correlation analysis across 30 days of health metrics

### Workouts
- **Strength Training** — set-by-set logging with weight, reps, RPE tracking
- **Running** — GPS-tracked with live pace, background execution, Live Activities on lock screen + Dynamic Island
- **Progressive Overload** — auto-suggested weights based on recent session history (+2.5kg upper / +5kg lower body)
- **Personal Records** — automatic PR detection and celebration across 1RM, 3RM, 5RM, and max volume
- **Rest Timer** — between-set timer with haptic feedback

### Training Plans
- **6 Templates** — Full Body Strength, Upper/Lower, PPL, Home Bodyweight, Couch to 5K, Hybrid
- **Plan Setup Wizard** — goal, modality, equipment, schedule selection with smart plan suggestion
- **Calendar Sync** — auto-create events in a dedicated HealthPulse calendar via EventKit (4 weeks rolling)
- **Conflict Checking** — shows overlapping calendar events when scheduling workouts
- **Plan Editing** — swap exercises, change training days, edit schedule

### Nutrition
- **Daily Tracking** — calories and macros (protein, carbs, fat) with meal-type grouping
- **Goal Calculation** — BMR/TDEE via Mifflin-St Jeor with custom override
- **Progress Visualization** — animated calorie ring and macro progress bars

### Sleep
- **Sleep Logging** — bed time, wake time, quality rating, optional sleep stages
- **Analytics** — 30-day averages, sleep debt, consistency scoring, trend detection
- **Stages Visualization** — deep, REM, light sleep with horizontal bar charts

### Smart Dashboard
- **Composite Dashboard** — single API call for recovery, readiness, progress, recommendations, weekly summary
- **Smart Recommendations** — personalized cards based on recovery, training load, sleep, and nutrition data
- **Progress Tracking** — key lift progress, recent PRs, muscle balance grid

### Notifications & Calendar
- **Meal Reminders** — adjustable times for breakfast, lunch, dinner
- **Workout Reminders** — morning notification on training days
- **Weekly/Monthly Reviews** — scheduled summary notifications
- **EventKit Calendar** — dedicated HealthPulse calendar with workout events, durations, and exercise lists

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                  HealthPulse Ecosystem                │
├──────────────────────────────────────────────────────┤
│                                                      │
│   ┌─────────────┐          ┌──────────────────────┐  │
│   │   iOS App   │  HTTPS   │    Backend API       │  │
│   │  (SwiftUI)  │ ◄──────► │  (FastAPI + ML)      │  │
│   └──────┬──────┘          └──────────┬───────────┘  │
│          │                            │              │
│          ▼                            ▼              │
│   ┌─────────────┐          ┌──────────────────────┐  │
│   │ Apple Health │          │   Supabase           │  │
│   │  HealthKit   │          │   PostgreSQL + Auth  │  │
│   └─────────────┘          └──────────────────────┘  │
│          │                                           │
│          ▼                  Deployed on Railway       │
│   ┌─────────────┐          (auto-deploy on push)     │
│   │  EventKit   │                                    │
│   │  Calendar   │                                    │
│   └─────────────┘                                    │
└──────────────────────────────────────────────────────┘
```

## Tech Stack

| Layer | Technology |
|-------|------------|
| **iOS App** | Swift / SwiftUI, HealthKit, EventKit, ActivityKit (Live Activities), Keychain |
| **Backend API** | Python 3.11, FastAPI, Pydantic v2, Uvicorn |
| **Database** | Supabase (PostgreSQL with RLS + Auth) |
| **ML / Analytics** | scikit-learn, XGBoost, NumPy, Pandas |
| **Deployment** | Railway (auto-deploy on push to main) |

## ML & Intelligence

HealthPulse uses a weighted scoring system combined with statistical analysis to power its predictions. All inference runs server-side on each API request.

### Recovery Score
Weighted model combining six inputs into a 0-100 score:

| Factor | Weight |
|--------|--------|
| Sleep duration | 25% |
| Sleep quality | 20% |
| HRV (vs user baseline) | 20% |
| Resting HR (vs baseline) | 15% |
| 7-day training load | 10% |
| Stress level | 10% |

Outputs: score, confidence, status (recovered / moderate / fatigued), contributing factors, personalized recommendations.

### Training Readiness
Determines recommended workout intensity from recovery and daily metrics:

| Factor | Weight |
|--------|--------|
| Recovery score | 35% |
| Sleep quality | 20% |
| Days since hard workout | 15% |
| Energy level | 15% |
| Muscle soreness | 15% |

Outputs: score 0-100, intensity recommendation (rest / light / moderate / hard), suggested workout types.

### Wellness Score
Daily composite health score from six component areas:

| Component | Weight |
|-----------|--------|
| Sleep | 25% |
| Activity (steps + calories) | 20% |
| Recovery (HRV, resting HR) | 20% |
| Nutrition adherence | 15% |
| Stress | 10% |
| Mood | 10% |

Includes trend detection (improving / stable / declining) by comparing recent 3-day average to historical average.

### Correlation Analysis
Pearson correlation (NumPy) across 30 days of health metrics. Discovers relationships like sleep-recovery, stress-HRV, and exercise-mood. Reports correlations with |r| > 0.3 and minimum 5 data points.

### Smart Recommendations
Rule engine on the dashboard endpoint generates personalized cards:
- Recovery < 60 → rest day recommendation
- Sleep deficit > 1h → sleep recovery suggestion
- Muscle imbalance detected → targeted workout recommendation
- Nutrition adherence < 60% → tracking nudge
- Volume trend drops > 20% → training consistency alert

### Progressive Overload
Algorithmic weight suggestions based on recent workout session history:
- **Increase**: +2.5kg (upper body) / +5kg (lower body) when RPE ≤ 8
- **Maintain**: same weight when RPE 9-10
- **Deload**: -10% after 2+ stagnant sessions with high RPE

> **Note**: The current system uses rule-based weighted scoring rather than trained neural networks. scikit-learn and XGBoost are available in dependencies for future data-driven model upgrades as user data volume grows.

## Project Structure

```
healthpulse-analytics/
├── backend/
│   ├── app/
│   │   ├── main.py                # FastAPI app + router registration
│   │   ├── auth.py                # JWT verification (ES256 JWKS + HS256)
│   │   ├── config.py              # Settings (env vars)
│   │   ├── api/                   # Route handlers
│   │   │   ├── auth.py            # Login, register, refresh
│   │   │   ├── users.py           # Profile, settings, weight
│   │   │   ├── metrics.py         # Health metrics CRUD
│   │   │   ├── workouts.py        # Workout tracking
│   │   │   ├── exercises.py       # Exercise library + analytics
│   │   │   ├── nutrition.py       # Food logging + summaries
│   │   │   ├── sleep.py           # Sleep tracking + analytics
│   │   │   ├── predictions.py     # ML predictions + insights
│   │   │   ├── training_plans.py  # Plans, sessions, suggestions
│   │   │   └── health.py          # Health checks
│   │   ├── services/              # Business logic
│   │   │   ├── dashboard_service.py
│   │   │   ├── prediction_service.py
│   │   │   ├── progression_service.py
│   │   │   ├── nutrition_service.py
│   │   │   ├── nutrition_calculator.py
│   │   │   ├── exercise_service.py
│   │   │   ├── sleep_service.py
│   │   │   └── wellness_calculator.py
│   │   ├── models/                # Pydantic models
│   │   └── ml/                    # ML scoring models
│   ├── tests/
│   ├── requirements.txt
│   ├── Procfile
│   └── railway.json
│
├── ios/
│   └── HealthPulse/HealthPulse/HealthPulse/
│       ├── HealthPulseApp.swift    # App entry point
│       ├── Views/                  # SwiftUI views (18+ files)
│       ├── Services/               # API, Auth, HealthKit, Calendar, etc.
│       ├── Models/                 # Codable models
│       └── Info.plist              # Permissions + capabilities
│
├── docs/
│   ├── database-schema.sql         # Full Supabase schema
│   ├── migration-exercises.sql     # Exercise + strength tables
│   └── seed-plan-templates.sql     # Training plan templates
│
├── PROJECT_STATUS.md               # Detailed project status
└── README.md
```

## Quick Start

### Prerequisites
- Python 3.11+
- Xcode 26+ (for iOS development)
- Supabase account (free tier works)

### 1. Backend Setup

```bash
cd backend

# Create virtual environment
python -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Copy environment template
cp .env.example .env
# Edit .env with your Supabase credentials

# Run the API
uvicorn app.main:app --reload --port 8000
```

API docs available at: http://localhost:8000/docs

### 2. Database Setup (Supabase)

1. Create a new project at [supabase.com](https://supabase.com)
2. Go to SQL Editor
3. Run `docs/database-schema.sql` for the base schema
4. Run `docs/migration-exercises.sql` for exercise + strength tables
5. Run `docs/seed-plan-templates.sql` for training plan templates
6. Copy your project URL and keys to backend `.env`

### 3. iOS App

1. Open `ios/HealthPulse/HealthPulse.xcodeproj` in Xcode
2. Update the API base URL in `Services/APIService.swift`
3. Build and run on a device (HealthKit requires a physical device)

## API Endpoints

| Router | Prefix | Key Endpoints |
|--------|--------|---------------|
| `auth.py` | `/api/v1/auth` | POST `/login`, `/register`, `/refresh` |
| `users.py` | `/api/v1/users` | GET/PUT `/me`, `/me/settings`, `/me/weight` |
| `metrics.py` | `/api/v1/metrics` | POST `/`, `/batch`; GET `/` |
| `workouts.py` | `/api/v1/workouts` | POST/GET/DELETE `/`; GET `/sets` |
| `exercises.py` | `/api/v1/exercises` | GET `/`, `/analytics/volume`, `/analytics/muscle-groups`; POST `/sets` |
| `nutrition.py` | `/api/v1/nutrition` | POST/GET `/food`, `/goal`; GET `/summary`, `/summary/weekly` |
| `sleep.py` | `/api/v1/sleep` | POST/GET `/`; GET `/summary`, `/history`, `/analytics` |
| `predictions.py` | `/api/v1/predictions` | GET `/dashboard`, `/recovery`, `/readiness`, `/wellness`, `/correlations`, `/insights` |
| `training_plans.py` | `/api/v1/training-plans` | GET `/templates`, `/today`; POST `/activate`, `/suggestions`, `/sessions`; PUT `/{id}` |
| `health.py` | `/` | GET `/health`, `/ready` |

## Privacy & Security

- **Row Level Security** — users can only access their own data (Supabase RLS on all tables)
- **JWT Verification** — ES256 via Supabase JWKS with HS256 fallback
- **Keychain Storage** — auth tokens stored in iOS Keychain (not UserDefaults)
- **Server-Side ML** — all predictions run on the backend, no third-party ML services
- **HealthKit Privacy** — health data stays on device unless user explicitly syncs
- **No Tracking** — no analytics SDKs or data collection beyond app functionality

## Testing

```bash
cd backend
pytest tests/ -v

# With coverage
pytest tests/ --cov=app --cov-report=html
```

## Roadmap

- **Phase 8 — Body Composition**: measurement tracking, progress photos, before/after comparison, body fat estimation
- **Phase 9 — App Distribution**: TestFlight, GDPR compliance, privacy policy
- **Phase 10 — Meal Plans**: pre-built meal templates, macro-balanced recipe suggestions
- **Phase 11 — Social Features**: friends system, workout sharing, challenges, leaderboards

## License

This project is licensed under the MIT License.

---

**HealthPulse** — Your AI-powered fitness companion.
