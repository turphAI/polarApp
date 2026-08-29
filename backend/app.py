"""
polarWatch Flask API.

Serves the built PWA (static/) plus a small JSON API. Actual data collection
happens in sync.py (run daily by launchd, see infra/launchd/) — this process
only reads what's already in SQLite, except for the on-demand /api/sync/now
and the OAuth connect flow.

Served under /polarwatch on the tailnet (tailscale serve mounts it there;
turph owns the root). Every route is dual-mounted under both the bare path
and a /polarwatch-prefixed path, same pattern as witness's app.py, so it
resolves whether tailscale strips the mount prefix or preserves it.
"""
import os
import secrets
from datetime import date, timedelta
from pathlib import Path

from flask import Flask, jsonify, redirect, request, session, send_from_directory

import config
import db
import polar_client
import sync as sync_module
from polar_client import PolarAPIError, PolarAuthError

PROJECT_ROOT = Path(__file__).resolve().parent.parent
STATIC_DIR = PROJECT_ROOT / "static"

app = Flask(__name__)
# Only needed transiently to hold the OAuth `state` nonce across the redirect
# round-trip — fine to regenerate on every process restart.
app.secret_key = secrets.token_hex(32)

db.init_db()


def _route(method, rule, **opts):
    """Register a view under both `rule` and `/polarwatch` + `rule`."""
    def decorator(fn):
        app.add_url_rule(rule, f"{fn.__name__}_bare", fn, methods=[method], **opts)
        app.add_url_rule(f"/polarwatch{rule}", f"{fn.__name__}_prefixed", fn, methods=[method], **opts)
        return fn
    return decorator


# --- health / status ---------------------------------------------------

@_route("GET", "/api/health")
def health():
    return jsonify({"ok": True, "service": "polarwatch", "matched_path": request.path})


@_route("GET", "/api/auth/status")
def auth_status():
    token = db.get_token()
    last_sync = db.get_last_sync()
    return jsonify({
        "connected": token is not None,
        "polar_user_id": token.get("polar_user_id") if token else None,
        "connected_at": token.get("connected_at") if token else None,
        "last_sync": last_sync,
    })


# --- OAuth connect flow --------------------------------------------------

@_route("GET", "/api/auth/start")
def auth_start():
    state = secrets.token_urlsafe(16)
    session["oauth_state"] = state
    return redirect(polar_client.authorize_url(state))


@_route("GET", "/api/auth/callback")
def auth_callback():
    error = request.args.get("error")
    if error:
        return jsonify({"ok": False, "error": error}), 400

    code = request.args.get("code")
    returned_state = request.args.get("state")
    expected_state = session.pop("oauth_state", None)

    if not code:
        return jsonify({"ok": False, "error": "no_authorization_code"}), 400
    if not expected_state or returned_state != expected_state:
        return jsonify({"ok": False, "error": "state_mismatch"}), 400

    try:
        polar_client.exchange_code(code)
    except PolarAuthError as e:
        return jsonify({"ok": False, "error": str(e)}), 502

    # Land back on the app's root so the frontend re-checks auth status.
    mount = "/polarwatch" if request.path.startswith("/polarwatch") else ""
    return redirect(f"{mount}/?connected=1")


# --- data -----------------------------------------------------------------

@_route("GET", "/api/heart-rate/today")
def heart_rate_today():
    today = db.get_daily(date.today().isoformat())
    if today:
        return jsonify({"date": today["date"], "data": today, "is_today": True})

    latest = db.get_latest_daily()
    if latest:
        return jsonify({"date": latest["date"], "data": latest, "is_today": False})

    return jsonify({"date": None, "data": None, "is_today": False})


@_route("GET", "/api/heart-rate/history")
def heart_rate_history():
    days = request.args.get("days", default=90, type=int)
    return jsonify({"days": days, "history": db.get_history(days)})


@_route("GET", "/api/heart-rate/trend")
def heart_rate_trend():
    recent_n = config.TREND_RECENT_DAYS
    prior_n = config.TREND_PRIOR_DAYS
    history = db.get_history(recent_n + prior_n)

    if len(history) < 2:
        return jsonify({"status": "not_enough_data", "recent_avg": None, "prior_avg": None, "delta": None})

    recent = history[-recent_n:]
    prior = history[:-recent_n][-prior_n:] if len(history) > recent_n else []

    recent_avg = round(sum(d["avg"] for d in recent) / len(recent), 1)

    if not prior:
        return jsonify({
            "status": "not_enough_data", "recent_avg": recent_avg, "prior_avg": None, "delta": None,
        })

    prior_avg = round(sum(d["avg"] for d in prior) / len(prior), 1)
    delta = round(recent_avg - prior_avg, 1)

    if abs(delta) < config.TREND_STABLE_THRESHOLD_BPM:
        status = "stable"
    elif delta > 0:
        status = "increasing"
    else:
        status = "decreasing"

    return jsonify({
        "status": status, "recent_avg": recent_avg, "prior_avg": prior_avg, "delta": delta,
        "recent_days": len(recent), "prior_days": len(prior),
    })


@_route("POST", "/api/sync/now")
def sync_now():
    for_date_str = request.args.get("date")
    for_date = date.fromisoformat(for_date_str) if for_date_str else date.today()
    try:
        ok = sync_module.run(for_date)
    except Exception as e:  # noqa: BLE001 — surface any unexpected failure to the caller
        return jsonify({"ok": False, "error": str(e)}), 500
    status_code = 200 if ok else 502
    return jsonify({"ok": ok, "date": for_date.isoformat()}), status_code


# --- static SPA -------------------------------------------------------

@app.route("/")
@app.route("/polarwatch/")
@app.route("/<path:path>")
@app.route("/polarwatch/<path:path>")
def spa(path="index.html"):
    full = STATIC_DIR / path
    if full.is_file():
        return send_from_directory(STATIC_DIR, path)
    return send_from_directory(STATIC_DIR, "index.html")


if __name__ == "__main__":
    host = os.environ.get("POLARWATCH_HOST", "127.0.0.1")
    port = int(os.environ.get("POLARWATCH_PORT", "5057"))
    app.run(host=host, port=port)
