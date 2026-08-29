# polarWatch

A personal heart-rate PWA. Activities are tracked in Strava; the Polar watch
is worn passively alongside purely for heart rate. This app matches the two:
pulls your Strava activity list, then slices Polar's heart-rate data down to
each activity's time window.

See [CLAUDE.md](CLAUDE.md) for architecture and the (considerable) Polar API
gotchas discovered building this, and [DEPLOY.md](DEPLOY.md) for how it runs
on the mini.

## Structure

```
backend/     Flask API, SQLite, Polar + Strava OAuth clients, activity matching
frontend/    Svelte + Vite PWA
docs/        Polar's legal docs, original product brief
polarView/   Abandoned native-iOS attempt — superseded, kept for history
```

## Status

Full pipeline verified against real data and deployed on the mini: Polar
OAuth (v4 Dynamic API), Strava OAuth, activity pull, heart-rate matching,
and the UI itself — three views:

- **Activities** — list of Strava activities, matched HR summary where available
- **Activity Detail** — the core view: heart rate plotted against the
  elevation/grade profile on a shared time axis, to see how HR actually
  responds to climbs vs. descents during a session
- **Progression** — elevation gain per session vs. average HR over time, to
  track building up distance/difficulty safely post-ablation

`backend/sync.py` and the daily `heart_rate_daily` rollup (`/api/heart-rate/*`)
still run too — not part of this UI's navigation, but still the mechanism
that preserves HR history beyond Polar's ~30-day retention window.
