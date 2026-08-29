<script>
  import { onMount } from 'svelte'
  import { getActivities } from '../lib/api.js'

  let activities = $state(null)   // null = loading
  let error = $state(null)

  onMount(async () => {
    try {
      const res = await getActivities(50)
      // Chronological — oldest first, so the chart reads left-to-right as
      // "building up over time," matching how the user actually thinks
      // about progression.
      activities = res.activities.slice().reverse()
      error = null
    } catch (e) {
      error = e.message
    }
  })

  const W = 340
  const H = 200
  const PAD = 6
  const BAR_GAP = 3

  const chart = $derived.by(() => {
    if (!activities || activities.length < 2) return null

    const n = activities.length
    const barW = (W - PAD * 2) / n - BAR_GAP
    const xCenter = (i) => PAD + i * ((W - PAD * 2) / n) + ((W - PAD * 2) / n) / 2

    const elevValues = activities.map((a) => a.elevation_gain_m ?? 0)
    const maxElev = Math.max(...elevValues, 1)
    const barHeight = (elev) => (elev / maxElev) * (H - PAD * 2)

    const hrActivities = activities
      .map((a, i) => ({ i, hr: a.hr_avg }))
      .filter((d) => d.hr != null)
    const hasHr = hrActivities.length > 1
    let hrPath = ''
    let minHr, maxHr
    if (hasHr) {
      const hrValues = hrActivities.map((d) => d.hr)
      minHr = Math.min(...hrValues)
      maxHr = Math.max(...hrValues)
      const hrRange = Math.max(maxHr - minHr, 1)
      const yHr = (hr) => H - PAD - ((hr - minHr) / hrRange) * (H - PAD * 2)
      hrPath = hrActivities.map((d) => `${xCenter(d.i)},${yHr(d.hr)}`).join(' L ')
    }

    return {
      bars: activities.map((a, i) => ({
        x: PAD + i * ((W - PAD * 2) / n) + BAR_GAP / 2,
        w: barW,
        h: barHeight(a.elevation_gain_m ?? 0),
        matched: a.hr_avg != null,
      })),
      hrPath: hasHr ? `M ${hrPath}` : '',
      hasHr,
      hrDots: hasHr ? hrActivities.map((d) => {
        const hrRange = Math.max(maxHr - minHr, 1)
        return { x: xCenter(d.i), y: H - PAD - ((d.hr - minHr) / hrRange) * (H - PAD * 2) }
      }) : [],
    }
  })

  function formatDate(iso) {
    return new Date(iso).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
  }
</script>

<div class="page">
  <h1>Progression</h1>
  <p class="subtitle">Elevation gain per session (bars) vs. average heart rate (line) — building up distance/difficulty over time.</p>

  {#if error}
    <div class="banner banner-error">{error}</div>
  {:else if activities === null}
    <p class="muted">Loading…</p>
  {:else if activities.length < 2}
    <div class="card empty-card">
      <p>Not enough sessions yet to show progression — needs at least a couple.</p>
    </div>
  {:else if chart}
    <div class="card chart-card">
      <svg viewBox="0 0 {W} {H}" class="chart">
        {#each chart.bars as bar}
          <rect x={bar.x} y={H - PAD - bar.h} width={bar.w} height={bar.h}
                fill="var(--color-secondary)" opacity={bar.matched ? 0.35 : 0.15} rx="1" />
        {/each}
        {#if chart.hasHr}
          <path d={chart.hrPath} fill="none" stroke="var(--color-accent)" stroke-width="2"
                stroke-linecap="round" stroke-linejoin="round" />
          {#each chart.hrDots as dot}
            <circle cx={dot.x} cy={dot.y} r="2.5" fill="var(--color-accent)" />
          {/each}
        {/if}
      </svg>
      <div class="chart-legend">
        <span class="legend-item"><span class="swatch swatch-elev"></span>Elevation gain</span>
        <span class="legend-item"><span class="swatch swatch-hr"></span>Avg heart rate</span>
      </div>
    </div>

    <div class="session-list">
      {#each activities as a}
        <div class="session-row">
          <span class="session-date">{formatDate(a.start_date_utc)}</span>
          <span class="session-name">{a.name}</span>
          <span class="session-stats">
            {a.elevation_gain_m != null ? `+${Math.round(a.elevation_gain_m)}m` : '—'}
            {#if a.hr_avg != null}· <span class="hr">{a.hr_avg} bpm</span>{/if}
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

  .subtitle {
    color: var(--color-secondary);
    font-size: 13px;
    margin-top: -8px;
  }

  .muted { color: var(--color-secondary); }

  .empty-card {
    color: var(--color-secondary);
    text-align: center;
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
    justify-content: center;
    gap: var(--space-4);
    font-size: 11px;
    color: var(--color-muted);
  }

  .legend-item {
    display: flex;
    align-items: center;
    gap: 4px;
  }

  .swatch {
    width: 10px;
    height: 10px;
    border-radius: 2px;
  }

  .swatch-elev {
    background: var(--color-secondary);
    opacity: 0.35;
  }

  .swatch-hr {
    background: var(--color-accent);
  }

  .session-list {
    display: flex;
    flex-direction: column;
    gap: 1px;
    background: var(--color-border);
    border: 1px solid var(--color-border);
    border-radius: var(--radius-md);
    overflow: hidden;
  }

  .session-row {
    display: flex;
    align-items: baseline;
    gap: var(--space-2);
    background: var(--color-surface);
    padding: var(--space-2) var(--space-4);
    font-size: 12px;
  }

  .session-date {
    color: var(--color-secondary);
    flex-shrink: 0;
  }

  .session-name {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .session-stats {
    color: var(--color-secondary);
    flex-shrink: 0;
  }

  .session-stats .hr {
    color: var(--color-accent);
    font-weight: 600;
  }
</style>
