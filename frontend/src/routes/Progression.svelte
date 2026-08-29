<script>
  import { onMount } from 'svelte'
  import { getActivities } from '../lib/api.js'

  // Motor-assisted sport types are excluded from Progression entirely (not
  // just de-emphasized): elevation gain doesn't reflect real cardiac effort
  // when a motor is helping climb it, so mixing them into an effort-vs-
  // elevation trend would be actively misleading, not just noisy. They
  // still show normally in the Activities list — this exclusion is
  // Progression-specific. See docs/product/progression-methodology.md.
  const MOTOR_ASSISTED_SPORT_TYPES = new Set(['EBikeRide', 'EMountainBikeRide'])

  let rawActivities = $state(null)   // null = loading
  let error = $state(null)
  let selectedSport = $state(null)

  onMount(async () => {
    try {
      const res = await getActivities(50)
      rawActivities = res.activities
      error = null
    } catch (e) {
      error = e.message
    }
  })

  // Sport types are mixed by default here on purpose ONLY within this
  // derivation step — the chart itself always shows a single sport type at
  // a time (see `filtered` below). Comparing HR response across sport
  // types (a bike interval effort profile vs. a walk's steady state) would
  // conflate a real effort-mode difference with an actual trend.
  const nonMotorActivities = $derived(
    (rawActivities ?? []).filter((a) => !MOTOR_ASSISTED_SPORT_TYPES.has(a.sport_type))
  )

  const sportTypes = $derived([...new Set(nonMotorActivities.map((a) => a.sport_type))].sort())

  $effect(() => {
    if (sportTypes.length && !sportTypes.includes(selectedSport)) {
      selectedSport = sportTypes[0]
    }
  })

  // Chronological — oldest first, so the chart reads left-to-right as
  // "building up over time," matching how the user actually thinks about it.
  const filtered = $derived(
    nonMotorActivities.filter((a) => a.sport_type === selectedSport).slice().reverse()
  )

  const W = 340
  const H = 200
  const PAD = 6
  const BAR_GAP = 3

  const chart = $derived.by(() => {
    if (filtered.length < 2) return null

    const n = filtered.length
    const barW = (W - PAD * 2) / n - BAR_GAP
    const xCenter = (i) => PAD + i * ((W - PAD * 2) / n) + ((W - PAD * 2) / n) / 2

    const elevValues = filtered.map((a) => a.elevation_gain_m ?? 0)
    const maxElev = Math.max(...elevValues, 1)
    const barHeight = (elev) => (elev / maxElev) * (H - PAD * 2)

    // Every activity here always has hr_avg (db.get_activities filters to
    // matched-only), so this is really just building the line's points —
    // the length-check is only for the degenerate n<2 "can't draw a line" case.
    const hrValues = filtered.map((a) => a.hr_avg)
    const minHr = Math.min(...hrValues)
    const maxHr = Math.max(...hrValues)
    const hrRange = Math.max(maxHr - minHr, 1)
    const yHr = (hr) => H - PAD - ((hr - minHr) / hrRange) * (H - PAD * 2)

    return {
      bars: filtered.map((a, i) => ({
        x: PAD + i * ((W - PAD * 2) / n) + BAR_GAP / 2,
        w: barW,
        h: barHeight(a.elevation_gain_m ?? 0),
      })),
      hrPath: `M ${filtered.map((a, i) => `${xCenter(i)},${yHr(a.hr_avg)}`).join(' L ')}`,
      hrDots: filtered.map((a, i) => ({ x: xCenter(i), y: yHr(a.hr_avg) })),
    }
  })

  function formatDate(iso) {
    return new Date(iso).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
  }
</script>

<div class="page">
  <h1>Progression</h1>
  <p class="subtitle">Elevation gain per session (bars) vs. average heart rate (line) — one sport at a time, so effort profiles aren't mixed.</p>

  {#if error}
    <div class="banner banner-error">{error}</div>
  {:else if rawActivities === null}
    <p class="muted">Loading…</p>
  {:else if sportTypes.length === 0}
    <div class="card empty-card">
      <p>No matched sessions yet (excluding motor-assisted rides).</p>
    </div>
  {:else}
    {#if sportTypes.length > 1}
      <div class="segmented">
        {#each sportTypes as sport}
          <button class:active={selectedSport === sport} onclick={() => selectedSport = sport}>{sport}</button>
        {/each}
      </div>
    {/if}

    {#if filtered.length < 2}
      <div class="card empty-card">
        <p>Not enough {selectedSport} sessions yet to show progression — needs at least a couple.</p>
      </div>
    {:else if chart}
      <div class="card chart-card">
        <svg viewBox="0 0 {W} {H}" class="chart">
          {#each chart.bars as bar}
            <rect x={bar.x} y={H - PAD - bar.h} width={bar.w} height={bar.h}
                  fill="var(--color-secondary)" opacity="0.35" rx="1" />
          {/each}
          <path d={chart.hrPath} fill="none" stroke="var(--color-accent)" stroke-width="2"
                stroke-linecap="round" stroke-linejoin="round" />
          {#each chart.hrDots as dot}
            <circle cx={dot.x} cy={dot.y} r="2.5" fill="var(--color-accent)" />
          {/each}
        </svg>
        <div class="chart-legend">
          <span class="legend-item"><span class="swatch swatch-elev"></span>Elevation gain</span>
          <span class="legend-item"><span class="swatch swatch-hr"></span>Avg heart rate</span>
        </div>
      </div>

      <div class="session-list">
        {#each filtered as a}
          <div class="session-row">
            <span class="session-date">{formatDate(a.start_date_utc)}</span>
            <span class="session-name">{a.name}</span>
            <span class="session-stats">
              {a.elevation_gain_m != null ? `+${Math.round(a.elevation_gain_m)}m` : '—'}
              · <span class="hr">{a.hr_avg} bpm</span>
            </span>
          </div>
        {/each}
      </div>
    {/if}
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
