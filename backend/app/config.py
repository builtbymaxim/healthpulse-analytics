"""Application configuration."""

from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # App settings
    app_name: str = "HealthPulse API"
    debug: bool = False
    api_version: str = "v1"

    # Supabase settings
    supabase_url: str = ""
    supabase_anon_key: str = ""
    supabase_service_key: str = ""

    # JWT settings (Supabase handles this, but useful for validation)
    jwt_secret: str = ""

    # CORS settings (comma-separated string in .env)
    cors_origins_str: str = "http://localhost:3000,http://localhost:8501"

    @property
    def cors_origins(self) -> list[str]:
        """Parse CORS origins from comma-separated string."""
        return [origin.strip() for origin in self.cors_origins_str.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
