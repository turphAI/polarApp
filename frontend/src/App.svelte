<script>
  import { onMount } from 'svelte'
  import TabBar from './lib/components/TabBar.svelte'
  import Activities from './routes/Activities.svelte'
  import ActivityDetail from './routes/ActivityDetail.svelte'
  import Progression from './routes/Progression.svelte'
  import { getAuthStatus, startAuth, getStravaAuthStatus, startStravaAuth } from './lib/api.js'

  let currentTab = $state('activities')
  let selectedActivityId = $state(null)   // set = showing ActivityDetail instead of a tab

  let polarStatus = $state(null)   // null while loading
  let stravaStatus = $state(null)
  let authError = $state(false)

  const tabs = [
    { id: 'activities',  label: 'Activities' },
    { id: 'progression', label: 'Progression' },
  ]

  onMount(async () => {
    try {
      polarStatus = await getAuthStatus()
      stravaStatus = await getStravaAuthStatus()
    } catch {
      authError = true
    }
  })

  // Fail loud: a sync that failed on auth (token refresh rejected) means the
  // user needs to reconnect, even though we still have a (stale) token row.
  const needsReconnect = $derived(
    polarStatus?.last_sync && !polarStatus.last_sync.ok && polarStatus.last_sync.detail?.startsWith('auth:')
  )
</script>

<div class="app-shell">
  {#if (polarStatus === null || stravaStatus === null) && !authError}
    <div class="center-message">Loading…</div>
  {:else if authError}
    <div class="center-message">
      <p>Can't reach the polarWatch backend right now.</p>
    </div>
  {:else if !polarStatus.connected}
    <div class="connect-screen">
      <h1>polarWatch</h1>
      <p class="prose-muted">Connect your Polar account to start tracking your heart rate.</p>
      <button class="btn" onclick={startAuth}>Connect to Polar</button>
    </div>
  {:else if !stravaStatus.connected}
    <div class="connect-screen">
      <h1>polarWatch</h1>
      <p class="prose-muted">Polar's connected. Now connect Strava — that's where your activities (rides, hikes, walks) are tracked.</p>
      <button class="btn" onclick={startStravaAuth}>Connect to Strava</button>
    </div>
  {:else}
    {#if needsReconnect}
      <div class="banner banner-error reconnect-banner">
        <span>Polar connection needs to be renewed.</span>
        <button class="btn-link" onclick={startAuth}>Reconnect</button>
      </div>
    {/if}

    <main class="route-content" class:no-tab-bar={selectedActivityId}>
      {#if selectedActivityId}
        <ActivityDetail stravaId={selectedActivityId} onBack={() => selectedActivityId = null} />
      {:else if currentTab === 'activities'}
        <Activities onSelect={(id) => selectedActivityId = id} />
      {:else if currentTab === 'progression'}
        <Progression />
      {/if}
    </main>

    {#if !selectedActivityId}
      <TabBar {tabs} bind:current={currentTab} />
    {/if}
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

  .route-content.no-tab-bar {
    padding-bottom: var(--space-6);
  }
</style>
