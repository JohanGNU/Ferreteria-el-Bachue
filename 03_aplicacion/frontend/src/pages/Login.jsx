// Pantalla de inicio de sesión. Validación HTML5 (required, type=email) y error de la API.
// A la izquierda, el nombre de la ferretería en grande; a la derecha, el formulario.
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
    <div className="pantalla-login">
      <section className="login-marca">
        <div>
          <h1 className="login-nombre">El<br />Bachué</h1>
          <p className="login-lema">Ferretería. Inventario, ventas y existencias en un solo mostrador.</p>
        </div>
        <p className="login-pie">Bases de Datos II, 2026</p>
      </section>

      <section className="login-formulario">
        <div className="panel-login">
          <div className="panel-login-cuerpo">
            <h2>Iniciar sesión</h2>
            <p className="text-body-secondary mb-4">Use el correo y la contraseña de su cuenta.</p>
            {error && (
              <div className="alert alert-danger py-2">
                <i className="bi bi-x-octagon me-2" />{error}
              </div>
            )}
            <form noValidate className={validado ? 'was-validated' : ''} onSubmit={enviar}>
              <div className="mb-3">
                <label className="form-label" htmlFor="email">Correo</label>
                <input
                  id="email"
                  type="email"
                  className="form-control form-control-lg"
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
                  className="form-control form-control-lg"
                  required
                  autoComplete="current-password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                />
                <div className="invalid-feedback">Escriba la contraseña</div>
              </div>
              <button type="submit" className="btn btn-primary btn-lg w-100" disabled={enviando}>
                {enviando && <span className="spinner-border spinner-border-sm me-2" />}
                Ingresar
              </button>
            </form>
          </div>
        </div>
      </section>
    </div>
  )
}
