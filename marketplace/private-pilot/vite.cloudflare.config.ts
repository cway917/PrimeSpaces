import vinext from 'vinext';
import { defineConfig } from 'vite';
import { cloudflare } from '@cloudflare/vite-plugin';

// Independent deployment only. The original vite.config.ts retains Sites hosting.
export default defineConfig({
  plugins: [vinext(), cloudflare({
    viteEnvironment: { name: 'rsc', childEnvironments: ['ssr'] },
    inspectorPort: false,
    configPath: './wrangler.cloudflare.jsonc',
  })],
});
