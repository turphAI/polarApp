<script>
  let { tabs, current = $bindable() } = $props()
</script>

<nav class="tab-bar" aria-label="Main navigation">
  {#each tabs as tab}
    <button
      class="tab-btn"
      class:active={current === tab.id}
      aria-current={current === tab.id ? 'page' : undefined}
      onclick={() => current = tab.id}
    >
      <span class="tab-label">{tab.label}</span>
    </button>
  {/each}
</nav>

<style>
  .tab-bar {
    position: fixed;
    bottom: 0;
    left: 50%;
    transform: translateX(-50%);
    width: 100%;
    max-width: 480px;
    height: calc(var(--tab-bar-height) + var(--safe-area-bottom));
    padding-bottom: var(--safe-area-bottom);

    display: flex;
    align-items: stretch;
    background: var(--color-surface);
    border-top: 1px solid var(--color-border);
    z-index: 100;
  }

  .tab-btn {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;

    background: none;
    border: none;
    cursor: pointer;
    color: var(--color-muted);
    transition: color 0.15s ease;

    min-height: 44px;
    -webkit-tap-highlight-color: transparent;
  }

  .tab-btn.active {
    color: var(--color-accent);
    font-weight: 600;
  }

  .tab-label {
    font-size: 14px;
  }
</style>
