"""
SQLite storage for polarWatch — single-user, so `oauth_token` is a one-row
table rather than keyed by user. `heart_rate_daily` is the permanent history:
one row per evening sync, written before Polar's own ~30-day retention would
drop that day's data.
"""
import sqlite3
import time
from contextlib import contextmanager

from config import DATA_DIR, DB_PATH

SCHEMA = """
CREATE TABLE IF NOT EXISTS oauth_token (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    access_token TEXT NOT NULL,
    refresh_token TEXT NOT NULL,
    expires_at REAL NOT NULL,     -- unix timestamp
    polar_user_id TEXT,
    connected_at REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS heart_rate_daily (
    date TEXT PRIMARY KEY,        -- YYYY-MM-DD
    high INTEGER NOT NULL,
    low INTEGER NOT NULL,
    avg INTEGER NOT NULL,
    latest INTEGER NOT NULL,      -- last sample of the day, i.e. the "evening ping"
    sample_count INTEGER NOT NULL,
    synced_at REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS sync_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ran_at REAL NOT NULL,
    ok INTEGER NOT NULL,
    detail TEXT
);
"""


def init_db():
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    with connect() as conn:
        conn.executescript(SCHEMA)


@contextmanager
def connect():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


# --- oauth_token ---------------------------------------------------------

def save_token(access_token, refresh_token, expires_at, polar_user_id=None):
    with connect() as conn:
        conn.execute(
            """
            INSERT INTO oauth_token (id, access_token, refresh_token, expires_at, polar_user_id, connected_at)
            VALUES (1, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                access_token = excluded.access_token,
                refresh_token = excluded.refresh_token,
                expires_at = excluded.expires_at,
                polar_user_id = COALESCE(excluded.polar_user_id, oauth_token.polar_user_id)
            """,
            (access_token, refresh_token, expires_at, polar_user_id, time.time()),
        )


def get_token():
    with connect() as conn:
        row = conn.execute("SELECT * FROM oauth_token WHERE id = 1").fetchone()
        return dict(row) if row else None


def clear_token():
    with connect() as conn:
        conn.execute("DELETE FROM oauth_token WHERE id = 1")


# --- heart_rate_daily ------------------------------------------------------

def upsert_daily(date, high, low, avg, latest, sample_count):
    with connect() as conn:
        conn.execute(
            """
            INSERT INTO heart_rate_daily (date, high, low, avg, latest, sample_count, synced_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(date) DO UPDATE SET
                high = excluded.high, low = excluded.low, avg = excluded.avg,
                latest = excluded.latest, sample_count = excluded.sample_count,
                synced_at = excluded.synced_at
            """,
            (date, high, low, avg, latest, sample_count, time.time()),
        )


def get_daily(date):
    with connect() as conn:
        row = conn.execute("SELECT * FROM heart_rate_daily WHERE date = ?", (date,)).fetchone()
        return dict(row) if row else None


def get_history(days):
    with connect() as conn:
        rows = conn.execute(
            "SELECT * FROM heart_rate_daily ORDER BY date DESC LIMIT ?", (days,)
        ).fetchall()
        return [dict(r) for r in rows][::-1]  # chronological order


def get_latest_daily():
    with connect() as conn:
        row = conn.execute(
            "SELECT * FROM heart_rate_daily ORDER BY date DESC LIMIT 1"
        ).fetchone()
        return dict(row) if row else None


# --- sync_log --------------------------------------------------------------

def log_sync(ok, detail=""):
    with connect() as conn:
        conn.execute(
            "INSERT INTO sync_log (ran_at, ok, detail) VALUES (?, ?, ?)",
            (time.time(), 1 if ok else 0, detail),
        )


def get_last_sync():
    with connect() as conn:
        row = conn.execute("SELECT * FROM sync_log ORDER BY ran_at DESC LIMIT 1").fetchone()
        return dict(row) if row else None
