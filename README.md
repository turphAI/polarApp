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

Backend pipeline fully verified against real data: Polar OAuth (v4 Dynamic
API), Strava OAuth, activity pull, and heart-rate matching all confirmed
working end-to-end and deployed on the mini. Frontend UI for the
Strava-matched activity view hasn't been scoped/built yet — the existing
`frontend/` views (Today/History/Trend) were built against the earlier
24/7-heart-rate assumption and predate the pivot to activity-based tracking.
