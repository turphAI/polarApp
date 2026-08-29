<script>
  import { onMount } from 'svelte'
  import { getActivities, syncStravaNow } from '../lib/api.js'
  import { formatDate, formatDistance, formatElevation, formatDuration, formatSportType } from '../lib/format.js'

  // sportFilter is hoisted to App.svelte and bound down (bindable), same
  // precedent as the hiking app's NH/ADK range toggle — so it survives a
  // trip into activity detail and back, instead of resetting.
  /** @type {{ onSelect: (stravaId: number) => void, sportFilter: string }} */
  let { onSelect, sportFilter = $bindable('All') } = $props()

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

  // Unlike Progression, mixing sport types in a plain list isn't statistically
  // misleading (each row already labels its own sport) — so "All" is a sensible
  // default here, unlike Progression's per-sport-only segmented control.
  const sportTypes = $derived(
    activities ? ['All', ...[...new Set(activities.map((a) => a.sport_type))].sort()] : []
  )
  const filteredActivities = $derived(
    activities ? activities.filter((a) => sportFilter === 'All' || a.sport_type === sportFilter) : []
  )
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
    {#if sportTypes.length > 2}
      <div class="segmented">
        {#each sportTypes as sport}
          <button class:active={sportFilter === sport} onclick={() => sportFilter = sport}>
            {sport === 'All' ? 'All' : formatSportType(sport)}
          </button>
        {/each}
      </div>
    {/if}

    {#if filteredActivities.length === 0}
      <div class="card empty-card">
        <p>No {sportFilter === 'All' ? '' : formatSportType(sportFilter) + ' '}activities.</p>
      </div>
    {/if}

    <div class="activity-list">
      {#each filteredActivities as a}
        <button class="activity-row" onclick={() => onSelect(a.strava_id)}>
          <div class="activity-main">
            <span class="activity-name">{a.name}</span>
            <span class="activity-meta">
              {formatDate(a.start_date_utc)} · {formatSportType(a.sport_type)} · {formatDuration(a.elapsed_time_sec)}
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

  .segmented {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-1);
  }

  .segmented button {
    flex: 1 1 auto;
    min-height: 36px;
    padding: 0 var(--space-3);
    background: var(--color-surface);
    border: 1px solid var(--color-border);
    border-radius: var(--radius-md);
    font-family: var(--font);
    font-size: 14px;
    color: var(--color-secondary);
    cursor: pointer;
  }

  .segmented button.active {
    color: var(--color-accent);
    border-color: var(--color-accent);
    font-weight: 600;
  }

  .btn-link {
    background: none;
    border: none;
    color: var(--color-accent);
    font-family: var(--font);
    font-size: 15px;
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
    font-size: 16px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .activity-meta {
    font-size: 13px;
    color: var(--color-secondary);
  }

  .activity-hr {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    flex-shrink: 0;
  }

  .hr-avg {
    font-size: 19px;
    font-weight: 700;
    color: var(--color-accent);
  }

  .hr-unit {
    font-size: 11px;
    color: var(--color-muted);
  }

  .no-hr {
    font-size: 12px;
    color: var(--color-muted);
    flex-shrink: 0;
  }
</style>
