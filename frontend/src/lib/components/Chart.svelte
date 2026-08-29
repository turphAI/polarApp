<script>
  import { onMount, onDestroy } from 'svelte'
  import Chart from 'chart.js/auto'
  import { themeColors } from '../theme.js'

  /** @type {{ type: string, data: object, options?: object }} */
  let { type, data, options = {} } = $props()

  let canvas
  let chart

  function build() {
    chart?.destroy()
    const base = baseOptions()
    // A plain shallow spread would let options.plugins/scales fully replace
    // base's (e.g. a caller passing plugins:{legend:{display:false}} would
    // silently drop base's tooltip theme colors too, since it's a sibling
    // key under the same `plugins` object) — merge one level deeper so a
    // caller only overriding legend still gets base's tooltip styling, etc.
    const merged = {
      ...base,
      ...options,
      plugins: { ...base.plugins, ...options.plugins },
      scales: { ...base.scales, ...options.scales },
    }
    chart = new Chart(canvas, { type, data, options: merged })
  }

  function baseOptions() {
    const c = themeColors()
    return {
      responsive: true,
      maintainAspectRatio: false,
      color: c.secondary,
      font: { size: 13 },   // Chart.js default (12px) read small on mobile
      plugins: {
        legend: { labels: { color: c.secondary, font: { size: 12 } } },
        tooltip: {
          // --color-bg, not --color-surface — the tooltip floats over a
          // .card (already --color-surface), so it needs to be visibly
          // darker/lighter than its background, not the same color as it.
          backgroundColor: c.bg,
          titleColor: c.text,
          titleFont: { size: 13, weight: '600' },
          bodyColor: c.text,
          bodyFont: { size: 13 },
          borderColor: c.border,
          borderWidth: 1,
          padding: 10,
        },
      },
      scales: {
        x: { ticks: { color: c.muted, font: { size: 12 } }, grid: { color: c.border } },
      },
    }
  }

  onMount(() => {
    build()
    // Rebuild on an OS/browser theme change so the chart doesn't go stale-
    // colored if the user switches light/dark while the app is open.
    const mq = window.matchMedia('(prefers-color-scheme: dark)')
    mq.addEventListener('change', build)
    return () => mq.removeEventListener('change', build)
  })

  // Re-render when the caller's data/options change (e.g. switching activities).
  $effect(() => {
    data; options
    if (chart) build()
  })

  onDestroy(() => chart?.destroy())
</script>

<canvas bind:this={canvas}></canvas>
