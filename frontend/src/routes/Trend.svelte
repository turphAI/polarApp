<script>
  import { onMount } from 'svelte'
  import { getTrend } from '../lib/api.js'

  let trend = $state(null)   // null = loading
  let error = $state(null)

  onMount(async () => {
    try {
      trend = await getTrend()
    } catch (e) {
      error = e.message
    }
  })

  const copy = {
    decreasing: { label: 'Decreasing', tone: 'good', note: 'Your resting heart rate has been trending down.' },
    increasing: { label: 'Increasing', tone: 'warn', note: 'Your resting heart rate has been trending up.' },
    stable:     { label: 'Stable', tone: 'neutral', note: "You're holding steady." },
  }
</script>

<div class="page">
  <h1>Trend</h1>

  {#if error}
    <div class="banner banner-error">{error}</div>
  {:else if trend === null}
    <p class="muted">Loading…</p>
  {:else if trend.status === 'not_enough_data'}
    <div class="card empty-card">
      <p>Not enough history yet to call a trend — needs at least a couple of weeks of evening syncs.</p>
    </div>
  {:else}
    {@const c = copy[trend.status]}
    <div class="card trend-card tone-{c.tone}">
      <span class="trend-label">{c.label}</span>
      <div class="trend-delta">
        {trend.delta > 0 ? '+' : ''}{trend.delta} <span class="unit">bpm avg</span>
      </div>
      <p class="trend-note">{c.note}</p>
    </div>

    <div class="stats-row">
      <div class="card stat">
        <span class="stat-label">Last {trend.recent_days} days</span>
        <span class="stat-value">{trend.recent_avg}</span>
      </div>
      <div class="card stat">
        <span class="stat-label">Prior {trend.prior_days} days</span>
        <span class="stat-value">{trend.prior_avg}</span>
      </div>
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

  .muted { color: var(--color-secondary); }

  .empty-card {
    color: var(--color-secondary);
    text-align: center;
  }

  .trend-card {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-8) var(--space-5);
    text-align: center;
  }

  .trend-label {
    font-size: 14px;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    font-weight: 600;
  }

  .trend-delta {
    font-size: 40px;
    font-weight: 700;
    line-height: 1;
  }

  .unit {
    font-size: 14px;
    font-weight: 400;
    color: var(--color-secondary);
  }

  .trend-note {
    color: var(--color-secondary);
    font-size: 14px;
  }

  .tone-good .trend-label, .tone-good .trend-delta { color: var(--color-good); }
  .tone-warn .trend-label, .tone-warn .trend-delta { color: var(--color-warn); }
  .tone-neutral .trend-label, .tone-neutral .trend-delta { color: var(--color-secondary); }

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
</style>
