// Inicio (dashboard). Admin: indicadores del día y del mes. Ambos roles: alerta de
// stock bajo, alimentada por la vista vw_stock_bajo.
import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import api, { mensajeError } from '../api'
import { useAuth } from '../auth'
import { useAlertas } from '../components/Alertas'
import Encabezado from '../components/Encabezado'
import { EstadoStock } from '../components/Insignias'
import TablaDatos from '../components/TablaDatos'
import { formatoMoneda, formatoNumero } from '../formato'

function Indicador({ titulo, valor, detalle, icono }) {
  return (
    <div className="indicador">
      <div className="indicador-titulo">
        <span>{titulo}</span>
        <i className={`bi bi-${icono}`} aria-hidden="true" />
      </div>
      <div className="indicador-valor">{valor}</div>
      {detalle && <div className="indicador-detalle">{detalle}</div>}
    </div>
  )
}

// Fecha de hoy en palabras, para el subtítulo del inicio (p. ej. "martes, 17 de noviembre de 2026")
const hoy = () => new Intl.DateTimeFormat('es-CO', { dateStyle: 'full' }).format(new Date())

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
      <Encabezado titulo={`Hola, ${usuario.nombre}`} subtitulo={hoy()}>
        <Link to="/ventas/nueva" className="btn btn-primary">
          <i className="bi bi-cart-plus me-1" />Nueva venta
        </Link>
      </Encabezado>

      {esAdmin && resumen && (
        <div className="franja-indicadores">
          <Indicador titulo="Ventas de hoy" icono="cash-coin" valor={formatoMoneda(resumen.ventas_hoy)}
            detalle={`${resumen.numero_ventas_hoy} ventas`} />
          <Indicador titulo="Ventas del mes" icono="calendar3" valor={formatoMoneda(resumen.ventas_mes)}
            detalle={`${resumen.numero_ventas_mes} ventas, con IVA`} />
          <Indicador titulo="Productos activos" icono="box-seam" valor={formatoNumero(resumen.productos_activos)} />
          <Indicador titulo="Con stock bajo" icono="exclamation-triangle" valor={formatoNumero(resumen.productos_stock_bajo)}
            detalle="BAJO o AGOTADO" />
        </div>
      )}

      <section className="tarjeta p-3">
        <h2 className="mb-3">Alerta de stock bajo</h2>
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
