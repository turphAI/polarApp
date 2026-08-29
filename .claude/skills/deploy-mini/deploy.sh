#!/bin/sh
# polarWatch → mini deploy. Runs ON the mini (pipe it in: `ssh turph@mini 'bash -s' <
# this`). Pulls, then does ONLY what the diff requires, then verifies. Idempotent
# — a no-op pull deploys nothing. Modeled directly on witness's deploy-mini/deploy.sh.
#
# polarWatch is a SERVICE: launchd com.polarwatch.app on port 5057 (Flask),
# mounted at /polarwatch via tailscale serve. The frontend builds to ../static/
# (Flask serves it fresh — no restart needed for a frontend-only change); backend
# code needs a kickstart. Schema migrations apply automatically — db.init_db()
# runs a migration ladder (see db.py's _migrate()) on every startup, so a
# kickstart migrates the mini's DB. com.polarwatch.sync (the daily evening HR
# sync, StartCalendarInterval) is a separate one-shot job — launchd runs it fresh
# from disk on its own schedule, so it always picks up new code with no restart
# needed here; it shares the same backend/.venv as the app, so a requirements.txt
# change below still needs the venv rebuilt for both to benefit.
set -e
export PATH=/opt/homebrew/bin:$PATH   # non-interactive PATH lacks npm/node/git
cd ~/Projects/polarWatch

before=$(git rev-parse HEAD)
if ! git pull --ff-only >/tmp/polarwatch-deploy-pull.log 2>&1; then
  echo "PULL FAILED:"; cat /tmp/polarwatch-deploy-pull.log; exit 1
fi
after=$(git rev-parse HEAD)
if [ "$before" = "$after" ]; then
  echo "already up to date ($after) — nothing to deploy"; exit 0
fi

changed=$(git diff --name-only "$before" "$after")
echo "deploying $before -> $after"
echo "$changed" | sed 's/^/  changed: /'
did=""

# Frontend → npm install if deps changed (a new dep makes `npm run build` fail to
# resolve imports), then rebuild the static bundle. Flask serves static/ fresh, so
# no restart.
if echo "$changed" | grep -qE '^frontend/'; then
  if echo "$changed" | grep -qE '^frontend/package(-lock)?\.json'; then
    if ! ( cd frontend && npm install ) >/tmp/polarwatch-deploy-npm.log 2>&1; then
      echo "NPM INSTALL FAILED:"; tail -20 /tmp/polarwatch-deploy-npm.log; exit 1
    fi
    did="$did npm-install"
  fi
  if ! ( cd frontend && npm run build ) >/tmp/polarwatch-deploy-build.log 2>&1; then
    echo "BUILD FAILED:"; tail -20 /tmp/polarwatch-deploy-build.log; exit 1
  fi
  did="$did build"
fi
# Backend deps → pip into the app's own venv (shared by app.py and sync.py).
if echo "$changed" | grep -qE '^backend/requirements'; then
  if ! ./backend/.venv/bin/pip install -r backend/requirements.txt >/tmp/polarwatch-deploy-pip.log 2>&1; then
    echo "PIP FAILED:"; tail -20 /tmp/polarwatch-deploy-pip.log; exit 1
  fi
  did="$did pip"
fi
# Backend code → restart the service (also applies any db.init_db migration on
# startup). sync.py needs no restart — see header note.
if echo "$changed" | grep -qE '^backend/.*\.py$'; then
  launchctl kickstart -k "gui/$(id -u)/com.polarwatch.app"
  did="$did kickstart"
fi
# A changed plist needs a manual bootstrap — too rare/risky to automate; flag it.
if echo "$changed" | grep -qE '\.plist$'; then
  echo "NOTE: a .plist changed — may need manual launchctl bootstrap (cp to ~/Library/LaunchAgents/, launchctl load/unload)"
fi
[ -n "$did" ] || did=" none (no deployable paths changed)"
echo "ran:$did"

# Verify: health, then (if we rebuilt) that the served bundle is the fresh one.
for i in $(seq 1 15); do curl -sf http://127.0.0.1:5057/api/health >/dev/null 2>&1 && break; sleep 1; done
health=$(curl -s http://127.0.0.1:5057/api/health || true)
echo "health: $health"
case "$health" in
  *'"ok":true'*) ;;
  *) echo "HEALTH CHECK FAILED — Flask down? (missing dep → pip; serve wiped → tailscale serve --set-path /polarwatch 5057)"; exit 1;;
esac
if echo "$did" | grep -q build; then
  built=$(ls -t static/assets/index-*.js | head -1 | xargs basename)
  served=$(curl -s http://127.0.0.1:5057/polarwatch/ | grep -o 'index-[A-Za-z0-9_-]*\.js' | head -1)
  if [ "$built" = "$served" ]; then echo "✓ served bundle matches build ($built)"; else echo "WARN: served=$served != built=$built"; fi
fi
echo "✓ deploy complete"
