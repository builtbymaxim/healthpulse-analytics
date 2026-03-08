"""HealthPulse API - Main FastAPI application."""

import logging
import sys
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.config import get_settings
from app.logging_config import setup_logging
from app.rate_limit import limiter
from app.middleware.request_id import RequestIdMiddleware
from app.api import account, auth, health, metrics, nutrition, predictions, users, workouts, exercises, sleep, training_plans, social, meal_plans

settings = get_settings()
setup_logging(debug=settings.debug)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(_app: FastAPI):
    """Validate required secrets on startup; crash fast if missing."""
    missing = [
        name for name, value in [
            ("SUPABASE_SERVICE_KEY", settings.supabase_service_key),
            ("JWT_SECRET", settings.jwt_secret),
        ]
        if not value
    ]
    if missing:
        logger.critical("Missing required environment variables: %s", ", ".join(missing))
        sys.exit(1)
    logger.info("Startup checks passed.")
    yield


app = FastAPI(
    title=settings.app_name,
    version=settings.api_version,
    description="AI-powered fitness and health analytics API",
    docs_url="/docs",
    redoc_url="/redoc",
    redirect_slashes=False,  # Prevent 307 redirects that lose auth headers
    lifespan=lifespan,
)

# Rate limiting
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Request ID middleware — must be added before other middleware so the ID is
# available throughout the full request lifecycle (including logging).
app.add_middleware(RequestIdMiddleware)

# CORS middleware — only enabled when origins are explicitly configured.
# iOS native clients don't send Origin headers, so this only affects web clients.
if settings.cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "Accept"],
    )


# Include routers
app.include_router(health.router, tags=["Health"])
app.include_router(auth.router, prefix="/api/v1/auth", tags=["Authentication"])
app.include_router(users.router, prefix="/api/v1/users", tags=["Users"])
app.include_router(metrics.router, prefix="/api/v1/metrics", tags=["Metrics"])
app.include_router(workouts.router, prefix="/api/v1/workouts", tags=["Workouts"])
app.include_router(predictions.router, prefix="/api/v1/predictions", tags=["Predictions"])
app.include_router(nutrition.router, prefix="/api/v1/nutrition", tags=["Nutrition"])
app.include_router(exercises.router, prefix="/api/v1/exercises", tags=["Exercises"])
app.include_router(sleep.router, prefix="/api/v1/sleep", tags=["Sleep"])
app.include_router(training_plans.router, prefix="/api/v1/training-plans", tags=["Training Plans"])
app.include_router(social.router, prefix="/api/v1/social", tags=["Social"])
app.include_router(meal_plans.router, prefix="/api/v1/meal-plans", tags=["Meal Plans"])
app.include_router(account.router, prefix="/api/v1/account", tags=["Account"])


@app.get("/")
async def root():
    """Root endpoint with API info."""
    return {
        "name": settings.app_name,
        "version": settings.api_version,
        "docs": "/docs",
        "health": "/health",
    }
