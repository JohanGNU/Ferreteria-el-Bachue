// Inicio (dashboard). Admin: indicadores del día y del mes. Ambos roles: alerta de
// stock bajo, alimentada por la vista vw_stock_bajo.
import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import api, { mensajeError } from '../api'
import { useAuth } from '../auth'
import { useAlertas } from '../components/Alertas'
import { EstadoStock } from '../components/Insignias'
import TablaDatos from '../components/TablaDatos'
import { formatoMoneda, formatoNumero } from '../formato'

function Indicador({ titulo, valor, detalle, icono }) {
  return (
    <div className="col-6 col-lg-3">
      <div className="tarjeta p-3 h-100">
        <div className="d-flex justify-content-between text-body-secondary small">
          <span>{titulo}</span>
          <i className={`bi bi-${icono}`} />
        </div>
        <div className="kpi-valor">{valor}</div>
        {detalle && <div className="small text-body-secondary">{detalle}</div>}
      </div>
    </div>
  )
}

export default function Inicio() {
  const { usuario, esAdmin } = useAuth()
  const alertas = useAlertas()
  const [resumen, setResumen] = useState(null)
  const [stockBajo, setStockBajo] = useState([])
  const [cargando, setCargando] = useState(true)

  useEffect(() => {
    api.get('/reportes/stock-bajo')
      .then(({ data }) => setStockBajo(data))
      .catch((e) => alertas.error(mensajeError(e)))
      .finally(() => setCargando(false))
    if (esAdmin) {
      api.get('/reportes/resumen').then(({ data }) => setResumen(data)).catch((e) => alertas.error(mensajeError(e)))
    }
  }, [esAdmin, alertas])

  return (
    <>
      <div className="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-4">
        <div>
          <h1 className="h4 mb-0">Hola, {usuario.nombre}</h1>
          <small className="text-body-secondary">Ferretería El Bachué · inventario y ventas</small>
        </div>
        <Link to="/ventas/nueva" className="btn btn-primary">
          <i className="bi bi-cart-plus me-1" />Nueva venta
        </Link>
      </div>

      {esAdmin && resumen && (
        <div className="row g-3 mb-4">
          <Indicador titulo="Ventas de hoy" icono="cash-coin" valor={formatoMoneda(resumen.ventas_hoy)}
            detalle={`${resumen.numero_ventas_hoy} ventas`} />
          <Indicador titulo="Ventas del mes" icono="calendar3" valor={formatoMoneda(resumen.ventas_mes)}
            detalle={`${resumen.numero_ventas_mes} ventas · con IVA`} />
          <Indicador titulo="Productos activos" icono="box-seam" valor={formatoNumero(resumen.productos_activos)} />
          <Indicador titulo="Con stock bajo" icono="exclamation-triangle" valor={formatoNumero(resumen.productos_stock_bajo)}
            detalle="BAJO o AGOTADO" />
        </div>
      )}

      <section className="tarjeta p-3">
        <div className="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-3">
          <h2 className="h6 fw-semibold mb-0">
            <i className="bi bi-exclamation-triangle text-warning me-2" />Alerta de stock bajo
          </h2>
          <small className="text-body-secondary">Fuente: <code>vw_stock_bajo</code></small>
        </div>
        {!cargando && stockBajo.length > 0 && (
          <div className="alert alert-warning py-2 small">
            Hay {stockBajo.length} producto(s) en el mínimo o agotados. Conviene pedir al proveedor.
          </div>
        )}
        <TablaDatos
          claveFila="producto_id"
          cargando={cargando}
          filas={stockBajo}
          vacio="Todo el inventario está sobre el mínimo"
          columnas={[
            { titulo: 'Código', campo: 'codigo' },
            { titulo: 'Producto', campo: 'producto', className: 'ajustar' },
            { titulo: 'Proveedor', campo: 'proveedor' },
            { titulo: 'Stock', campo: 'stock', className: 'text-end' },
            { titulo: 'Mínimo', campo: 'stock_minimo', className: 'text-end' },
            { titulo: 'Estado', render: (p) => <EstadoStock estado={p.estado} /> },
            { titulo: 'Sugerido pedir', campo: 'sugerido_pedir', className: 'text-end' },
          ]}
        />
      </section>
    </>
  )
}
