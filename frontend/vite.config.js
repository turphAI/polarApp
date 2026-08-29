import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig({
  base: '/polarwatch/',

  plugins: [
    svelte(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['icons/favicon.svg', 'icons/apple-touch-icon.png'],
      workbox: {
        // Don't let the SPA app-shell fallback swallow API requests.
        navigateFallbackDenylist: [/\/api\//],
      },
      manifest: {
        name: 'polarWatch',
        short_name: 'polarWatch',
        description: 'Your heart rate, out of Polar’s app and into one you actually want to look at.',
        theme_color: '#C43A3A',
        background_color: '#FAFAFA',
        display: 'standalone',
        orientation: 'portrait',
        start_url: '/polarwatch/',
        scope: '/polarwatch/',
        icons: [
          { src: 'icons/pwa-192.png', sizes: '192x192', type: 'image/png' },
          { src: 'icons/pwa-512.png', sizes: '512x512', type: 'image/png', purpose: 'any maskable' },
        ],
      },
    }),
  ],

  server: {
    port: 5173,
    proxy: {
      // BASE_URL is '/polarwatch/' even in dev, so api.js calls /polarwatch/api/*.
      // Strip the mount prefix before forwarding to the backend on 5057.
      '/polarwatch/api': {
        target: 'http://localhost:5057',
        changeOrigin: true,
        rewrite: (p) => p.replace(/^\/polarwatch/, ''),
      },
    },
  },

  build: {
    outDir: '../static',
    emptyOutDir: true,
  },
})
