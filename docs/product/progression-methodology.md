# How "Progression" is defined — and what it doesn't control for

This exists because a clean-looking chart can imply more than the data
supports, and this app may end up in front of a cardiologist. Read this
before drawing conclusions from the Progression view — or before adding to
it.

## What's actually plotted

Progression shows, per **matched** activity (see below), chronologically,
**one sport type at a time** (a segmented selector switches between
whichever sport types currently have matched sessions):

- **Elevation gain** (meters, from Strava) — the effort/difficulty proxy
- **Average heart rate** (bpm, from Polar, sliced to that activity's exact
  time window) — the physiological-response proxy

**Motor-assisted rides (`EBikeRide`, `EMountainBikeRide`) are excluded from
Progression entirely** (decided 2026-08-29) — elevation gain doesn't reflect
real cardiac effort when a motor is helping climb it, so including them
would be actively misleading, not just noisy. They still appear normally in
the Activities list with their real HR data; this exclusion is
Progression-specific (`frontend/src/routes/Progression.svelte`).

## Matched-only, by design (decided 2026-08-29)

**Only activities with both a Strava record and a real Polar heart-rate
match appear anywhere in the app** — Activities list and Progression alike.
There's no guarantee every Strava session has Polar coverage (predates
wearing the watch, watch hasn't synced yet, etc.), and an activity with no
HR data is simply not shown — not shown-with-a-placeholder. This is enforced
in `db.get_activities()` (`WHERE hr_avg IS NOT NULL`), not just hidden in
the UI.

## What this does NOT control for

Two of the original confounds identified here are now handled (sport-type
mixing and e-bike assist, both above) — these remain:

1. **Elevation gain alone doesn't capture steepness or how sustained the
   climbing was.** 500m gained over 30km (gradual) is a different cardiac
   load than 500m over 5km (steep, sustained) — same bar height on the
   chart, different actual demand.
2. **Weather isn't captured at all.** Heat and humidity raise heart rate at
   a given effort level (thermoregulatory load) — a hot day's elevated HR
   can look like a setback that's actually just the temperature. The app
   currently has no way to tell these apart.
3. **Day-to-day factors** — sleep, hydration, caffeine, fatigue, time since
   last meal — aren't in Strava or Polar's data at all, and are out of
   scope unless manually logged.

## What IS reasonably clean to read

The **per-session Activity Detail chart** (heart rate vs. elevation/grade
*within* one ride) is the trustworthy view: same day, same conditions, same
person, same effort — so HR visibly tracking terrain shape there is a real
physiological signal, not a cross-session comparison carrying the confounds
above. Progression is a rougher, second-order view; Activity Detail is the
one to trust first.

## Open questions — not decided, flagging for when they matter

- **Pull in historical weather?** A free, no-auth-key API exists
  (temperature/humidity by lat/lon + date — e.g. Open-Meteo's archive API).
  Would need Strava's `start_latlng` per activity (not currently stored —
  deliberately, to avoid anything map/route-shaped per the "no crazy map
  info" scope). Worth it once there's enough matched-session volume for
  weather variance to matter; premature with one matched session.

## Timeline note

Cardiologist-provided HR thresholds/zones expected **late October 2026** —
until then, charts show a plain HR curve with no reference lines. The data
model doesn't need to change to add them later (see `activity_detail.py`
and the Activity Detail chart) — just draw the line once a number exists.
