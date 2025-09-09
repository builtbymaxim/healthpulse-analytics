import sys
import types
from datetime import datetime
from unittest.mock import patch
import pytest

# Create a minimal stub for streamlit before importing the app
streamlit_stub = types.ModuleType("streamlit")

class SessionState(dict):
    def __getattr__(self, key):
        try:
            return self[key]
        except KeyError:
            raise AttributeError(key)

    def __setattr__(self, key, value):
        self[key] = value

streamlit_stub.session_state = SessionState()
streamlit_stub.set_page_config = lambda **kwargs: None
streamlit_stub.markdown = lambda *args, **kwargs: None
streamlit_stub.button = lambda *args, **kwargs: None
streamlit_stub.rerun = lambda: None

# cache decorators simply return the original function
def _cache_decorator(*args, **kwargs):
    def wrapper(func):
        return func
    return wrapper

streamlit_stub.cache_data = _cache_decorator
streamlit_stub.cache_resource = _cache_decorator
sys.modules['streamlit'] = streamlit_stub

import healthpulse_app as app


def test_get_default_theme_daytime():
    """Light theme during daytime hours"""
    with patch('healthpulse_app.datetime') as mock_datetime:
        mock_datetime.now.return_value = datetime(2023, 1, 1, 10, 0, 0)
        assert app.get_default_theme() == 'light'


def test_get_default_theme_nighttime():
    """Dark theme during nighttime hours"""
    with patch('healthpulse_app.datetime') as mock_datetime:
        mock_datetime.now.return_value = datetime(2023, 1, 1, 22, 0, 0)
        assert app.get_default_theme() == 'dark'


def test_init_theme_sets_defaults(monkeypatch):
    """Initialize theme and page when session state empty"""
    app.st.session_state.clear()
    monkeypatch.setattr(app, 'get_default_theme', lambda: 'light')
    app.init_theme()
    assert app.st.session_state['theme'] == 'light'
    assert app.st.session_state['current_page'] == 'Overview'


def test_init_theme_preserves_existing():
    """Existing session state is not overwritten"""
    app.st.session_state.clear()
    app.st.session_state['theme'] = 'dark'
    app.st.session_state['current_page'] = 'Metrics'
    app.init_theme()
    assert app.st.session_state['theme'] == 'dark'
    assert app.st.session_state['current_page'] == 'Metrics'


def test_get_theme_colors_switch():
    """Color palette changes with theme"""
    app.st.session_state.clear()
    app.st.session_state['theme'] = 'light'
    colors_light = app.get_theme_colors()
    assert colors_light['background'] == '#F8F9FA'

    app.st.session_state['theme'] = 'dark'
    colors_dark = app.get_theme_colors()
    assert colors_dark['background'] == '#121212'
    assert colors_light != colors_dark
