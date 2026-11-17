// Reportes (solo admin). Cada bloque lee una vista o una función de consultas_reportes.sql:
//  - Ventas por categoría y mes  -> vw_ventas_categoria_mes
//  - Top de productos            -> vw_top_productos
//  - Clientes sobre el promedio  -> fn_reporte_clientes_sobre_promedio (subconsulta)
//  - Categorías sobre un monto   -> fn_reporte_categorias_sobre_monto (GROUP BY + HAVING)
//  - Detalle de ventas           -> vw_ventas_detalle (JOIN de 6 tablas)
import { useCallback, useEffect, useState } from 'react'
import { Bar } from 'react-chartjs-2'
import api, { mensajeError } from '../api'
import { useAlertas } from '../components/Alertas'
import Encabezado from '../components/Encabezado'
import { COLOR_UNICO, colorPorId, estiloBarra, opcionesBarras, pesosCompacto } from '../components/graficas'
import { Clasificacion } from '../components/Insignias'
import TablaDatos from '../components/TablaDatos'
import { formatoFecha, formatoMes, formatoMoneda, formatoNumero } from '../formato'

const dinero = (v, completo) => (completo ? formatoMoneda(v) : pesosCompacto(v))

function Tarjeta({ titulo, controles, children }) {
  return (
    <section className="tarjeta p-3 mb-4">
      <div className="d-flex flex-wrap justify-content-between align-items-start gap-2 mb-3">
        <h2 className="h6 mb-0">{titulo}</h2>
        {controles}
      </div>
      {children}
    </section>
  )
}

function useReporte(ruta, params) {
  const alertas = useAlertas()
  const [datos, setDatos] = useState([])
  const [cargando, setCargando] = useState(true)
  const clave = JSON.stringify(params)
  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      const { data } = await api.get(ruta, { params: JSON.parse(clave) })
      setDatos(data)
    } catch (error) {
      alertas.error(mensajeError(error))
    } finally {
      setCargando(false)
    }
  }, [ruta, clave, alertas])
  useEffect(() => { cargar() }, [cargar])
  return { datos, cargando }
}

// ------------------------------------------------------------------ categoría y mes
function VentasCategoriaMes({ idsCategorias }) {
  const [meses, setMeses] = useState(4)
  const { datos } = useReporte('/reportes/ventas-categoria-mes', { meses })

  const etiquetasMes = [...new Set(datos.map((d) => d.mes))].sort()
  const categorias = [...new Map(datos.map((d) => [d.categoria_id, d.categoria])).entries()]
    .sort((a, b) => a[0] - b[0])
  const series = categorias.map(([id, nombre]) => ({
    label: nombre,
    data: etiquetasMes.map((mes) => Number(datos.find((d) => d.mes === mes && d.categoria_id === id)?.total ?? 0)),
    ...estiloBarra(colorPorId(idsCategorias, id)),
    stack: 'ventas',
  }))

  return (
    <Tarjeta
      titulo="Ventas por categoría y mes (sin IVA)"
      controles={
        <select className="form-select form-select-sm" style={{ width: 'auto' }} value={meses}
          onChange={(e) => setMeses(Number(e.target.value))} aria-label="Meses">
          <option value={3}>Últimos 3 meses</option>
          <option value={4}>Últimos 4 meses</option>
          <option value={6}>Últimos 6 meses</option>
          <option value={12}>Últimos 12 meses</option>
        </select>
      }
    >
      <div className="grafica">
        <Bar
          data={{ labels: etiquetasMes.map(formatoMes), datasets: series }}
          options={opcionesBarras({ apilado: true, leyenda: true, formatoValor: dinero })}
        />
      </div>
    </Tarjeta>
  )
}

// ------------------------------------------------------------------ top productos
function TopProductos() {
  const [limite, setLimite] = useState(10)
  const { datos } = useReporte('/reportes/top-productos', { limite })
  return (
    <Tarjeta
      titulo="Top de productos más vendidos (unidades)"
      controles={
        <select className="form-select form-select-sm" style={{ width: 'auto' }} value={limite}
          onChange={(e) => setLimite(Number(e.target.value))} aria-label="Cantidad">
          <option value={5}>Top 5</option>
          <option value={10}>Top 10</option>
          <option value={15}>Top 15</option>
        </select>
      }
    >
      <div className="grafica" style={{ height: Math.max(220, datos.length * 30 + 40) }}>
        <Bar
          data={{
            labels: datos.map((d) => `${d.puesto}. ${d.producto}`),
            datasets: [{ label: 'Unidades', data: datos.map((d) => d.unidades_vendidas), ...estiloBarra(COLOR_UNICO) }],
          }}
          options={opcionesBarras({ horizontal: true, formatoValor: (v, completo) => (completo ? `${formatoNumero(v)} unidades` : formatoNumero(v)) })}
        />
      </div>
    </Tarjeta>
  )
}

// ------------------------------------------------------------------ clientes sobre el promedio
function ClientesSobrePromedio() {
  const { datos, cargando } = useReporte('/reportes/clientes-sobre-promedio', {})
  const promedio = datos[0]?.promedio_general
  return (
    <Tarjeta titulo="Clientes con compras sobre el promedio (con IVA)">
      {promedio !== undefined && (
        <p className="small mb-2">Promedio de compras por cliente: <strong>{formatoMoneda(promedio)}</strong></p>
      )}
      <TablaDatos
        claveFila="cliente_id"
        cargando={cargando}
        filas={datos}
        vacio="Ningún cliente supera el promedio"
        columnas={[
          { titulo: 'Cliente', campo: 'cliente', className: 'ajustar' },
          { titulo: 'Documento', campo: 'documento' },
          { titulo: 'Compras', campo: 'numero_compras', className: 'text-end' },
          { titulo: 'Total comprado', render: (c) => formatoMoneda(c.total_comprado), className: 'text-end' },
          { titulo: 'Clasificación', render: (c) => <Clasificacion valor={c.clasificacion} /> },
        ]}
      />
    </Tarjeta>
  )
}

// ------------------------------------------------------------------ categorías sobre un monto
function CategoriasSobreMonto({ idsCategorias }) {
  const [monto, setMonto] = useState(500000)
  const [montoAplicado, setMontoAplicado] = useState(500000)
  const { datos, cargando } = useReporte('/reportes/categorias-sobre-monto', { monto: montoAplicado })

  return (
    <Tarjeta
      titulo="Categorías con ventas sobre un monto (sin IVA)"
      controles={
        <form className="input-group input-group-sm" style={{ width: 260 }}
          onSubmit={(e) => { e.preventDefault(); setMontoAplicado(monto) }}>
          <span className="input-group-text">Monto &gt;</span>
          <input type="number" className="form-control" min={0} step={10000} required
            value={monto} onChange={(e) => setMonto(e.target.value)} />
          <button className="btn btn-outline-primary" type="submit">Aplicar</button>
        </form>
      }
    >
      <div className="row g-3">
        <div className="col-lg-7">
          <div className="grafica" style={{ height: Math.max(200, datos.length * 40 + 40) }}>
            <Bar
              data={{
                labels: datos.map((d) => d.categoria),
                datasets: [{
                  label: 'Ventas',
                  data: datos.map((d) => Number(d.total)),
                  ...estiloBarra(datos.map((d) => colorPorId(idsCategorias, d.categoria_id))),
                }],
              }}
              options={opcionesBarras({ horizontal: true, formatoValor: dinero })}
            />
          </div>
        </div>
        <div className="col-lg-5">
          <TablaDatos
            claveFila="categoria_id"
            cargando={cargando}
            filas={datos}
            vacio="Ninguna categoría supera ese monto"
            columnas={[
              { titulo: 'Categoría', campo: 'categoria' },
              { titulo: 'Ventas', campo: 'numero_ventas', className: 'text-end' },
              { titulo: 'Total', render: (d) => formatoMoneda(d.total), className: 'text-end' },
            ]}
          />
        </div>
      </div>
    </Tarjeta>
  )
}

// ------------------------------------------------------------------ detalle de ventas
function DetalleVentas({ categorias }) {
  const hoy = new Date()
  const haceUnMes = new Date(hoy.getFullYear(), hoy.getMonth() - 1, hoy.getDate())
  const iso = (d) => d.toLocaleDateString('en-CA', { timeZone: 'America/Bogota' })
  const [filtros, setFiltros] = useState({ desde: iso(haceUnMes), hasta: iso(hoy), categoria_id: '' })
  const { datos, cargando } = useReporte('/reportes/ventas-detalle', {
    desde: filtros.desde || undefined,
    hasta: filtros.hasta || undefined,
    categoria_id: filtros.categoria_id || undefined,
  })
  const cambiar = (campo) => (e) => setFiltros({ ...filtros, [campo]: e.target.value })
  const total = datos.reduce((s, d) => s + Number(d.subtotal), 0)

  return (
    <Tarjeta titulo="Detalle de ventas (sin IVA)">
      <div className="row g-2 align-items-end mb-3">
        <div className="col-6 col-md-3">
          <label className="form-label small mb-1">Desde</label>
          <input type="date" className="form-control form-control-sm" value={filtros.desde} onChange={cambiar('desde')} />
        </div>
        <div className="col-6 col-md-3">
          <label className="form-label small mb-1">Hasta</label>
          <input type="date" className="form-control form-control-sm" value={filtros.hasta} onChange={cambiar('hasta')} />
        </div>
        <div className="col-12 col-md-3">
          <label className="form-label small mb-1">Categoría</label>
          <select className="form-select form-select-sm" value={filtros.categoria_id} onChange={cambiar('categoria_id')}>
            <option value="">Todas</option>
            {categorias.map((c) => <option key={c.id} value={c.id}>{c.nombre}</option>)}
          </select>
        </div>
        <div className="col-12 col-md-3 text-md-end small">
          {datos.length} líneas · <strong>{formatoMoneda(total)}</strong>
        </div>
      </div>
      <div style={{ maxHeight: 420, overflow: 'auto' }}>
        <TablaDatos
          claveFila="clave"
          cargando={cargando}
          filas={datos.map((d) => ({ ...d, clave: `${d.venta_id}-${d.codigo}` }))}
          vacio="No hay ventas en ese rango"
          columnas={[
            { titulo: 'Venta', campo: 'venta_id' },
            { titulo: 'Fecha', render: (d) => formatoFecha(d.fecha) },
            { titulo: 'Cliente', campo: 'cliente', className: 'ajustar' },
            { titulo: 'Producto', render: (d) => `${d.codigo} · ${d.producto}`, className: 'ajustar' },
            { titulo: 'Categoría', campo: 'categoria' },
            { titulo: 'Cant.', campo: 'cantidad', className: 'text-end' },
            { titulo: 'Subtotal', render: (d) => formatoMoneda(d.subtotal), className: 'text-end' },
          ]}
        />
      </div>
    </Tarjeta>
  )
}

export default function Reportes() {
  const [categorias, setCategorias] = useState([])
  useEffect(() => {
    api.get('/categorias').then(({ data }) => setCategorias([...data].sort((a, b) => a.id - b.id))).catch(() => {})
  }, [])
  const idsCategorias = categorias.map((c) => c.id)

  return (
    <>
      <Encabezado titulo="Reportes" icono="bar-chart" />
      <VentasCategoriaMes idsCategorias={idsCategorias} />
      <div className="row g-0 gx-lg-4">
        <div className="col-lg-6"><TopProductos /></div>
        <div className="col-lg-6"><ClientesSobrePromedio /></div>
      </div>
      <CategoriasSobreMonto idsCategorias={idsCategorias} />
      <DetalleVentas categorias={categorias} />
    </>
  )
}
