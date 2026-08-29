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
from datetime import date as date_cls, datetime, timedelta
from zoneinfo import ZoneInfo

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


def get_samples_with_local_time(for_date: date_cls):
    """Fetch one day's raw continuous heart-rate samples, each tagged with a
    real local datetime (not just Polar's offsetMillis-since-midnight).

    Returns a list of {"heart_rate": int, "local_dt": datetime} sorted by
    time, or [] if Polar has no data for that date.

    Shared by get_daily_summary() (whole-day stats) and the Strava-activity
    matcher (slices this same list down to one workout's window) — one HTTP
    call and one parse, reused both ways.
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
        return []
    if resp.status_code != 200:
        raise PolarAPIError(f"continuous-samples returned {resp.status_code}: {resp.text[:300]}")

    body = resp.json()
    # Verified against the real v4 response (2026-08-29): heartRateSamplesPerDay
    # is top-level, NOT wrapped in a "continuousSamples" envelope — earlier docs
    # summarized it wrong. See CLAUDE.md "Polar API gotchas".
    days = body.get("heartRateSamplesPerDay") or []
    raw = []
    for day_entry in days:
        if day_entry.get("date") != from_str:
            continue
        raw.extend(day_entry.get("samples") or [])

    # WORKING ASSUMPTION, not yet verified against a real matched activity
    # (see CLAUDE.md): offsetMillis is milliseconds since LOCAL midnight of
    # `for_date`, in config.LOCAL_TZ. If a real Strava-matched workout later
    # shows the HR window is off by a fixed amount, this is the line to fix.
    midnight_local = datetime.combine(for_date, datetime.min.time(), tzinfo=ZoneInfo(config.LOCAL_TZ))
    samples = [
        {
            "heart_rate": s["heartRate"],
            "local_dt": midnight_local + timedelta(milliseconds=s.get("offsetMillis", 0)),
        }
        for s in raw
        if "heartRate" in s
    ]
    samples.sort(key=lambda s: s["local_dt"])
    return samples


def get_daily_summary(for_date: date_cls):
    """Whole-day high/low/avg/latest, or None if there's no data for that date."""
    samples = get_samples_with_local_time(for_date)
    if not samples:
        return None

    values = [s["heart_rate"] for s in samples]
    high = max(values)
    low = min(values)
    avg = round(sum(values) / len(values))
    latest = samples[-1]["heart_rate"]
    return high, low, avg, latest, len(values)
