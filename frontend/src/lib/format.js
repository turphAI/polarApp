// Shared formatting — English units (miles/feet), since Strava/Polar both
// give SI (meters). Converted at display time, not stored/transmitted
// converted, so the backend stays unit-agnostic.

const METERS_PER_MILE = 1609.344
const FEET_PER_METER = 3.28084

export function metersToMiles(m) {
  return m / METERS_PER_MILE
}

export function metersToFeet(m) {
  return m * FEET_PER_METER
}

export function formatDistance(m) {
  if (m == null) return '—'
  return `${metersToMiles(m).toFixed(1)} mi`
}

export function formatElevation(m) {
  if (m == null) return null
  return `+${Math.round(metersToFeet(m))} ft`
}

export function formatDuration(sec) {
  const h = Math.floor(sec / 3600)
  const m = Math.round((sec % 3600) / 60)
  return h > 0 ? `${h}h ${m}m` : `${m}m`
}

export function formatDate(iso) {
  return new Date(iso).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
}

// Strava's sport_type is a raw API enum (PascalCase, sometimes with the
// activity mode baked in redundantly — "MountainBikeRide"). Map the ones
// actually seen to plain labels; anything unmapped falls back to spacing
// out the PascalCase rather than showing the raw enum value untouched.
const SPORT_LABELS = {
  MountainBikeRide: 'Mountain Bike',
  EMountainBikeRide: 'E-Mountain Bike',
  EBikeRide: 'E-Bike',
  Ride: 'Bike Ride',
  VirtualRide: 'Virtual Ride',
  GravelRide: 'Gravel Ride',
  Run: 'Run',
  TrailRun: 'Trail Run',
  Walk: 'Walk',
  Hike: 'Hike',
}

export function formatSportType(sportType) {
  if (!sportType) return sportType
  return SPORT_LABELS[sportType] ?? sportType.replace(/([a-z])([A-Z])/g, '$1 $2')
}
