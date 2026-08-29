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
POLAR_API_BASE = "https://www.polaraccesslink.com/v4/data"
POLAR_SCOPE = "continuous_samples:read"

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
