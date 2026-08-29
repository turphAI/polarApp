"""
Per-activity detail: merges Strava's elevation/grade streams with Polar's
heart-rate samples on a shared elapsed-time axis, for the "how did my heart
rate respond to this climb/descent" chart. No GPS lat/lng is touched — this
is a data chart (elevation profile + HR), not a route/map.
"""
import bisect
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

import config
import db
import polar_client
import strava_client

# Cap on returned points — Strava streams run near 1Hz, so an hour-long
# activity is ~3600+ raw points; that's more resolution than a chart needs
# and needlessly bloats the response. Fixed-stride downsampling is fine
# since grade_smooth/altitude are already Strava-smoothed.
MAX_POINTS = 400


class ActivityNotFoundError(Exception):
    pass


def _parse_strava_utc(iso_str):
    return datetime.strptime(iso_str, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)


def get_activity_series(strava_id):
    """Returns the activity's summary fields plus a downsampled point series:
    {t_sec, heart_rate (nullable), altitude_m (nullable), grade_pct (nullable)}.

    heart_rate is null for any point outside Polar's data coverage (e.g. the
    activity predates when Polar data starts) — that's a real "no data"
    state for the frontend to show plainly, not an error.
    """
    activity = db.get_activity(strava_id)
    if not activity:
        raise ActivityNotFoundError(f"No activity {strava_id}")

    start_utc = _parse_strava_utc(activity["start_date_utc"])
    tz = ZoneInfo(config.LOCAL_TZ)

    streams = strava_client.get_streams(strava_id)
    times = streams.get("time") or []
    altitudes = streams.get("altitude") or []
    grades = streams.get("grade_smooth") or []

    # Pull Polar samples for every local day this activity's window touches.
    end_utc = start_utc + timedelta(seconds=activity["elapsed_time_sec"])
    hr_samples = []
    day = start_utc.astimezone(tz).date()
    last_day = end_utc.astimezone(tz).date()
    while day <= last_day:
        hr_samples.extend(polar_client.get_samples_with_local_time(day))
        day += timedelta(days=1)
    hr_samples.sort(key=lambda s: s["local_dt"])
    hr_times = [s["local_dt"] for s in hr_samples]  # parallel, sorted — bisect target

    def nearest_heart_rate(at_utc):
        if not hr_samples:
            return None
        at_local = at_utc.astimezone(tz)
        i = bisect.bisect_left(hr_times, at_local)
        candidates = [c for c in (i - 1, i) if 0 <= c < len(hr_samples)]
        if not candidates:
            return None
        best = min(candidates, key=lambda c: abs((hr_times[c] - at_local).total_seconds()))
        # Don't match samples more than 30s away — that's not "the same moment,"
        # that's just Polar having no coverage near this point.
        if abs((hr_times[best] - at_local).total_seconds()) > 30:
            return None
        return hr_samples[best]["heart_rate"]

    raw_points = []
    for i, t in enumerate(times):
        at_utc = start_utc + timedelta(seconds=t)
        raw_points.append({
            "t_sec": t,
            "altitude_m": altitudes[i] if i < len(altitudes) else None,
            "grade_pct": grades[i] if i < len(grades) else None,
            "heart_rate": nearest_heart_rate(at_utc),
        })

    stride = max(1, len(raw_points) // MAX_POINTS)
    points = raw_points[::stride]

    return {
        "strava_id": activity["strava_id"],
        "name": activity["name"],
        "sport_type": activity["sport_type"],
        "start_date_utc": activity["start_date_utc"],
        "elapsed_time_sec": activity["elapsed_time_sec"],
        "distance_m": activity["distance_m"],
        "elevation_gain_m": activity["elevation_gain_m"],
        "hr_high": activity["hr_high"],
        "hr_low": activity["hr_low"],
        "hr_avg": activity["hr_avg"],
        "has_heart_rate": activity["hr_sample_count"] not in (None, 0),
        "points": points,
    }
