"""HealthPulse API - Main FastAPI application."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.api import auth, health, metrics, nutrition, predictions, users, workouts, exercises, sleep, training_plans, social

settings = get_settings()

app = FastAPI(
    title=settings.app_name,
    version=settings.api_version,
    description="AI-powered fitness and health analytics API",
    docs_url="/docs",
    redoc_url="/redoc",
    redirect_slashes=False,  # Prevent 307 redirects that lose auth headers
)

# CORS middleware for web and mobile clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
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


@app.get("/")
async def root():
    """Root endpoint with API info."""
    return {
        "name": settings.app_name,
        "version": settings.api_version,
        "docs": "/docs",
        "health": "/health",
    }
