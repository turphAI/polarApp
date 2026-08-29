"""
Configuration for the polarWatch backend.

Secrets (POLAR_CLIENT_ID / POLAR_CLIENT_SECRET) come from the environment —
the run script sources them from the gitignored data/secrets.env, mirroring
witness's config.py. Nothing here is a secret itself.
"""
import os
from pathlib import Path

DATA_DIR = Path(os.environ.get("POLARWATCH_DATA_DIR", Path(__file__).parent.parent / "data"))
DB_PATH = DATA_DIR / "polarwatch.db"

# Polar AccessLink v4 (Dynamic API) — distinct host/endpoints from the old v3
# AccessLink API. See CLAUDE.md "Polar API gotchas" for why this matters.
POLAR_AUTH_URL = "https://auth.polar.com/oauth/authorize"
POLAR_TOKEN_URL = "https://auth.polar.com/oauth/token"
# Not toggleable in admin.polaraccesslink.com's "Available data types" UI —
# that portal only shows the older v3-style categories (Exercise, Daily
# activity, Physical information). Verified empirically (2026-08-29) that
# v4 scopes work anyway if requested directly here, regardless of what the
# portal's checkboxes show: continuous_samples:read succeeded even though it
# was never toggled. training_sessions:read (needed for per-workout data,
# since this watch is worn during activity only, not 24/7) is added the
# same way — confirmed via a 403 "Missing required scope" response (not a
# 404), which proves the endpoint path is real and just needs this scope.
POLAR_API_BASE = "https://www.polaraccesslink.com/v4/data"
POLAR_SCOPE = "continuous_samples:read training_sessions:read"

POLAR_CLIENT_ID = os.environ.get("POLAR_CLIENT_ID", "")
POLAR_CLIENT_SECRET = os.environ.get("POLAR_CLIENT_SECRET", "")
POLAR_REDIRECT_URI = os.environ.get("POLAR_REDIRECT_URI", "http://127.0.0.1:5057/api/auth/callback")

# How many of the most recent days count as the "recent" window for the
# Improving/Stable/Worsening trend comparison, and how many days before that
# form the "prior" window it's compared against.
TREND_RECENT_DAYS = 7
TREND_PRIOR_DAYS = 7

# A day-over-day resting-average delta smaller than this (bpm) reads as
# "Stable" rather than up/down — avoids noise reading as a trend.
TREND_STABLE_THRESHOLD_BPM = 2
