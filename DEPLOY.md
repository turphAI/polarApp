# Deploying polarWatch on the mini

The mini is the only host. The laptop never runs polarWatch services.

polarWatch runs as its own service alongside the rest of the suite. turph
owns the tailnet root (`https://mini.tail5ef0b2.ts.net/`) on port 5050;
polarWatch is a separate Flask app on **port 5057**, mounted at `/polarwatch`
via `tailscale serve`. Fully decoupled from every other app.

## What runs

- Flask (`backend/app.py`) bound to `127.0.0.1:5057`, supervised by launchd
  (`com.polarwatch.app`), `KeepAlive` on.
- A second launchd job, `com.polarwatch.sync`, runs `backend/sync.py` once
  daily (~21:00, `StartCalendarInterval`) — pulls that day's Polar heart
  rate into permanent history before Polar's ~30-day retention drops it.
  One-shot, no `KeepAlive`.
- `tailscale serve` mounts the Flask app at
  `https://mini.tail5ef0b2.ts.net/polarwatch/`.
- The built SPA in `static/` (regenerated from `frontend/` on each deploy),
  base path `/polarwatch/`.
- SQLite at `data/polarwatch.db` (gitignored).
- Secrets at `data/secrets.env` (gitignored) — see `data/secrets.env.example`
  for the required keys (Polar + Strava client IDs/secrets, redirect URIs).

## Running commands over SSH

```sh
ssh turph@mini 'eval "$(/opt/homebrew/bin/brew shellenv)"; cd ~/Projects/polarWatch && git pull && ...'
```

Non-interactive SSH doesn't source `~/.zprofile`, so `brew`/`node`/`npm`
need the `shellenv` prefix. `tailscale` needs its absolute path
(`/opt/homebrew/bin/tailscale`) for the same reason. `python3`/`pip` inside
the venv and plain `curl`/`launchctl` are unaffected.

## One-time setup

```sh
# Backend
cd ~/Projects/polarWatch/backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
deactivate

# Frontend
cd ~/Projects/polarWatch/frontend
npm install
npm run build             # outputs to ../static/ with base /polarwatch/

# Secrets
cd ~/Projects/polarWatch
cp data/secrets.env.example data/secrets.env
nano data/secrets.env     # fill in POLAR_/STRAVA_ CLIENT_ID and CLIENT_SECRET

# launchd
cp infra/launchd/com.polarwatch.app.plist ~/Library/LaunchAgents/
cp infra/launchd/com.polarwatch.sync.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.polarwatch.app.plist
launchctl load ~/Library/LaunchAgents/com.polarwatch.sync.plist

# Tailscale serve
/opt/homebrew/bin/tailscale serve --bg --set-path /polarwatch 5057
```

Then do the one-time OAuth connects (see below) — nothing works until both
providers are connected.

Verify:
```sh
curl -s http://127.0.0.1:5057/api/health
curl -s https://mini.tail5ef0b2.ts.net/polarwatch/api/health
tailscale serve status   # confirm /polarwatch sits alongside the other apps, none clobbered
```

## Connecting Polar / Strava (one-time, or after adding a new OAuth scope)

Visit directly (not through the app UI, which skips this once already
"connected" — hit these URLs straight if you need to *re*-authorize, e.g.
after a scope change):

```
https://mini.tail5ef0b2.ts.net/polarwatch/api/auth/start          # Polar
https://mini.tail5ef0b2.ts.net/polarwatch/api/strava/auth/start   # Strava
```

Log in and approve. Confirm with:
```sh
curl -s https://mini.tail5ef0b2.ts.net/polarwatch/api/auth/status
curl -s https://mini.tail5ef0b2.ts.net/polarwatch/api/strava/status
```

## Updates (every deploy)

```sh
cd ~/Projects/polarWatch
git pull

# Backend deps if requirements.txt changed
cd backend && source .venv/bin/activate && pip install -r requirements.txt && deactivate

# Frontend rebuild (always — bundle changes any time src/ changes)
cd ../frontend && npm install && npm run build

# Restart Flask (schema migrations, if any, run automatically via db.init_db()
# at module load — no separate init step needed)
launchctl kickstart -k gui/$(id -u)/com.polarwatch.app
```

The sync job doesn't need restarting on a deploy — it's a fresh one-shot
process each time launchd fires it, so it always picks up the latest code.

## Manual sync / matching (without waiting for the scheduled jobs)

```sh
# One day's Polar heart rate
curl -s -X POST "https://mini.tail5ef0b2.ts.net/polarwatch/api/sync/now?date=2026-08-28"

# Pull recent Strava activities + attempt HR matching against Polar data
curl -s -X POST "https://mini.tail5ef0b2.ts.net/polarwatch/api/strava/sync/now?days=30"
```

## Logs

```sh
tail -f ~/Projects/polarWatch/polarwatch.log         # Flask app
tail -f ~/Projects/polarWatch/polarwatch-sync.log     # daily sync job
```
