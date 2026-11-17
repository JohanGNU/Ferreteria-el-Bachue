// Tabla genérica con buscador. La búsqueda la hace la API (?q=), con espera de 300 ms
// para no llamar al servidor en cada tecla.
import { useEffect, useState } from 'react'

export function Buscador({ onBuscar, placeholder = 'Buscar...' }) {
  const [texto, setTexto] = useState('')

  useEffect(() => {
    const espera = setTimeout(() => onBuscar(texto), 300)
    return () => clearTimeout(espera)
  }, [texto, onBuscar])

  return (
    <div className="input-group buscador">
      <span className="input-group-text"><i className="bi bi-search" /></span>
      <input
        type="search"
        className="form-control"
        placeholder={placeholder}
        value={texto}
        onChange={(e) => setTexto(e.target.value)}
        aria-label="Buscar"
      />
    </div>
  )
}

// columnas: [{ titulo, campo, render(fila), className }]
export default function TablaDatos({ columnas, filas, cargando, vacio = 'No hay registros', claveFila = 'id' }) {
  return (
    <div className="table-responsive">
      <table className="table table-hover align-middle mb-0">
        <thead>
          <tr>
            {columnas.map((c) => (
              <th key={c.titulo} className={c.className}>{c.titulo}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {cargando && (
            <tr>
              <td colSpan={columnas.length} className="text-center py-4">
                <span className="spinner-border spinner-border-sm me-2" />Cargando...
              </td>
            </tr>
          )}
          {!cargando && filas.length === 0 && (
            <tr>
              <td colSpan={columnas.length} className="text-center text-body-secondary py-4">{vacio}</td>
            </tr>
          )}
          {!cargando &&
            filas.map((fila) => (
              <tr key={fila[claveFila]}>
                {columnas.map((c) => (
                  <td key={c.titulo} className={c.className}>
                    {c.render ? c.render(fila) : fila[c.campo]}
                  </td>
                ))}
              </tr>
            ))}
        </tbody>
      </table>
    </div>
  )
}
