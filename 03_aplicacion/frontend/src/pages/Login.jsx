// Pantalla de inicio de sesión. Validación HTML5 (required, type=email) y error de la API.
import { useState } from 'react'
import { Navigate, useNavigate } from 'react-router-dom'
import { mensajeError } from '../api'
import { useAuth } from '../auth'

export default function Login() {
  const { usuario, iniciarSesion } = useAuth()
  const navegar = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [validado, setValidado] = useState(false)
  const [enviando, setEnviando] = useState(false)

  if (usuario) return <Navigate to="/" replace />

  async function enviar(e) {
    e.preventDefault()
    setError('')
    if (!e.currentTarget.checkValidity()) {
      setValidado(true)
      return
    }
    setEnviando(true)
    try {
      await iniciarSesion(email, password)
      navegar('/')
    } catch (err) {
      setError(mensajeError(err))
    } finally {
      setEnviando(false)
    }
  }

  return (
    <div className="pantalla-login d-flex align-items-center justify-content-center p-3">
      <div className="card shadow-lg border-0" style={{ width: '100%', maxWidth: 400 }}>
        <div className="card-body p-4">
          <div className="text-center mb-4">
            <i className="bi bi-tools text-primary" style={{ fontSize: '2.5rem' }} />
            <h1 className="h4 mt-2 mb-0">Ferretería El Bachué</h1>
            <p className="text-body-secondary small">Inventario y ventas</p>
          </div>
          {error && <div className="alert alert-danger py-2">{error}</div>}
          <form noValidate className={validado ? 'was-validated' : ''} onSubmit={enviar}>
            <div className="mb-3">
              <label className="form-label" htmlFor="email">Correo</label>
              <input
                id="email"
                type="email"
                className="form-control"
                required
                autoComplete="username"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
              <div className="invalid-feedback">Escriba un correo válido</div>
            </div>
            <div className="mb-4">
              <label className="form-label" htmlFor="password">Contraseña</label>
              <input
                id="password"
                type="password"
                className="form-control"
                required
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
              <div className="invalid-feedback">Escriba la contraseña</div>
            </div>
            <button type="submit" className="btn btn-primary w-100" disabled={enviando}>
              {enviando && <span className="spinner-border spinner-border-sm me-2" />}
              Ingresar
            </button>
          </form>
        </div>
      </div>
    </div>
  )
}
