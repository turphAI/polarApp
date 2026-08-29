// Thin fetch wrappers, same shape as witness's api.js. Paths are based on
// import.meta.env.BASE_URL ('/polarwatch/' in production, '/' in dev).

const BASE = import.meta.env.BASE_URL
const api = (p) => `${BASE}api/${p}`

async function getJson(path) {
  const resp = await fetch(path, { headers: { Accept: 'application/json' } })
  if (!resp.ok) {
    throw new Error(`${path} → ${resp.status}`)
  }
  return resp.json()
}

async function postJson(path) {
  const resp = await fetch(path, { method: 'POST' })
  if (!resp.ok) {
    const text = await resp.text().catch(() => '')
    throw new Error(`POST ${path} → ${resp.status} ${text}`)
  }
  return resp.json()
}

/** @returns {Promise<{connected: boolean, polar_user_id: string|null, connected_at: number|null, last_sync: object|null}>} */
export function getAuthStatus() {
  return getJson(api('auth/status'))
}

/** Full-page redirect to start the Polar OAuth dance. */
export function startAuth() {
  window.location.href = api('auth/start')
}

/** @returns {Promise<{connected: boolean, athlete_id: string|null, connected_at: number|null}>} */
export function getStravaAuthStatus() {
  return getJson(api('strava/status'))
}

/** Full-page redirect to start the Strava OAuth dance. */
export function startStravaAuth() {
  window.location.href = api('strava/auth/start')
}

/** @returns {Promise<{activities: object[]}>} */
export function getActivities(limit = 50) {
  return getJson(api(`activities?limit=${limit}`))
}

/**
 * Merged per-activity series: heart rate matched to Strava's elevation/grade
 * streams on a shared elapsed-time axis. heart_rate is null on points
 * outside Polar's data coverage.
 * @returns {Promise<{name: string, sport_type: string, elapsed_time_sec: number,
 *   distance_m: number, elevation_gain_m: number|null, hr_high: number|null,
 *   hr_low: number|null, hr_avg: number|null, has_heart_rate: boolean,
 *   points: {t_sec: number, altitude_m: number|null, grade_pct: number|null, heart_rate: number|null}[]}>}
 */
export function getActivityDetail(stravaId) {
  return getJson(api(`activities/${stravaId}/detail`))
}

/** Pull recent Strava activities and attempt HR matching against Polar data. */
export function syncStravaNow(days = 30) {
  return postJson(api(`strava/sync/now?days=${days}`))
}
