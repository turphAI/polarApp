<script>
  import { getHistory } from '../lib/api.js'

  let history = $state(null)   // null = loading
  let error = $state(null)
  let rangeDays = $state(30)

  const ranges = [
    { label: '30d', days: 30 },
    { label: '90d', days: 90 },
    { label: 'All', days: 3650 },
  ]

  async function load() {
    try {
      const res = await getHistory(rangeDays)
      history = res.history
      error = null
    } catch (e) {
      error = e.message
    }
  }

  // Re-fetches on mount (rangeDays read establishes the dependency) and again
  // whenever the range selector changes.
  $effect(() => { rangeDays; load() })

  // Chart geometry — hand-rolled inline SVG, no charting dependency.
  const W = 320
  const H = 160
  const PAD = 8

  const chart = $derived.by(() => {
    if (!history || history.length < 2) return null

    const allValues = history.flatMap((d) => [d.high, d.low])
    const min = Math.min(...allValues)
    const max = Math.max(...allValues)
    const range = Math.max(max - min, 1)

    const x = (i) => PAD + (i / (history.length - 1)) * (W - PAD * 2)
    const y = (v) => H - PAD - ((v - min) / range) * (H - PAD * 2)

    const bandPoints = [
      ...history.map((d, i) => `${x(i)},${y(d.high)}`),
      ...history.slice().reverse().map((d, i) => `${x(history.length - 1 - i)},${y(d.low)}`),
    ].join(' ')

    const avgLine = history.map((d, i) => `${x(i)},${y(d.avg)}`).join(' ')

    return { bandPoints, avgLine, min, max }
  })

  function formatShort(dateStr) {
    const d = new Date(dateStr + 'T00:00:00')
    return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
  }
</script>

<div class="page">
  <h1>History</h1>

  <div class="segmented">
    {#each ranges as r}
      <button class:active={rangeDays === r.days} onclick={() => rangeDays = r.days}>{r.label}</button>
    {/each}
  </div>

  {#if error}
    <div class="banner banner-error">{error}</div>
  {:else if history === null}
    <p class="muted">Loading…</p>
  {:else if history.length < 2}
    <div class="card empty-card">
      <p>Not enough history yet — check back after a few evenings of syncing.</p>
    </div>
  {:else}
    <div class="card chart-card">
      <svg viewBox="0 0 {W} {H}" class="chart">
        <polygon points={chart.bandPoints} fill="var(--color-accent)" opacity="0.12" />
        <polyline points={chart.avgLine} fill="none" stroke="var(--color-accent)" stroke-width="2"
                   stroke-linecap="round" stroke-linejoin="round" />
      </svg>
      <div class="chart-legend">
        <span>{chart.min} bpm</span>
        <span class="legend-note">shaded band = daily low–high, line = daily avg</span>
        <span>{chart.max} bpm</span>
      </div>
    </div>

    <div class="day-list">
      {#each history.slice().reverse() as d}
        <div class="day-row">
          <span class="day-date">{formatShort(d.date)}</span>
          <span class="day-stats">
            <span class="day-avg">{d.avg}</span>
            <span class="day-range">{d.low}–{d.high}</span>
          </span>
        </div>
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

  .muted { color: var(--color-secondary); }

  .segmented {
    display: flex;
    gap: var(--space-1);
  }

  .segmented button {
    flex: 1;
    min-height: 36px;
    background: var(--color-surface);
    border: 1px solid var(--color-border);
    border-radius: var(--radius-md);
    font-family: var(--font);
    font-size: 13px;
    color: var(--color-secondary);
    cursor: pointer;
  }

  .segmented button.active {
    color: var(--color-accent);
    border-color: var(--color-accent);
    font-weight: 600;
  }

  .chart-card {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .chart {
    width: 100%;
    height: auto;
  }

  .chart-legend {
    display: flex;
    justify-content: space-between;
    font-size: 11px;
    color: var(--color-muted);
  }

  .legend-note {
    flex: 1;
    text-align: center;
  }

  .empty-card {
    color: var(--color-secondary);
    text-align: center;
  }

  .day-list {
    display: flex;
    flex-direction: column;
    gap: 1px;
    background: var(--color-border);
    border: 1px solid var(--color-border);
    border-radius: var(--radius-md);
    overflow: hidden;
  }

  .day-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    background: var(--color-surface);
    padding: var(--space-2) var(--space-4);
  }

  .day-date {
    font-size: 13px;
    color: var(--color-secondary);
  }

  .day-stats {
    display: flex;
    align-items: baseline;
    gap: var(--space-2);
  }

  .day-avg {
    font-weight: 600;
  }

  .day-range {
    font-size: 12px;
    color: var(--color-muted);
  }
</style>
