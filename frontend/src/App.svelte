<script>
  import { onMount } from 'svelte'
  import TabBar from './lib/components/TabBar.svelte'
  import Today from './routes/Today.svelte'
  import History from './routes/History.svelte'
  import Trend from './routes/Trend.svelte'
  import { getAuthStatus, startAuth } from './lib/api.js'

  let currentTab = $state('today')
  let authStatus = $state(null)   // null while loading
  let authError = $state(false)

  const tabs = [
    { id: 'today',   label: 'Today' },
    { id: 'history', label: 'History' },
    { id: 'trend',   label: 'Trend' },
  ]

  onMount(async () => {
    try {
      authStatus = await getAuthStatus()
    } catch {
      authError = true
    }
  })

  // Fail loud: a sync that failed on auth (token refresh rejected) means the
  // user needs to reconnect, even though we still have a (stale) token row.
  const needsReconnect = $derived(
    authStatus?.last_sync && !authStatus.last_sync.ok && authStatus.last_sync.detail?.startsWith('auth:')
  )
</script>

<div class="app-shell">
  {#if authStatus === null && !authError}
    <div class="center-message">Loading…</div>
  {:else if authError}
    <div class="center-message">
      <p>Can't reach the polarWatch backend right now.</p>
    </div>
  {:else if !authStatus.connected}
    <div class="connect-screen">
      <h1>polarWatch</h1>
      <p class="prose-muted">Connect your Polar account to start tracking your heart rate history.</p>
      <button class="btn" onclick={startAuth}>Connect to Polar</button>
    </div>
  {:else}
    {#if needsReconnect}
      <div class="banner banner-error reconnect-banner">
        <span>Polar connection needs to be renewed.</span>
        <button class="btn-link" onclick={startAuth}>Reconnect</button>
      </div>
    {/if}

    <main class="route-content">
      {#if currentTab === 'today'}
        <Today />
      {:else if currentTab === 'history'}
        <History />
      {:else if currentTab === 'trend'}
        <Trend />
      {/if}
    </main>

    <TabBar {tabs} bind:current={currentTab} />
  {/if}
</div>

<style>
  .app-shell {
    display: flex;
    flex-direction: column;
    min-height: 100dvh;
  }

  .center-message {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: var(--space-6);
    color: var(--color-secondary);
    text-align: center;
  }

  .connect-screen {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: var(--space-4);
    padding: var(--space-8);
    text-align: center;
  }

  .prose-muted {
    color: var(--color-secondary);
    font-size: 15px;
    line-height: 1.5;
  }

  .reconnect-banner {
    justify-content: space-between;
    border-radius: 0;
  }

  .btn-link {
    background: none;
    border: none;
    color: inherit;
    font-weight: 600;
    text-decoration: underline;
    cursor: pointer;
  }

  .route-content {
    flex: 1 1 auto;
    overflow-y: auto;
    padding-bottom: calc(var(--tab-bar-height) + var(--safe-area-bottom) + var(--space-6));
  }
</style>
