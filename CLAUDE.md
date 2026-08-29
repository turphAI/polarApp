# CLAUDE.md — polarWatch

## What this is

A personal heart-rate PWA. The real workflow: activities are started/stopped
in **Strava**, and the Polar watch is worn passively alongside, purely for
heart rate — it's not a daily/sleep watch. So the unit of interest is
**per-activity heart rate**, not a 24/7 timeline: pull the activity list from
Strava, then slice Polar's continuous heart-rate data down to each activity's
time window.

Supersedes an earlier native-iOS attempt at `polarView/` (SwiftUI, abandoned
— left in place, not deleted, for history). That attempt stalled on the Polar
API mismatch documented below and never got past placeholder UI.

## Architecture

- **Backend**: Flask (`backend/`), SQLite (`data/polarwatch.db`, gitignored).
- **Frontend**: Svelte + Vite PWA (`frontend/`), builds to `static/`.
- **Deploy**: the mini, launchd-supervised, mounted on the tailnet via
  `tailscale serve`. See DEPLOY.md.
- Secrets (`POLAR_CLIENT_ID`/`SECRET`, `STRAVA_CLIENT_ID`/`SECRET`, redirect
  URIs) live in `data/secrets.env` (gitignored) — copy from
  `data/secrets.env.example`. Sourced by the launchd run scripts in
  `infra/launchd/`.

## Polar API gotchas (hard-won — read before touching `polar_client.py`)

- **v3 vs v4 are different systems**, not just a version bump. v3
  ("AccessLink") uses `flow.polar.com`/`polarremote.com` OAuth hosts,
  effectively-non-expiring tokens, and endpoints like
  `/v3/users/continuous-heart-rate/{date}`. v4 ("Dynamic API") uses
  `auth.polar.com/oauth/{authorize,token}`, **12h access tokens with a
  refresh_token flow**, and `/v4/data/...` endpoints. A v4 token gets a plain
  `401` from v3 endpoints (confirmed: hit `/v3/exercise-transactions` with a
  v4 token, got a Tomcat 401 page, not a Polar JSON error). This app only
  uses v4.
- **admin.polaraccesslink.com's "Available data types" toggles are stale/
  incomplete** — they only show v3-era categories (Exercise, Daily activity,
  Physical information). They do NOT list v4 scopes like
  `continuous_samples:read` or `training_sessions:read`. Request those scopes
  directly in the OAuth `scope` parameter anyway — confirmed working despite
  not being toggleable in the portal UI. A `403 {"error":"Missing required
  scope: ..."}` (not a 404) is how you confirm an endpoint path is real and
  just needs a scope grant.
- **`GET /v4/data/continuous-samples`** response has `heartRateSamplesPerDay`
  **top-level** — NOT wrapped in a `"continuousSamples"` envelope (an earlier
  AI-summarized doc fetch got this wrong; verified against the real response
  2026-08-29). `offsetMillis` per sample is milliseconds since **local**
  midnight of that date (in `config.LOCAL_TZ`) — confirmed correct by
  independently matching a Strava activity's HR window against the day's
  overall high and getting an exact match.
- **`GET /v4/data/training-sessions/list`** needs `training_sessions:read`
  and `from`/`to` as bare ISO datetimes (`2026-07-01T00:00:00`, no
  timezone offset, no milliseconds — `Z`-suffixed or date-only both get
  rejected with `"could not be parsed as datetime"`). Max 90-day range.
  **This account's training-sessions list is empty** going back through all
  of 2025 — nothing has ever been explicitly start/stopped as a workout on
  the Polar watch itself. That's *why* this app matches Strava activities
  against continuous-samples instead of using training-sessions directly.
- `/v4/data/continuous-samples` max range is 30 days per call; retention is
  roughly the same window. `sync.py` (daily launchd job, see DEPLOY.md) is
  what turns that rolling window into permanent history — one row per
  evening in `heart_rate_daily` before Polar would drop it.
- No "register user" call is needed for v4 (that's a v3 requirement). A
  search-engine summary once claimed otherwise; checked against real working
  v4 client source code (not another doc summary) and confirmed false.

## Strava

- OAuth is standard v3 Strava API — `www.strava.com/oauth/{authorize,token}`,
  scope `activity:read_all`, token response includes an absolute
  `expires_at` Unix timestamp (not a duration like Polar's `expires_in`).
- Strava's redirect validation is **domain-only** (the app's "Authorization
  Callback Domain" setting), unlike Polar's exact-URL match — but this app's
  `STRAVA_REDIRECT_URI` should still be the full real callback URL; Strava
  just checks its domain matches what's registered.
- `activities` table holds Strava's fields always; `hr_*` columns are filled
  in separately by `match.py`, which slices `polar_client.get_samples_with_
  local_time()` to each activity's `[start, start+elapsed_time]` window
  (converted UTC→local via `config.LOCAL_TZ`). `hr_matched_at` is set even on
  a genuine miss (activity predates any Polar data) so nothing retries
  forever.

## Ports / mini layout

Port 5057 (next free after turph 5050, witness 5051, turphfolio 5052,
turphDocs 5053, vasospasm 5054, turphRetirement 5055, hiking 5056). Mounted
at `/polarwatch` via `tailscale serve`. See DEPLOY.md for the full sequence.

## Branching

Work happens on `feature/*` branches off `main`. This repo's `main` is
`claude/init-ios-app-F8KD7`-derived and still contains the abandoned iOS
build in history — that's fine, `polarView/` is kept as-is rather than
rewritten out.
