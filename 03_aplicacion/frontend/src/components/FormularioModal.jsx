// Formulario dentro de un modal con validación HTML5 (required, pattern, min, type=email...).
// Si el navegador encuentra campos inválidos, marca el formulario con "was-validated"
// para que Bootstrap muestre los mensajes; si no, llama a onGuardar.
import { useEffect, useState } from 'react'
import Modal from './Modal'

export default function FormularioModal({ titulo, abierto, onCerrar, onGuardar, children, tamano, textoGuardar = 'Guardar' }) {
  const [validado, setValidado] = useState(false)
  const [guardando, setGuardando] = useState(false)

  useEffect(() => {
    if (abierto) setValidado(false)
  }, [abierto])

  async function enviar(e) {
    e.preventDefault()
    const formulario = e.currentTarget
    if (!formulario.checkValidity()) {
      setValidado(true)
      return
    }
    setGuardando(true)
    try {
      await onGuardar()
    } finally {
      setGuardando(false)
    }
  }

  return (
    <Modal titulo={titulo} abierto={abierto} onCerrar={onCerrar} tamano={tamano}>
      <form noValidate className={validado ? 'was-validated' : ''} onSubmit={enviar}>
        {children}
        <div className="d-flex justify-content-end gap-2 mt-4">
          <button type="button" className="btn btn-outline-secondary" onClick={onCerrar} disabled={guardando}>
            Cancelar
          </button>
          <button type="submit" className="btn btn-primary" disabled={guardando}>
            {guardando && <span className="spinner-border spinner-border-sm me-2" />}
            {textoGuardar}
          </button>
        </div>
      </form>
    </Modal>
  )
}

// Campo de formulario con etiqueta y mensaje de error de Bootstrap
export function Campo({ etiqueta, error, children, className = 'col-12', ayuda }) {
  return (
    <div className={className}>
      <label className="form-label">{etiqueta}</label>
      {children}
      {ayuda && <div className="form-text">{ayuda}</div>}
      {error && <div className="invalid-feedback">{error}</div>}
    </div>
  )
}
