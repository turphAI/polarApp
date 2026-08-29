"""
Strava API v3 client — OAuth + activity listing.

Strava is the actual start/stop activity log (per user: workouts are tracked
in Strava, the Polar watch is just worn passively alongside). This client
only reads activities; heart rate itself still comes from Polar's
continuous-samples, sliced to each activity's time window (see match.py).
"""
import time

import requests

import config
import db


class StravaAuthError(Exception):
    """Raised when we have no usable token and the user needs to reconnect."""


class StravaAPIError(Exception):
    """Raised on a non-auth API failure."""


def authorize_url(state):
    params = {
        "client_id": config.STRAVA_CLIENT_ID,
        "redirect_uri": config.STRAVA_REDIRECT_URI,
        "response_type": "code",
        "approval_prompt": "auto",
        "scope": config.STRAVA_SCOPE,
        "state": state,
    }
    query = "&".join(f"{k}={requests.utils.quote(str(v))}" for k, v in params.items())
    return f"{config.STRAVA_AUTH_URL}?{query}"


def exchange_code(code):
    resp = requests.post(
        config.STRAVA_TOKEN_URL,
        data={
            "client_id": config.STRAVA_CLIENT_ID,
            "client_secret": config.STRAVA_CLIENT_SECRET,
            "code": code,
            "grant_type": "authorization_code",
        },
        timeout=15,
    )
    return _store_token_response(resp)


def _refresh(refresh_token):
    resp = requests.post(
        config.STRAVA_TOKEN_URL,
        data={
            "client_id": config.STRAVA_CLIENT_ID,
            "client_secret": config.STRAVA_CLIENT_SECRET,
            "grant_type": "refresh_token",
            "refresh_token": refresh_token,
        },
        timeout=15,
    )
    return _store_token_response(resp)


def _store_token_response(resp):
    if resp.status_code != 200:
        raise StravaAuthError(f"Token endpoint returned {resp.status_code}: {resp.text[:300]}")
    body = resp.json()
    access_token = body.get("access_token")
    refresh_token = body.get("refresh_token")
    # Strava returns an absolute unix timestamp (expires_at), not a duration —
    # different from Polar's expires_in. Use it directly if present.
    expires_at = body.get("expires_at") or (time.time() + body.get("expires_in", 6 * 3600))
    athlete_id = str(body.get("athlete", {}).get("id")) if body.get("athlete") else None
    if not access_token or not refresh_token:
        raise StravaAuthError(f"Token response missing access/refresh token: {body}")
    db.save_strava_token(access_token, refresh_token, expires_at, athlete_id)
    return access_token


def get_valid_access_token():
    token = db.get_strava_token()
    if not token:
        raise StravaAuthError("Not connected to Strava yet.")

    if token["expires_at"] - time.time() < 300:
        return _refresh(token["refresh_token"])

    return token["access_token"]


def list_activities(after_ts, before_ts, per_page=100):
    """List activities in a Unix-timestamp window. Handles pagination.

    Returns a list of raw Strava activity dicts (id, name, type, sport_type,
    start_date [UTC], start_date_local, elapsed_time, distance, ...).
    """
    access_token = get_valid_access_token()
    activities = []
    page = 1
    while True:
        resp = requests.get(
            f"{config.STRAVA_API_BASE}/athlete/activities",
            headers={"Authorization": f"Bearer {access_token}"},
            params={"after": after_ts, "before": before_ts, "page": page, "per_page": per_page},
            timeout=30,
        )
        if resp.status_code == 401:
            raise StravaAuthError(f"Strava rejected the access token (401): {resp.text[:300]}")
        if resp.status_code != 200:
            raise StravaAPIError(f"activities returned {resp.status_code}: {resp.text[:300]}")

        batch = resp.json()
        if not batch:
            break
        activities.extend(batch)
        if len(batch) < per_page:
            break
        page += 1

    return activities


def sync_recent_activities(days_back=30):
    """Pulls activities from Strava and upserts them into the local DB.

    Only writes Strava-side fields (name, time, distance) — heart-rate
    matching against Polar is a separate step (match.py), run after this.
    Returns the number of activities upserted.
    """
    now = time.time()
    after_ts = int(now - days_back * 86400)
    activities = list_activities(after_ts=after_ts, before_ts=int(now))

    for a in activities:
        db.upsert_activity(
            strava_id=a["id"],
            name=a.get("name"),
            sport_type=a.get("sport_type") or a.get("type"),
            start_date_utc=a["start_date"],
            elapsed_time_sec=a["elapsed_time"],
            distance_m=a.get("distance"),
        )

    return len(activities)
