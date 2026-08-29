#!/usr/bin/env python3
"""
Standalone daily sync — no Flask process needed. Run once an evening
(launchd StartCalendarInterval, see infra/launchd/com.polarwatch.sync.plist)
to pull that day's heart rate and save a permanent row before Polar's own
~30-day retention would drop it.

Usage:
    python sync.py                # syncs today
    python sync.py --date 2026-08-20
"""
import argparse
import sys
from datetime import date

import db
import polar_client
from polar_client import PolarAPIError, PolarAuthError


def run(for_date: date) -> bool:
    db.init_db()
    try:
        result = polar_client.get_daily_summary(for_date)
    except PolarAuthError as e:
        db.log_sync(ok=False, detail=f"auth: {e}")
        print(f"❌ Auth failed — reconnect to Polar: {e}", file=sys.stderr)
        return False
    except PolarAPIError as e:
        db.log_sync(ok=False, detail=f"api: {e}")
        print(f"❌ Polar API error: {e}", file=sys.stderr)
        return False

    if result is None:
        # Not an error — the watch may not have synced to Polar Flow yet today.
        db.log_sync(ok=True, detail=f"no data for {for_date.isoformat()}")
        print(f"ℹ️ No heart rate data available for {for_date.isoformat()} yet.")
        return True

    high, low, avg, latest, sample_count = result
    db.upsert_daily(for_date.isoformat(), high, low, avg, latest, sample_count)
    db.log_sync(ok=True, detail=f"{for_date.isoformat()}: {sample_count} samples")
    print(f"✅ {for_date.isoformat()}: high={high} low={low} avg={avg} latest={latest} ({sample_count} samples)")
    return True


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--date", type=date.fromisoformat, default=date.today())
    args = parser.parse_args()
    ok = run(args.date)
    sys.exit(0 if ok else 1)
