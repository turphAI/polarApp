<script>
  import { onMount } from 'svelte'
  import { getActivityDetail } from '../lib/api.js'

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

  const W = 340
  const H = 220
  const PAD = 6

  // Elevation profile (filled area, background context — "am I going up or
  // downhill") and heart rate (line, foreground — "how is it responding")
  // share the same x (elapsed time) but are each normalized independently
  // to the full chart height. This is a shape comparison, not a shared
  // value axis — reading an exact elevation off the HR scale (or vice
  // versa) isn't the point.
  const chart = $derived.by(() => {
    if (!detail || !detail.points.length) return null
    const points = detail.points
    const maxT = points[points.length - 1].t_sec || 1

    const x = (t) => PAD + (t / maxT) * (W - PAD * 2)

    const altValues = points.map((p) => p.altitude_m).filter((v) => v != null)
    const hasAlt = altValues.length > 1
    let elevationPath = ''
    if (hasAlt) {
      const minAlt = Math.min(...altValues)
      const maxAlt = Math.max(...altValues)
      const altRange = Math.max(maxAlt - minAlt, 1)
      const yElev = (alt) => H - PAD - ((alt - minAlt) / altRange) * (H - PAD * 2)
      const withAlt = points.filter((p) => p.altitude_m != null)
      const top = withAlt.map((p) => `${x(p.t_sec)},${yElev(p.altitude_m)}`).join(' L ')
      elevationPath = `M ${top} L ${x(withAlt[withAlt.length - 1].t_sec)},${H - PAD} `
        + `L ${x(withAlt[0].t_sec)},${H - PAD} Z`
    }

    const hrValues = points.map((p) => p.heart_rate).filter((v) => v != null)
    const hasHr = hrValues.length > 1
    let hrPath = ''
    if (hasHr) {
      const minHr = Math.min(...hrValues)
      const maxHr = Math.max(...hrValues)
      const hrRange = Math.max(maxHr - minHr, 1)
      const yHr = (hr) => H - PAD - ((hr - minHr) / hrRange) * (H - PAD * 2)
      // Break the line at gaps (no fabricating data across a coverage gap)
      // instead of one continuous polyline.
      let segments = []
      let current = []
      for (const p of points) {
        if (p.heart_rate == null) {
          if (current.length) segments.push(current)
          current = []
          continue
        }
        current.push(`${x(p.t_sec)},${yHr(p.heart_rate)}`)
      }
      if (current.length) segments.push(current)
      hrPath = segments.map((seg) => `M ${seg.join(' L ')}`).join(' ')
    }

    return { elevationPath, hrPath, hasAlt, hasHr, maxT }
  })

  function formatDuration(sec) {
    const h = Math.floor(sec / 3600)
    const m = Math.round((sec % 3600) / 60)
    return h > 0 ? `${h}h ${m}m` : `${m}m`
  }

  function formatDistance(m) {
    if (m == null) return '—'
    return `${(m / 1000).toFixed(1)} km`
  }
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
      <p class="subtitle">{detail.sport_type} · {formatDuration(detail.elapsed_time_sec)}</p>
    </div>

    <div class="stats-row">
      <div class="card stat">
        <span class="stat-label">Distance</span>
        <span class="stat-value">{formatDistance(detail.distance_m)}</span>
      </div>
      <div class="card stat">
        <span class="stat-label">Elevation</span>
        <span class="stat-value">{detail.elevation_gain_m != null ? `+${Math.round(detail.elevation_gain_m)}m` : '—'}</span>
      </div>
      <div class="card stat">
        <span class="stat-label">Avg HR</span>
        <span class="stat-value hr">{detail.hr_avg ?? '—'}</span>
      </div>
    </div>

    {#if !detail.has_heart_rate}
      <div class="banner banner-warn">No heart rate data for this session (predates Polar data, or the watch wasn't worn).</div>
    {/if}

    {#if chart}
      <div class="card chart-card">
        <svg viewBox="0 0 {W} {H}" class="chart">
          {#if chart.hasAlt}
            <path d={chart.elevationPath} fill="var(--color-secondary)" opacity="0.15" />
          {/if}
          {#if chart.hasHr}
            <path d={chart.hrPath} fill="none" stroke="var(--color-accent)" stroke-width="2"
                  stroke-linecap="round" stroke-linejoin="round" />
          {/if}
        </svg>
        <div class="chart-legend">
          <span class="legend-item"><span class="swatch swatch-elev"></span>Elevation</span>
          <span class="legend-item"><span class="swatch swatch-hr"></span>Heart rate</span>
        </div>
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
    font-size: 14px;
    cursor: pointer;
    padding: 0;
  }

  .muted { color: var(--color-secondary); }

  .header h1 {
    font-size: 20px;
  }

  .subtitle {
    color: var(--color-secondary);
    font-size: 13px;
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
    font-size: 12px;
    color: var(--color-secondary);
  }

  .stat-value {
    font-size: 20px;
    font-weight: 600;
  }

  .stat-value.hr, .stat-value.high { color: var(--color-accent); }
  .stat-value.low { color: var(--color-good); }

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
    opacity: 0.3;
  }

  .swatch-hr {
    background: var(--color-accent);
  }
</style>
