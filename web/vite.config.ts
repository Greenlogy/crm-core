import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

// Lokálne: /api ide na API spustené cez api/dev.sh (wrangler dev).
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: { '/api': 'http://localhost:8787' },
  },
});
