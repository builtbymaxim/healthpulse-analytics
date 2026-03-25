"""APNs push notification service using JWT-based HTTP/2 auth."""

import os
import time
import logging

logger = logging.getLogger(__name__)


async def send_push(
    device_token: str,
    title: str,
    body: str,
    data: dict | None = None,
) -> bool:
    """Send APNs push notification.

    Returns True on success, False if APNs is unconfigured or the request fails.
    Logs warnings on failure — never raises so callers can fire-and-forget.
    """
    apns_key = os.environ.get("APNS_KEY")
    apns_key_id = os.environ.get("APNS_KEY_ID")
    apns_team_id = os.environ.get("APNS_TEAM_ID")
    bundle_id = os.environ.get("APNS_BUNDLE_ID", "com.healthpulse.app")
    apns_env = os.environ.get("APNS_ENVIRONMENT", "sandbox")

    if not all([apns_key, apns_key_id, apns_team_id]):
        logger.debug("APNs not configured — skipping push to %s", device_token[:8])
        return False

    try:
        import jwt as pyjwt  # PyJWT
        import httpx

        jwt_token = pyjwt.encode(
            {"iss": apns_team_id, "iat": int(time.time())},
            apns_key,
            algorithm="ES256",
            headers={"kid": apns_key_id},
        )

        host = (
            "https://api.push.apple.com"
            if apns_env == "production"
            else "https://api.sandbox.push.apple.com"
        )

        payload: dict = {
            "aps": {
                "alert": {"title": title, "body": body},
                "sound": "default",
            }
        }
        if data:
            payload.update(data)

        headers = {
            "authorization": f"bearer {jwt_token}",
            "apns-topic": bundle_id,
            "apns-push-type": "alert",
        }

        async with httpx.AsyncClient(http2=True) as client:
            resp = await client.post(
                f"{host}/3/device/{device_token}",
                json=payload,
                headers=headers,
                timeout=10.0,
            )

        if resp.status_code != 200:
            logger.warning(
                "APNs rejected push to %s...: %s %s",
                device_token[:8],
                resp.status_code,
                resp.text,
            )
        return resp.status_code == 200

    except Exception as exc:
        logger.warning("APNs push failed: %s", exc)
        return False
