// Reads the app's CSS custom properties as real color strings, for anywhere
// (chart datasets, canvas-based rendering) that can't reference a CSS var
// directly. Shared by Chart.svelte (axis/tooltip chrome) and any component
// building dataset colors (e.g. ActivityDetail, Progression).
export function themeColors() {
  const style = getComputedStyle(document.body)
  const get = (name) => style.getPropertyValue(name).trim()
  return {
    bg: get('--color-bg'),
    text: get('--color-text'),
    secondary: get('--color-secondary'),
    muted: get('--color-muted'),
    border: get('--color-border'),
    accent: get('--color-accent'),
    good: get('--color-good'),
    surface: get('--color-surface'),
  }
}
