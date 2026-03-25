"""Tests for APNs push notification service."""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch


# ---------------------------------------------------------------------------
# send_push — unconfigured (missing env vars)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_send_push_skipped_when_not_configured():
    """Returns False and does not make any HTTP call when APNs env vars are absent."""
    with patch.dict("os.environ", {}, clear=True):
        # Remove all APNS_* vars
        import os
        for key in ("APNS_KEY", "APNS_KEY_ID", "APNS_TEAM_ID"):
            os.environ.pop(key, None)

        from app.services.push_service import send_push
        result = await send_push("fake_device_token", "Hello", "World")

    assert result is False


# ---------------------------------------------------------------------------
# send_push — APNs returns 200
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_send_push_success():
    """Returns True when APNs responds with 200."""
    apns_env = {
        "APNS_KEY": "-----BEGIN EC PRIVATE KEY-----\nMHQCAQEEIFAKEKEYFAKEKEYFAKEKEY==\n-----END EC PRIVATE KEY-----",
        "APNS_KEY_ID": "ABC1234567",
        "APNS_TEAM_ID": "TEAM123456",
        "APNS_BUNDLE_ID": "com.healthpulse.app",
        "APNS_ENVIRONMENT": "sandbox",
    }
    mock_response = MagicMock()
    mock_response.status_code = 200

    mock_client = AsyncMock()
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)
    mock_client.post = AsyncMock(return_value=mock_response)

    with patch.dict("os.environ", apns_env):
        with patch("jwt.encode", return_value="mock_jwt_token"):
            with patch("httpx.AsyncClient", return_value=mock_client):
                from importlib import reload
                import app.services.push_service as ps
                reload(ps)  # force re-import with patched env

                result = await ps.send_push(
                    "abc123devicetoken",
                    title="New Partnership Request",
                    body="Someone wants to be your partner!",
                    data={"deep_link": "healthpulse://social/pending"},
                )

    assert result is True


# ---------------------------------------------------------------------------
# send_push — APNs returns 400 (bad token)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_send_push_returns_false_on_apns_error():
    """Returns False when APNs rejects the push (non-200 status)."""
    apns_env = {
        "APNS_KEY": "fake_key",
        "APNS_KEY_ID": "ABC1234567",
        "APNS_TEAM_ID": "TEAM123456",
    }
    mock_response = MagicMock()
    mock_response.status_code = 400
    mock_response.text = "BadDeviceToken"

    mock_client = AsyncMock()
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)
    mock_client.post = AsyncMock(return_value=mock_response)

    with patch.dict("os.environ", apns_env):
        with patch("jwt.encode", return_value="mock_jwt_token"):
            with patch("httpx.AsyncClient", return_value=mock_client):
                from importlib import reload
                import app.services.push_service as ps
                reload(ps)

                result = await ps.send_push("bad_token", "Title", "Body")

    assert result is False


# ---------------------------------------------------------------------------
# send_push — network exception
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_send_push_returns_false_on_exception():
    """Returns False (never raises) when an exception occurs."""
    apns_env = {
        "APNS_KEY": "fake_key",
        "APNS_KEY_ID": "ABC1234567",
        "APNS_TEAM_ID": "TEAM123456",
    }
    mock_client = AsyncMock()
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)
    mock_client.post = AsyncMock(side_effect=ConnectionError("Network unreachable"))

    with patch.dict("os.environ", apns_env):
        with patch("jwt.encode", return_value="mock_jwt_token"):
            with patch("httpx.AsyncClient", return_value=mock_client):
                from importlib import reload
                import app.services.push_service as ps
                reload(ps)

                result = await ps.send_push("some_token", "Title", "Body")

    assert result is False


# ---------------------------------------------------------------------------
# Device token hex conversion (utility test)
# ---------------------------------------------------------------------------

def test_device_token_hex_conversion():
    """iOS Data -> hex string conversion produces expected format."""
    # Simulate what iOS does: token bytes -> lowercase hex string
    raw = bytes([0xAB, 0xCD, 0xEF, 0x01, 0x23])
    hex_str = raw.hex()
    assert hex_str == "abcdef0123"
    assert len(hex_str) == len(raw) * 2
