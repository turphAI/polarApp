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

/** @returns {Promise<{date: string|null, data: object|null, is_today: boolean}>} */
export function getToday() {
  return getJson(api('heart-rate/today'))
}

/** @returns {Promise<{days: number, history: object[]}>} */
export function getHistory(days = 90) {
  return getJson(api(`heart-rate/history?days=${days}`))
}

/** @returns {Promise<{status: string, recent_avg: number|null, prior_avg: number|null, delta: number|null}>} */
export function getTrend() {
  return getJson(api('heart-rate/trend'))
}

/** Trigger an on-demand sync for today (or a given date). */
export function syncNow(dateStr) {
  const q = dateStr ? `?date=${dateStr}` : ''
  return postJson(api(`sync/now${q}`))
}
