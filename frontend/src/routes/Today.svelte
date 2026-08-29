<script>
  import { onMount } from 'svelte'
  import { getToday, syncNow } from '../lib/api.js'

  let today = $state(null)      // null = loading
  let error = $state(null)
  let syncing = $state(false)

  async function load() {
    try {
      today = await getToday()
      error = null
    } catch (e) {
      error = e.message
    }
  }

  async function checkNow() {
    syncing = true
    try {
      await syncNow()
      await load()
    } catch (e) {
      error = e.message
    } finally {
      syncing = false
    }
  }

  onMount(load)

  function formatDate(dateStr) {
    if (!dateStr) return ''
    const d = new Date(dateStr + 'T00:00:00')
    return d.toLocaleDateString(undefined, { weekday: 'long', month: 'short', day: 'numeric' })
  }
</script>

<div class="page">
  <h1>Today</h1>

  {#if error}
    <div class="banner banner-error">{error}</div>
  {/if}

  {#if today === null}
    <p class="muted">Loading…</p>
  {:else if !today.data}
    <div class="card empty-card">
      <p>No heart rate data yet. The evening sync hasn't run, or your watch hasn't synced to Polar Flow.</p>
      <button class="btn" onclick={checkNow} disabled={syncing}>
        {syncing ? 'Checking…' : 'Check now'}
      </button>
    </div>
  {:else}
    <p class="as-of">
      {today.is_today ? "As of tonight's sync" : `Last reading: ${formatDate(today.date)}`}
    </p>

    <div class="card latest-card">
      <span class="latest-label">Latest reading</span>
      <div class="latest-value">
        <span class="bpm">{today.data.latest}</span>
        <span class="unit">bpm</span>
      </div>
    </div>

    <div class="stats-row">
      <div class="card stat">
        <span class="stat-label">High</span>
        <span class="stat-value high">{today.data.high}</span>
      </div>
      <div class="card stat">
        <span class="stat-label">Low</span>
        <span class="stat-value low">{today.data.low}</span>
      </div>
      <div class="card stat">
        <span class="stat-label">Avg</span>
        <span class="stat-value">{today.data.avg}</span>
      </div>
    </div>

    <button class="btn btn-secondary check-now" onclick={checkNow} disabled={syncing}>
      {syncing ? 'Checking…' : 'Check now'}
    </button>
  {/if}
</div>

<style>
  .page {
    padding: var(--space-6) var(--space-4);
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
  }

  .muted {
    color: var(--color-secondary);
  }

  .as-of {
    color: var(--color-secondary);
    font-size: 13px;
  }

  .latest-card {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-8) var(--space-5);
  }

  .latest-label {
    color: var(--color-secondary);
    font-size: 13px;
  }

  .latest-value {
    display: flex;
    align-items: baseline;
    gap: var(--space-2);
  }

  .bpm {
    font-size: 56px;
    font-weight: 700;
    color: var(--color-accent);
    line-height: 1;
  }

  .unit {
    font-size: 18px;
    color: var(--color-secondary);
  }

  .stats-row {
    display: flex;
    gap: var(--space-3);
  }

  .stat {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-1);
    padding: var(--space-4);
  }

  .stat-label {
    font-size: 12px;
    color: var(--color-secondary);
  }

  .stat-value {
    font-size: 22px;
    font-weight: 600;
  }

  .stat-value.high { color: var(--color-accent); }
  .stat-value.low { color: var(--color-good); }

  .empty-card {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    text-align: center;
    color: var(--color-secondary);
  }

  .check-now {
    align-self: center;
  }
</style>
