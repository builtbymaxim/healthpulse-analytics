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

    # Vision API settings (AI Food Scanner)
    vision_provider: str = "gemini"        # "gemini", "openai", or "claude"
    gemini_api_key: str = ""
    anthropic_api_key: str = ""
    openai_api_key: str = ""
    usda_api_key: str = ""                 # free key from api.data.gov

    # CORS settings (comma-separated string in .env)
    # iOS native clients don't send Origin headers, so CORS only matters for
    # web dashboards or Swagger UI. Leave empty in production to deny all web origins.
    cors_origins_str: str = ""

    @property
    def cors_origins(self) -> list[str]:
        """Parse CORS origins from comma-separated string."""
        origins = [origin.strip() for origin in self.cors_origins_str.split(",") if origin.strip()]
        # Explicit "*" still supported via env var for local dev / open APIs
        if "*" in origins:
            return ["*"]
        # Default for local dev: allow localhost origins when no explicit list is set
        if not origins and self.debug:
            return ["http://localhost:3000", "http://localhost:8000", "http://127.0.0.1:8000"]
        return origins


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
