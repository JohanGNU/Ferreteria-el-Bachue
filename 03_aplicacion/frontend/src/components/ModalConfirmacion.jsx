// Confirmación antes de acciones destructivas (eliminar, anular).
import { useState } from 'react'
import Modal from './Modal'

export default function ModalConfirmacion({
  abierto,
  titulo = 'Confirmar',
  mensaje,
  textoConfirmar = 'Eliminar',
  onConfirmar,
  onCancelar,
}) {
  const [procesando, setProcesando] = useState(false)

  async function confirmar() {
    setProcesando(true)
    try {
      await onConfirmar()
    } finally {
      setProcesando(false)
    }
  }

  return (
    <Modal
      titulo={titulo}
      abierto={abierto}
      onCerrar={onCancelar}
      pie={
        <>
          <button type="button" className="btn btn-outline-secondary" onClick={onCancelar} disabled={procesando}>
            Cancelar
          </button>
          <button type="button" className="btn btn-danger" onClick={confirmar} disabled={procesando}>
            {procesando && <span className="spinner-border spinner-border-sm me-2" />}
            {textoConfirmar}
          </button>
        </>
      }
    >
      <p className="mb-0">{mensaje}</p>
    </Modal>
  )
}
