"""Supabase database client."""

from functools import lru_cache
from supabase import create_client, Client
from supabase.lib.client_options import ClientOptions

from app.config import get_settings

# 10-second timeout on all PostgREST queries — prevents Railway dyno hangs
# if Supabase is temporarily unreachable.
_CLIENT_OPTIONS = ClientOptions(postgrest_client_timeout=10)


@lru_cache
def get_supabase_client() -> Client:
    """Get cached Supabase client instance."""
    settings = get_settings()
    return create_client(settings.supabase_url, settings.supabase_service_key, options=_CLIENT_OPTIONS)


def get_supabase_admin() -> Client:
    """Get Supabase client with service role (admin) access."""
    settings = get_settings()
    return create_client(settings.supabase_url, settings.supabase_service_key)


def get_supabase_anon() -> Client:
    """Get Supabase client with anon (public) access."""
    settings = get_settings()
    return create_client(settings.supabase_url, settings.supabase_anon_key)
