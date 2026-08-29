<script>
  import { onMount } from 'svelte'
  import ChartComponent from '../lib/components/Chart.svelte'
  import { getActivityDetail } from '../lib/api.js'
  import { formatDuration, formatDistance, formatElevation, formatSportType, metersToFeet } from '../lib/format.js'
  import { themeColors } from '../lib/theme.js'

  /** @type {{ stravaId: number, onBack: () => void }} */
  let { stravaId, onBack } = $props()

  let detail = $state(null)   // null = loading
  let error = $state(null)

  onMount(async () => {
    try {
      detail = await getActivityDetail(stravaId)
    } catch (e) {
      error = e.message
    }
  })

  // Elevation (filled area, background context — "am I going up or downhill")
  // and heart rate (line, foreground — "how is it responding") share the
  // same x (elapsed time) but sit on independent y-axes with real units, so
  // Chart.js's built-in tooltip reads out real ft/bpm values, not a
  // normalized shape comparison like the old hand-rolled SVG chart.
  const chartData = $derived.by(() => {
    if (!detail || !detail.points.length) return null
    const c = themeColors()
    const labels = detail.points.map((p) => (p.t_sec / 60).toFixed(0))

    return {
      labels,
      datasets: [
        {
          label: 'Elevation (ft)',
          data: detail.points.map((p) => (p.altitude_m != null ? Math.round(metersToFeet(p.altitude_m)) : null)),
          yAxisID: 'yElev',
          borderColor: 'transparent',
          backgroundColor: c.secondary + '26',   // ~15% opacity
          fill: 'origin',
          pointRadius: 0,
          tension: 0.15,
          order: 2,
        },
        {
          label: 'Heart rate (bpm)',
          data: detail.points.map((p) => p.heart_rate),
          yAxisID: 'yHr',
          borderColor: c.accent,
          backgroundColor: c.accent,
          pointRadius: 0,
          borderWidth: 2,
          spanGaps: false,   // a real coverage gap should show as a break, not a fabricated line
          tension: 0.15,
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
        x: {
          title: { display: true, text: 'Minutes', color: c.muted },
          ticks: { color: c.muted, maxTicksLimit: 8, font: { size: 12 } },
          grid: { color: c.border },
        },
        yHr: {
          position: 'left',
          title: { display: true, text: 'Heart rate (bpm)', color: c.accent },
          ticks: { color: c.accent, font: { size: 12 } },
          grid: { color: c.border },
        },
        yElev: {
          position: 'right',
          title: { display: true, text: 'Elevation (ft)', color: c.secondary },
          ticks: { color: c.secondary, font: { size: 12 } },
          grid: { display: false },
        },
      },
      plugins: { legend: { display: false } },
    }
  })
</script>

<div class="page">
  <button class="back-btn" onclick={onBack}>← Activities</button>

  {#if error}
    <div class="banner banner-error">{error}</div>
  {:else if detail === null}
    <p class="muted">Loading…</p>
  {:else}
    <div class="header">
      <h1>{detail.name}</h1>
      <p class="subtitle">{formatSportType(detail.sport_type)} · {formatDuration(detail.elapsed_time_sec)}</p>
    </div>

    <div class="stats-row">
      <div class="card stat">
        <span class="stat-label">Distance</span>
        <span class="stat-value">{formatDistance(detail.distance_m)}</span>
      </div>
      <div class="card stat">
        <span class="stat-label">Elevation</span>
        <span class="stat-value">{formatElevation(detail.elevation_gain_m) ?? '—'}</span>
      </div>
      <div class="card stat">
        <span class="stat-label">Avg HR</span>
        <span class="stat-value hr">{detail.hr_avg ?? '—'}</span>
      </div>
    </div>

    {#if !detail.has_heart_rate}
      <div class="banner banner-warn">No heart rate data for this session (predates Polar data, or the watch wasn't worn).</div>
    {/if}

    {#if chartData}
      <div class="card chart-card">
        <ChartComponent type="line" data={chartData} options={chartOptions} />
      </div>
    {/if}

    <div class="stats-row">
      <div class="card stat">
        <span class="stat-label">High</span>
        <span class="stat-value high">{detail.hr_high ?? '—'}</span>
      </div>
      <div class="card stat">
        <span class="stat-label">Low</span>
        <span class="stat-value low">{detail.hr_low ?? '—'}</span>
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

  .back-btn {
    align-self: flex-start;
    background: none;
    border: none;
    color: var(--color-secondary);
    font-family: var(--font);
    font-size: 15px;
    cursor: pointer;
    padding: 0;
  }

  .muted { color: var(--color-secondary); }

  .header h1 {
    font-size: 22px;
  }

  .subtitle {
    color: var(--color-secondary);
    font-size: 14px;
    margin-top: 2px;
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
    font-size: 13px;
    color: var(--color-secondary);
  }

  .stat-value {
    font-size: 21px;
    font-weight: 600;
  }

  .stat-value.hr, .stat-value.high { color: var(--color-accent); }
  .stat-value.low { color: var(--color-good); }

  .chart-card {
    height: 280px;
    padding: var(--space-4) var(--space-3);
  }
</style>
