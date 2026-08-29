"""
Polar AccessLink v4 (Dynamic API) client.

v4 is NOT the same system as the older v3 AccessLink API that polarView's
native attempt used — different OAuth host, different scopes, different
endpoint shapes, and (unlike v3's effectively-non-expiring tokens) a 12h
access-token lifetime with a refresh_token flow. See CLAUDE.md for the full
story of how that mismatch was found.
"""
import base64
import time
from datetime import date as date_cls, timedelta

import requests

import config
import db


class PolarAuthError(Exception):
    """Raised when we have no usable token and the user needs to reconnect."""


class PolarAPIError(Exception):
    """Raised on a non-auth API failure (bad response, network, etc.)."""


def authorize_url(state):
    params = {
        "response_type": "code",
        "client_id": config.POLAR_CLIENT_ID,
        "redirect_uri": config.POLAR_REDIRECT_URI,
        "scope": config.POLAR_SCOPE,
        "state": state,
    }
    query = "&".join(f"{k}={requests.utils.quote(str(v))}" for k, v in params.items())
    return f"{config.POLAR_AUTH_URL}?{query}"


def _basic_auth_header():
    creds = f"{config.POLAR_CLIENT_ID}:{config.POLAR_CLIENT_SECRET}".encode()
    return {"Authorization": f"Basic {base64.b64encode(creds).decode()}"}


def exchange_code(code):
    """One-time: turn an authorization code into a token pair, and store it."""
    resp = requests.post(
        config.POLAR_TOKEN_URL,
        headers={**_basic_auth_header(), "Accept": "application/json"},
        data={
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": config.POLAR_REDIRECT_URI,
        },
        timeout=15,
    )
    return _store_token_response(resp)


def _refresh(refresh_token):
    resp = requests.post(
        config.POLAR_TOKEN_URL,
        headers={**_basic_auth_header(), "Accept": "application/json"},
        data={"grant_type": "refresh_token", "refresh_token": refresh_token},
        timeout=15,
    )
    return _store_token_response(resp)


def _store_token_response(resp):
    if resp.status_code != 200:
        raise PolarAuthError(f"Token endpoint returned {resp.status_code}: {resp.text[:300]}")
    body = resp.json()
    access_token = body.get("access_token")
    refresh_token = body.get("refresh_token")
    expires_in = body.get("expires_in", 12 * 3600)
    polar_user_id = body.get("x_user_id")
    if not access_token or not refresh_token:
        raise PolarAuthError(f"Token response missing access/refresh token: {body}")
    expires_at = time.time() + expires_in
    db.save_token(access_token, refresh_token, expires_at, polar_user_id)
    return access_token


def get_valid_access_token():
    """Returns a usable access token, refreshing first if it's near expiry.

    Fails loud: raises PolarAuthError (not a silent None) so callers surface
    "reconnect to Polar" instead of quietly skipping a sync.
    """
    token = db.get_token()
    if not token:
        raise PolarAuthError("Not connected to Polar yet.")

    # Refresh a bit before actual expiry so a slow request doesn't race it.
    if token["expires_at"] - time.time() < 300:
        return _refresh(token["refresh_token"])

    return token["access_token"]


def get_daily_summary(for_date: date_cls):
    """Fetch one day's continuous heart-rate samples and summarize them.

    Returns (high, low, avg, latest, sample_count) or None if Polar has no
    data for that date (e.g. watch hasn't synced yet that day).
    """
    access_token = get_valid_access_token()
    from_str = for_date.isoformat()
    to_str = (for_date + timedelta(days=1)).isoformat()

    resp = requests.get(
        f"{config.POLAR_API_BASE}/continuous-samples",
        headers={"Authorization": f"Bearer {access_token}", "Accept": "application/json"},
        params={"from": from_str, "to": to_str, "features": "heart-rate-samples"},
        timeout=30,
    )

    if resp.status_code == 401:
        raise PolarAuthError(f"Polar rejected the access token (401): {resp.text[:300]}")
    if resp.status_code == 404:
        return None
    if resp.status_code != 200:
        raise PolarAPIError(f"continuous-samples returned {resp.status_code}: {resp.text[:300]}")

    body = resp.json()
    days = (body.get("continuousSamples") or {}).get("heartRateSamplesPerDay") or []
    all_samples = []
    for day_entry in days:
        if day_entry.get("date") != from_str:
            continue
        all_samples.extend(day_entry.get("samples") or [])

    if not all_samples:
        return None

    all_samples.sort(key=lambda s: s.get("offsetMillis", 0))
    values = [s["heartRate"] for s in all_samples if "heartRate" in s]
    if not values:
        return None

    high = max(values)
    low = min(values)
    avg = round(sum(values) / len(values))
    latest = all_samples[-1]["heartRate"]
    return high, low, avg, latest, len(values)
