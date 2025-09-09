import pytest
import streamlit as st

from healthpulse_app import create_theme_toggle_button


def test_theme_toggle_button(monkeypatch):
    """Ensure theme toggles between light and dark"""
    st.session_state.clear()
    st.session_state.theme = "light"
    st.session_state.theme_toggle = True

    def fake_toggle(*args, **kwargs):
        if "on_change" in kwargs and kwargs["on_change"]:
            kwargs["on_change"]()
        return st.session_state.theme_toggle

    monkeypatch.setattr(st, "toggle", fake_toggle)
    monkeypatch.setattr(st, "rerun", lambda: None)

    create_theme_toggle_button()
    assert st.session_state.theme == "dark"

    st.session_state.theme_toggle = False
    create_theme_toggle_button()
    assert st.session_state.theme == "light"

