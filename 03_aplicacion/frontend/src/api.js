// Cliente HTTP de la app. Todas las rutas empiezan por /api (Vite las reenvía a FastAPI).
import axios from 'axios'

const api = axios.create({ baseURL: '/api' })

// Agrega el token JWT a cada petición
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

// Si el token venció (401), se cierra la sesión y se vuelve al login
api.interceptors.response.use(
  (respuesta) => respuesta,
  (error) => {
    const esLogin = error.config?.url?.includes('/auth/login')
    if (error.response?.status === 401 && !esLogin) {
      localStorage.removeItem('token')
      localStorage.removeItem('usuario')
      window.location.href = '/login'
    }
    return Promise.reject(error)
  },
)

// La API siempre responde los errores como {"detail": "mensaje en español"}
export function mensajeError(error) {
  const detalle = error.response?.data?.detail
  if (typeof detalle === 'string') return detalle
  if (!error.response) return 'No se pudo conectar con el servidor'
  return 'Ocurrió un error inesperado'
}

export default api
