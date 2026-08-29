<script>
  import { onMount } from 'svelte'
  import { getActivities, syncStravaNow } from '../lib/api.js'

  /** @type {(stravaId: number) => void} */
  let { onSelect } = $props()

  let activities = $state(null)   // null = loading
  let error = $state(null)
  let syncing = $state(false)

  async function load() {
    try {
      const res = await getActivities(50)
      activities = res.activities
      error = null
    } catch (e) {
      error = e.message
    }
  }

  async function syncNow() {
    syncing = true
    try {
      await syncStravaNow()
      await load()
    } catch (e) {
      error = e.message
    } finally {
      syncing = false
    }
  }

  onMount(load)

  function formatDate(iso) {
    return new Date(iso).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
  }

  function formatDistance(m) {
    if (m == null) return '—'
    return `${(m / 1000).toFixed(1)} km`
  }

  function formatElevation(m) {
    if (m == null) return null
    return `+${Math.round(m)} m`
  }

  function formatDuration(sec) {
    const h = Math.floor(sec / 3600)
    const m = Math.round((sec % 3600) / 60)
    return h > 0 ? `${h}h ${m}m` : `${m}m`
  }
</script>

<div class="page">
  <div class="header-row">
    <h1>Activities</h1>
    <button class="btn-link" onclick={syncNow} disabled={syncing}>
      {syncing ? 'Syncing…' : 'Sync now'}
    </button>
  </div>

  {#if error}
    <div class="banner banner-error">{error}</div>
  {/if}

  {#if activities === null}
    <p class="muted">Loading…</p>
  {:else if activities.length === 0}
    <div class="card empty-card">
      <p>No activities yet. Tap "Sync now" to pull recent Strava activities.</p>
    </div>
  {:else}
    <div class="activity-list">
      {#each activities as a}
        <button class="activity-row" onclick={() => onSelect(a.strava_id)}>
          <div class="activity-main">
            <span class="activity-name">{a.name}</span>
            <span class="activity-meta">
              {formatDate(a.start_date_utc)} · {a.sport_type} · {formatDuration(a.elapsed_time_sec)}
              · {formatDistance(a.distance_m)}
              {#if formatElevation(a.elevation_gain_m)} · {formatElevation(a.elevation_gain_m)}{/if}
            </span>
          </div>
          {#if a.hr_avg != null}
            <div class="activity-hr">
              <span class="hr-avg">{a.hr_avg}</span>
              <span class="hr-unit">avg bpm</span>
            </div>
          {:else}
            <span class="no-hr">no HR data</span>
          {/if}
        </button>
      {/each}
    </div>
  {/if}
</div>

<style>
  .page {
    padding: var(--space-6) var(--space-4);
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
  }

  .header-row {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
  }

  .btn-link {
    background: none;
    border: none;
    color: var(--color-accent);
    font-family: var(--font);
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
  }

  .btn-link:disabled {
    opacity: 0.5;
    cursor: default;
  }

  .muted { color: var(--color-secondary); }

  .empty-card {
    color: var(--color-secondary);
    text-align: center;
  }

  .activity-list {
    display: flex;
    flex-direction: column;
    gap: 1px;
    background: var(--color-border);
    border: 1px solid var(--color-border);
    border-radius: var(--radius-md);
    overflow: hidden;
  }

  .activity-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-3);
    background: var(--color-surface);
    border: none;
    padding: var(--space-3) var(--space-4);
    text-align: left;
    cursor: pointer;
    -webkit-tap-highlight-color: transparent;
    font-family: var(--font);
    color: var(--color-text);
  }

  .activity-main {
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 0;
  }

  .activity-name {
    font-weight: 600;
    font-size: 15px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .activity-meta {
    font-size: 12px;
    color: var(--color-secondary);
  }

  .activity-hr {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    flex-shrink: 0;
  }

  .hr-avg {
    font-size: 18px;
    font-weight: 700;
    color: var(--color-accent);
  }

  .hr-unit {
    font-size: 10px;
    color: var(--color-muted);
  }

  .no-hr {
    font-size: 11px;
    color: var(--color-muted);
    flex-shrink: 0;
  }
</style>
