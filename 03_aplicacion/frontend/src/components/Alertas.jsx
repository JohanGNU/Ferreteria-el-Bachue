// Alertas de éxito y error (esquina superior derecha, se cierran solas).
// Uso: const alertas = useAlertas(); alertas.exito('Guardado'); alertas.error('Falló')
import { createContext, useCallback, useContext, useMemo, useState } from 'react'

const AlertasContext = createContext(null)
let siguienteId = 1

export function AlertasProvider({ children }) {
  const [lista, setLista] = useState([])

  const cerrar = useCallback((id) => setLista((actual) => actual.filter((a) => a.id !== id)), [])

  const mostrar = useCallback(
    (tipo, texto) => {
      const id = siguienteId++
      setLista((actual) => [...actual, { id, tipo, texto }])
      setTimeout(() => cerrar(id), tipo === 'danger' ? 7000 : 4000)
    },
    [cerrar],
  )

  const api = useMemo(
    () => ({
      exito: (texto) => mostrar('success', texto),
      error: (texto) => mostrar('danger', texto),
      aviso: (texto) => mostrar('warning', texto),
    }),
    [mostrar],
  )

  return (
    <AlertasContext.Provider value={api}>
      {children}
      <div className="alertas-flotantes">
        {lista.map((a) => (
          <div key={a.id} className={`alert alert-${a.tipo} alert-dismissible shadow-sm mb-2`} role="alert">
            <i className={`bi ${a.tipo === 'success' ? 'bi-check-circle' : 'bi-exclamation-triangle'} me-2`} />
            {a.texto}
            <button type="button" className="btn-close" aria-label="Cerrar" onClick={() => cerrar(a.id)} />
          </div>
        ))}
      </div>
    </AlertasContext.Provider>
  )
}

export const useAlertas = () => useContext(AlertasContext)
