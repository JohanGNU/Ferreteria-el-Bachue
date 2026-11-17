// Sin sesión: va al login. Con sesión pero sin el rol pedido: vuelve al inicio.
import { Navigate } from 'react-router-dom'
import { useAuth } from '../auth'

export default function RutaProtegida({ roles, children }) {
  const { usuario } = useAuth()
  if (!usuario) return <Navigate to="/login" replace />
  if (roles && !roles.includes(usuario.rol)) return <Navigate to="/" replace />
  return children
}
