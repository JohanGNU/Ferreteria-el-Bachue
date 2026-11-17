// Auditoría (solo admin). Muestra lo que registró trg_auditoria en productos, clientes y
// usuarios: quién, cuándo y qué cambió. Filtros por tabla, operación y fechas.
import { useState } from 'react'
import Encabezado from '../components/Encabezado'
import Modal from '../components/Modal'
import TablaDatos from '../components/TablaDatos'
import useListado from '../components/useListado'
import { formatoFecha } from '../formato'

const COLOR_OPERACION = { INSERT: 'success', UPDATE: 'primary', DELETE: 'danger' }

// Para UPDATE: lista solo los campos que cambiaron
function cambios(fila) {
  if (fila.operacion !== 'UPDATE') return null
  const antes = fila.datos_antes || {}
  const despues = fila.datos_despues || {}
  return Object.keys(despues).filter((k) => JSON.stringify(antes[k]) !== JSON.stringify(despues[k]))
    .map((k) => ({ campo: k, antes: antes[k], despues: despues[k] }))
}

const mostrar = (v) => (v === null || v === undefined ? '∅' : String(v))

export default function Auditoria() {
  const [filtros, setFiltros] = useState({ tabla: '', operacion: '', desde: '', hasta: '' })
  const params = Object.fromEntries(Object.entries(filtros).map(([k, v]) => [k, v || undefined]))
  const { filas, cargando } = useListado('/auditoria', params)
  const [verFila, setVerFila] = useState(null)
  const cambiar = (campo) => (e) => setFiltros({ ...filtros, [campo]: e.target.value })

  const columnas = [
    { titulo: 'Fecha', render: (a) => formatoFecha(a.fecha) },
    { titulo: 'Usuario', campo: 'usuario' },
    { titulo: 'Tabla', campo: 'tabla' },
    {
      titulo: 'Operación',
      render: (a) => <span className={`badge text-bg-${COLOR_OPERACION[a.operacion]}`}>{a.operacion}</span>,
    },
    { titulo: 'Registro', campo: 'registro_id', className: 'text-end' },
    {
      titulo: 'Cambios',
      className: 'ajustar small',
      render: (a) => {
        const lista = cambios(a)
        if (!lista) {
          const datos = a.datos_despues || a.datos_antes || {}
          return <span className="text-body-secondary">{datos.nombre ?? datos.codigo ?? ''}</span>
        }
        return lista.map((c) => (
          <div key={c.campo}>
            <strong>{c.campo}</strong>: {mostrar(c.antes)} → {mostrar(c.despues)}
          </div>
        ))
      },
    },
    {
      titulo: '',
      className: 'text-end',
      render: (a) => (
        <button className="btn btn-sm btn-outline-secondary" onClick={() => setVerFila(a)}>
          <i className="bi bi-braces" />
        </button>
      ),
    },
  ]

  return (
    <>
      <Encabezado titulo="Auditoría" icono="shield-check" />
      <div className="tarjeta p-3">
        <div className="row g-2 align-items-end mb-3">
          <div className="col-6 col-md-3">
            <label className="form-label small mb-1">Tabla</label>
            <select className="form-select" value={filtros.tabla} onChange={cambiar('tabla')}>
              <option value="">Todas</option>
              <option value="productos">Productos</option>
              <option value="clientes">Clientes</option>
              <option value="usuarios">Usuarios</option>
            </select>
          </div>
          <div className="col-6 col-md-3">
            <label className="form-label small mb-1">Operación</label>
            <select className="form-select" value={filtros.operacion} onChange={cambiar('operacion')}>
              <option value="">Todas</option>
              <option value="INSERT">INSERT</option>
              <option value="UPDATE">UPDATE</option>
              <option value="DELETE">DELETE</option>
            </select>
          </div>
          <div className="col-6 col-md-3">
            <label className="form-label small mb-1">Desde</label>
            <input type="date" className="form-control" value={filtros.desde} onChange={cambiar('desde')} />
          </div>
          <div className="col-6 col-md-3">
            <label className="form-label small mb-1">Hasta</label>
            <input type="date" className="form-control" value={filtros.hasta} onChange={cambiar('hasta')} />
          </div>
        </div>
        <TablaDatos columnas={columnas} filas={filas} cargando={cargando} vacio="No hay registros de auditoría" />
        <small className="text-body-secondary d-block mt-2">
          Se muestran los últimos 200 registros. Los cambios de solo stock no se auditan: quedan en el kardex.
        </small>
      </div>

      <Modal titulo={`Auditoría #${verFila?.id}`} abierto={!!verFila} onCerrar={() => setVerFila(null)} tamano="modal-lg">
        {verFila && (
          <div className="row g-3">
            <div className="col-md-6">
              <h3 className="h6">Antes</h3>
              <pre className="json-auditoria bg-light p-2 rounded">{JSON.stringify(verFila.datos_antes, null, 2) ?? '—'}</pre>
            </div>
            <div className="col-md-6">
              <h3 className="h6">Después</h3>
              <pre className="json-auditoria bg-light p-2 rounded">{JSON.stringify(verFila.datos_despues, null, 2) ?? '—'}</pre>
            </div>
          </div>
        )}
      </Modal>
    </>
  )
}
