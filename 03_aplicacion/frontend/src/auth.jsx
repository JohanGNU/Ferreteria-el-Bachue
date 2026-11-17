// Sesión del usuario: token y datos guardados en localStorage.
// El menú usa el rol para mostrar opciones, pero el control real lo hace la API (require_role).
import { createContext, useContext, useState } from 'react'
import api from './api'

const AuthContext = createContext(null)

function leerUsuarioGuardado() {
  try {
    return JSON.parse(localStorage.getItem('usuario'))
  } catch {
    return null
  }
}

export function AuthProvider({ children }) {
  const [usuario, setUsuario] = useState(leerUsuarioGuardado)

  async function iniciarSesion(email, password) {
    const { data } = await api.post('/auth/login', { email, password })
    localStorage.setItem('token', data.access_token)
    localStorage.setItem('usuario', JSON.stringify(data.usuario))
    setUsuario(data.usuario)
    return data.usuario
  }

  function cerrarSesion() {
    localStorage.removeItem('token')
    localStorage.removeItem('usuario')
    setUsuario(null)
  }

  const esAdmin = usuario?.rol === 'admin'

  return (
    <AuthContext.Provider value={{ usuario, esAdmin, iniciarSesion, cerrarSesion }}>
      {children}
    </AuthContext.Provider>
  )
}

export const useAuth = () => useContext(AuthContext)
