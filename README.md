# HealthPulse

**AI-Powered Fitness & Health Intelligence Platform**

[![Python](https://img.shields.io/badge/python-3.9%2B-blue.svg)](https://www.python.org/downloads/)
[![FastAPI](https://img.shields.io/badge/fastapi-0.109-green.svg)](https://fastapi.tiangolo.com/)
[![SwiftUI](https://img.shields.io/badge/swiftui-iOS%2017%2B-orange.svg)](https://developer.apple.com/xcode/swiftui/)
[![Streamlit](https://img.shields.io/badge/streamlit-1.28-red.svg)](https://streamlit.io/)

A comprehensive fitness tracking ecosystem featuring an iOS app with HealthKit integration, AI-powered predictions, and an analytics web dashboard.

## Features

- **Multi-Platform**: iOS app + Web dashboard + Backend API
- **HealthKit Integration**: Sync steps, workouts, sleep, heart rate, HRV
- **Wellness Scoring**: Daily wellness score (0-100) from multiple metrics
- **Recovery Prediction**: ML-powered recovery and readiness predictions
- **Correlation Discovery**: Find what actually impacts your fitness
- **Manual Logging**: Track mood, energy, soreness, nutrition
- **Rich Analytics**: Trends, insights, and personalized recommendations

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   HealthPulse Ecosystem                 │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   ┌─────────────┐         ┌─────────────────────────┐  │
│   │   iOS App   │ ◄─────► │     Backend API         │  │
│   │  (SwiftUI)  │         │  (FastAPI + ML Models)  │  │
│   └──────┬──────┘         └───────────┬─────────────┘  │
│          │                            │                │
│          ▼                            ▼                │
│   ┌─────────────┐         ┌─────────────────────────┐  │
│   │ Apple Health│         │    Web Dashboard        │  │
│   │  HealthKit  │         │     (Streamlit)         │  │
│   └─────────────┘         └───────────┬─────────────┘  │
│                                       │                │
│                                       ▼                │
│                           ┌─────────────────────────┐  │
│                           │   Database (Supabase)   │  │
│                           │   Postgres + Auth       │  │
│                           └─────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Project Structure

```
healthpulse-analytics/
├── backend/                    # FastAPI Backend
│   ├── app/
│   │   ├── api/               # API endpoints
│   │   │   ├── health.py      # Health checks
│   │   │   ├── users.py       # User management
│   │   │   ├── metrics.py     # Health metrics CRUD
│   │   │   ├── workouts.py    # Workout tracking
│   │   │   └── predictions.py # ML predictions
│   │   ├── models/            # Data models
│   │   ├── services/          # Business logic
│   │   └── ml/                # ML models
│   ├── tests/
│   └── requirements.txt
│
├── web/                        # Streamlit Dashboard
│   ├── app/
│   │   └── healthpulse_app.py
│   └── requirements.txt
│
├── ios/                        # iOS SwiftUI App
│   ├── HealthPulse/
│   └── README.md              # iOS setup instructions
│
├── shared/                     # Shared Assets
│   └── assets/
│       └── healthpulse_logo.png
│
├── docs/                       # Documentation
│   └── database-schema.sql    # Supabase schema
│
└── README.md
```

## Quick Start

### Prerequisites
- Python 3.9+
- Node.js 18+ (optional, for future React migration)
- Xcode 15+ (for iOS development)
- Supabase account (free tier works)

### 1. Backend Setup

```bash
cd backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

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
3. Run the schema from `docs/database-schema.sql`
4. Copy your project URL and keys to backend `.env`

### 3. Web Dashboard

```bash
cd web

# Install dependencies
pip install -r requirements.txt

# Run the dashboard
streamlit run app/healthpulse_app.py
```

Dashboard available at: http://localhost:8501

### 4. iOS App

See [ios/README.md](ios/README.md) for detailed setup instructions.

## Tech Stack

| Component | Technology |
|-----------|------------|
| **iOS App** | SwiftUI, HealthKit, Supabase Swift SDK |
| **Backend** | FastAPI, Python 3.9+, XGBoost, scikit-learn |
| **Database** | Supabase (PostgreSQL), Row Level Security |
| **Web Dashboard** | Streamlit, Plotly, Pandas |
| **Auth** | Supabase Auth (supports Apple Sign-In) |

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/api/v1/users/me` | GET | Get current user profile |
| `/api/v1/metrics` | GET/POST | Health metrics CRUD |
| `/api/v1/metrics/daily` | GET | Daily metric summaries |
| `/api/v1/workouts` | GET/POST | Workout tracking |
| `/api/v1/predictions/recovery` | GET | Recovery score prediction |
| `/api/v1/predictions/readiness` | GET | Training readiness |
| `/api/v1/predictions/wellness` | GET | Wellness score breakdown |
| `/api/v1/predictions/insights` | GET | AI-generated insights |

## Tracked Metrics

### From HealthKit (iOS)
- Steps, Active Calories, Distance
- Heart Rate, Resting HR, HRV
- Sleep Duration, Sleep Stages
- Workouts (all types)
- Weight, Body Fat %

### Manual Entry
- Energy Level (1-10)
- Mood (1-10)
- Stress (1-10)
- Soreness (1-10)
- Nutrition (calories, protein, carbs, fat, water)

## ML Models

### Wellness Score
Combines activity, sleep, recovery, and mental wellness into a 0-100 score.

### Recovery Prediction
Predicts recovery status based on HRV, resting HR, sleep, and soreness.

### Readiness Score
Recommends training intensity based on recovery and recent training load.

### Correlation Discovery
Finds patterns in your data (e.g., "sleep improves 23% after evening workouts").

## Development Roadmap

- [x] Phase 1: Project restructure for multi-platform
- [x] Phase 1: Database schema design
- [x] Phase 1: FastAPI backend structure
- [ ] Phase 2: Implement Supabase integration
- [ ] Phase 2: Complete API endpoints
- [ ] Phase 2: Refresh web dashboard
- [ ] Phase 3: iOS app - Auth & basic UI
- [ ] Phase 3: iOS app - Manual logging
- [ ] Phase 4: iOS app - HealthKit integration
- [ ] Phase 5: ML predictions & insights
- [ ] Phase 6: Polish & App Store

## Testing

```bash
# Backend tests
cd backend
pytest tests/ -v

# With coverage
pytest tests/ --cov=app --cov-report=html
```

## Privacy & Security

- **Row Level Security**: Users can only access their own data
- **Local Processing**: ML runs on backend, not third-party services
- **HealthKit Privacy**: Data stays on device unless user syncs
- **No Tracking**: No analytics or data collection beyond functionality

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License.

## Acknowledgments

- **Supabase**: Backend as a Service
- **FastAPI**: Modern Python API framework
- **Apple HealthKit**: Health data integration
- **XGBoost**: Machine learning predictions
- **Streamlit**: Rapid dashboard development

---

**HealthPulse** - Your AI-powered fitness companion.
