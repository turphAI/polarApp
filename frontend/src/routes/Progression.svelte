<script>
  import { onMount } from 'svelte'
  import ChartComponent from '../lib/components/Chart.svelte'
  import { getActivities } from '../lib/api.js'
  import { formatDate, formatSportType, metersToFeet } from '../lib/format.js'
  import { themeColors } from '../lib/theme.js'

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

  const chartData = $derived.by(() => {
    if (filtered.length < 2) return null
    const c = themeColors()
    return {
      labels: filtered.map((a) => formatDate(a.start_date_utc)),
      datasets: [
        {
          type: 'bar',
          label: 'Elevation gain (ft)',
          data: filtered.map((a) => (a.elevation_gain_m != null ? Math.round(metersToFeet(a.elevation_gain_m)) : null)),
          yAxisID: 'yElev',
          backgroundColor: c.secondary + '59',   // ~35% opacity
          order: 2,
        },
        {
          type: 'line',
          label: 'Avg heart rate (bpm)',
          data: filtered.map((a) => a.hr_avg),
          yAxisID: 'yHr',
          borderColor: c.accent,
          backgroundColor: c.accent,
          pointRadius: 3,
          borderWidth: 2,
          order: 1,
        },
      ],
    }
  })

  const chartOptions = $derived.by(() => {
    const c = themeColors()
    return {
      interaction: { mode: 'index', intersect: false },
      scales: {
        x: { ticks: { color: c.muted, font: { size: 12 } }, grid: { display: false } },
        yHr: {
          position: 'left',
          title: { display: true, text: 'Avg HR (bpm)', color: c.accent },
          ticks: { color: c.accent, font: { size: 12 } },
          grid: { color: c.border },
        },
        yElev: {
          position: 'right',
          title: { display: true, text: 'Elevation gain (ft)', color: c.secondary },
          ticks: { color: c.secondary, font: { size: 12 } },
          grid: { display: false },
        },
      },
      plugins: { legend: { display: false } },
    }
  })
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
          <button class:active={selectedSport === sport} onclick={() => selectedSport = sport}>{formatSportType(sport)}</button>
        {/each}
      </div>
    {/if}

    {#if filtered.length < 2}
      <div class="card empty-card">
        <p>Not enough {formatSportType(selectedSport)} sessions yet to show progression — needs at least a couple.</p>
      </div>
    {:else if chartData}
      <div class="card chart-card">
        <ChartComponent type="bar" data={chartData} options={chartOptions} />
      </div>

      <div class="session-list">
        {#each filtered as a}
          <div class="session-row">
            <span class="session-date">{formatDate(a.start_date_utc)}</span>
            <span class="session-name">{a.name}</span>
            <span class="session-stats">
              {a.elevation_gain_m != null ? `+${Math.round(metersToFeet(a.elevation_gain_m))} ft` : '—'}
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
    font-size: 14px;
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
    min-height: 40px;
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

  .chart-card {
    height: 260px;
    padding: var(--space-4) var(--space-3);
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
    font-size: 13px;
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
