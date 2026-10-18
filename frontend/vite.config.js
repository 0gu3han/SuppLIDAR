import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  build: {
    outDir: '../backend/static_spa',
    emptyOutDir: true,
  },
  server: {
    host: true,
    proxy: {
      '/rooms':    'http://localhost:5001',
      '/auth':     'http://localhost:5001',
      '/anchors':  'http://localhost:5001',
      '/objects':  'http://localhost:5001',
      '/uploads':  'http://localhost:5001',
      '/items':    'http://localhost:5001',
      '/requests': 'http://localhost:5001',
      '/claims':   'http://localhost:5001',
      '/detect':   'http://localhost:5001',
      '/impact':   'http://localhost:5001',
    },
  },
})
