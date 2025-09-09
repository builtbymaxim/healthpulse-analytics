import streamlit as st
from healthpulse_app import create_theme_toggle_button


def test_create_theme_toggle_button(monkeypatch):
    """Theme toggle button switches between light and dark modes"""

    def fake_button(label, key, on_click, help):  # pragma: no cover - simple stub
        on_click()
        return True

    monkeypatch.setattr(st, "button", fake_button)
    monkeypatch.setattr(st, "rerun", lambda: None)

    st.session_state.clear()
    st.session_state.theme = "light"
    create_theme_toggle_button()
    assert st.session_state.theme == "dark"

    create_theme_toggle_button()
    assert st.session_state.theme == "light"
