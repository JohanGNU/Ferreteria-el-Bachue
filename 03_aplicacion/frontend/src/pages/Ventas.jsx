// Listado de ventas con total (fn_total_venta), filtros, detalle y anulación.
// Anular llama a sp_anular_venta (cursor que devuelve el stock); solo admin.
import { useState } from 'react'
import { Link } from 'react-router-dom'
import api, { mensajeError } from '../api'
import { useAuth } from '../auth'
import { useAlertas } from '../components/Alertas'
import Encabezado from '../components/Encabezado'
import { EstadoVenta } from '../components/Insignias'
import Modal from '../components/Modal'
import ModalConfirmacion from '../components/ModalConfirmacion'
import TablaDatos, { Buscador } from '../components/TablaDatos'
import useListado from '../components/useListado'
import { formatoFecha, formatoMoneda } from '../formato'

export default function Ventas() {
  const { esAdmin } = useAuth()
  const alertas = useAlertas()
  const [filtros, setFiltros] = useState({ desde: '', hasta: '', estado: '' })
  const params = {
    desde: filtros.desde || undefined,
    hasta: filtros.hasta || undefined,
    estado: filtros.estado || undefined,
  }
  const { filas, cargando, recargar, setQ } = useListado('/ventas', params)
  const [detalle, setDetalle] = useState(null)
  const [aAnular, setAAnular] = useState(null)

  const cambiarFiltro = (campo) => (e) => setFiltros({ ...filtros, [campo]: e.target.value })

  async function verDetalle(id) {
    try {
      const { data } = await api.get(`/ventas/${id}`)
      setDetalle(data)
    } catch (error) {
      alertas.error(mensajeError(error))
    }
  }

  async function anular() {
    try {
      const { data } = await api.post(`/ventas/${aAnular.id}/anular`)
      alertas.exito(`Venta #${data.id} anulada: el stock de sus productos se devolvió`)
      setDetalle(null)
      recargar()
    } catch (error) {
      alertas.error(mensajeError(error))
    } finally {
      setAAnular(null)
    }
  }

  const totalFiltrado = filas.filter((v) => v.estado === 'PAGADA').reduce((s, v) => s + Number(v.total), 0)

  const columnas = [
    { titulo: '#', campo: 'id' },
    { titulo: 'Fecha', render: (v) => formatoFecha(v.fecha) },
    { titulo: 'Cliente', campo: 'cliente', className: 'ajustar' },
    { titulo: 'Vendedor', campo: 'vendedor' },
    { titulo: 'Total', render: (v) => formatoMoneda(v.total), className: 'text-end' },
    { titulo: 'Estado', render: (v) => <EstadoVenta estado={v.estado} /> },
    {
      titulo: '',
      className: 'text-end',
      render: (v) => (
        <button className="btn btn-sm btn-outline-primary" onClick={() => verDetalle(v.id)}>
          <i className="bi bi-eye me-1" />Ver
        </button>
      ),
    },
  ]

  return (
    <>
      <Encabezado titulo="Ventas" icono="receipt">
        <Link to="/ventas/nueva" className="btn btn-primary">
          <i className="bi bi-cart-plus me-1" />Nueva venta
        </Link>
      </Encabezado>

      <div className="tarjeta p-3">
        <div className="row g-2 align-items-end mb-3">
          <div className="col-12 col-lg-4">
            <Buscador onBuscar={setQ} placeholder="Cliente o documento" />
          </div>
          <div className="col-6 col-md-3 col-lg-2">
            <label className="form-label small mb-1">Desde</label>
            <input type="date" className="form-control" value={filtros.desde} onChange={cambiarFiltro('desde')} />
          </div>
          <div className="col-6 col-md-3 col-lg-2">
            <label className="form-label small mb-1">Hasta</label>
            <input type="date" className="form-control" value={filtros.hasta} onChange={cambiarFiltro('hasta')} />
          </div>
          <div className="col-6 col-md-3 col-lg-2">
            <label className="form-label small mb-1">Estado</label>
            <select className="form-select" value={filtros.estado} onChange={cambiarFiltro('estado')}>
              <option value="">Todos</option>
              <option value="PAGADA">Pagadas</option>
              <option value="ANULADA">Anuladas</option>
            </select>
          </div>
          <div className="col-6 col-md-3 col-lg-2 text-end small">
            <div className="text-body-secondary">Total pagado</div>
            <strong>{formatoMoneda(totalFiltrado)}</strong>
          </div>
        </div>
        <TablaDatos columnas={columnas} filas={filas} cargando={cargando} vacio="No hay ventas con esos filtros" />
      </div>

      <Modal
        titulo={detalle ? `Venta #${detalle.id}` : ''}
        abierto={!!detalle}
        onCerrar={() => setDetalle(null)}
        tamano="modal-lg"
        pie={
          esAdmin && detalle?.estado === 'PAGADA' ? (
            <button className="btn btn-outline-danger" onClick={() => setAAnular(detalle)}>
              <i className="bi bi-x-circle me-1" />Anular venta
            </button>
          ) : null
        }
      >
        {detalle && (
          <>
            <div className="row small mb-3 g-2">
              <div className="col-sm-6"><strong>Cliente:</strong> {detalle.cliente} ({detalle.cliente_documento})</div>
              <div className="col-sm-6"><strong>Vendedor:</strong> {detalle.vendedor}</div>
              <div className="col-sm-6"><strong>Fecha:</strong> {formatoFecha(detalle.fecha)}</div>
              <div className="col-sm-6"><strong>Estado:</strong> <EstadoVenta estado={detalle.estado} /></div>
            </div>
            <div className="table-responsive">
              <table className="table table-sm align-middle">
                <thead>
                  <tr>
                    <th>Producto</th>
                    <th className="text-end">Cant.</th>
                    <th className="text-end">Precio</th>
                    <th className="text-end">Subtotal</th>
                  </tr>
                </thead>
                <tbody>
                  {detalle.items.map((i) => (
                    <tr key={i.producto_id}>
                      <td className="ajustar">{i.codigo} · {i.producto}</td>
                      <td className="text-end">{i.cantidad}</td>
                      <td className="text-end">{formatoMoneda(i.precio_unitario)}</td>
                      <td className="text-end">{formatoMoneda(i.subtotal)}</td>
                    </tr>
                  ))}
                </tbody>
                <tfoot>
                  <tr><td colSpan={3} className="text-end">Subtotal</td><td className="text-end">{formatoMoneda(detalle.subtotal)}</td></tr>
                  <tr><td colSpan={3} className="text-end">IVA 19 %</td><td className="text-end">{formatoMoneda(detalle.iva)}</td></tr>
                  <tr className="fw-semibold"><td colSpan={3} className="text-end">Total</td><td className="text-end">{formatoMoneda(detalle.total)}</td></tr>
                </tfoot>
              </table>
            </div>
          </>
        )}
      </Modal>

      <ModalConfirmacion
        abierto={!!aAnular}
        titulo="Anular venta"
        textoConfirmar="Anular"
        mensaje={`¿Anular la venta #${aAnular?.id}? El stock de sus productos se devolverá al inventario.`}
        onConfirmar={anular}
        onCancelar={() => setAAnular(null)}
      />
    </>
  )
}
