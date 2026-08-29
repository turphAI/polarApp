"""
Matches Strava activities (the start/stop log) to Polar heart-rate data, by
slicing Polar's continuous-samples for the relevant day(s) down to the
activity's [start, start + elapsed_time] window.
"""
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

import config
import db
import polar_client


def _parse_strava_utc(iso_str):
    """Strava gives e.g. "2026-08-28T16:18:00Z"."""
    return datetime.strptime(iso_str, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)


def match_activity(activity):
    """Attempt to find HR samples for one activity's time window.

    Always records hr_matched_at (even when nothing is found), so an
    activity Polar genuinely has no data for isn't retried forever.
    Returns True if samples were found, False otherwise.
    """
    tz = ZoneInfo(config.LOCAL_TZ)
    start_utc = _parse_strava_utc(activity["start_date_utc"])
    end_utc = start_utc + timedelta(seconds=activity["elapsed_time_sec"])
    start_local = start_utc.astimezone(tz)
    end_local = end_utc.astimezone(tz)

    # Gather samples from every local calendar day the window touches —
    # usually one day, but this also covers an activity that crosses midnight.
    samples = []
    day = start_local.date()
    while day <= end_local.date():
        samples.extend(polar_client.get_samples_with_local_time(day))
        day += timedelta(days=1)

    in_window = [s for s in samples if start_local <= s["local_dt"] <= end_local]

    if not in_window:
        db.update_activity_hr(activity["strava_id"], None, None, None, 0)
        return False

    values = [s["heart_rate"] for s in in_window]
    high, low = max(values), min(values)
    avg = round(sum(values) / len(values))
    db.update_activity_hr(activity["strava_id"], high, low, avg, len(values))
    return True


def match_all_unmatched():
    """Runs match_activity() over every activity not yet attempted.

    Returns (matched_count, unmatched_count) for callers to report.
    """
    matched = unmatched = 0
    for activity in db.get_unmatched_activities():
        if match_activity(activity):
            matched += 1
        else:
            unmatched += 1
    return matched, unmatched
