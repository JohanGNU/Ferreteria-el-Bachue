import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// En Docker la API se llama "api" (servicio de compose); fuera de Docker, localhost.
const destinoApi = process.env.API_URL || 'http://localhost:8000'

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 5173,
    // Windows + Docker: los cambios de archivos no llegan como eventos, se sondean
    watch: { usePolling: true },
    // El navegador llama a /api en el mismo origen y Vite lo reenvía a FastAPI
    proxy: {
      '/api': { target: destinoApi, changeOrigin: true },
    },
  },
})
