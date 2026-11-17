// Registrar una venta: cliente + ítems. Al guardar, la API llama a sp_registrar_venta.
// A propósito NO se bloquea en el navegador una cantidad mayor al stock: la validación real
// la hace el trigger trg_detalle_venta_validar en la BD (RAISE + ROLLBACK de toda la venta)
// y aquí se muestra su mensaje. Solo se avisa con una advertencia.
import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import api, { mensajeError } from '../api'
import { useAlertas } from '../components/Alertas'
import Encabezado from '../components/Encabezado'
import { IVA, formatoMoneda } from '../formato'

export default function NuevaVenta() {
  const alertas = useAlertas()
  const [clientes, setClientes] = useState([])
  const [productos, setProductos] = useState([])
  const [clienteId, setClienteId] = useState('')
  const [filtro, setFiltro] = useState('')
  const [productoId, setProductoId] = useState('')
  const [cantidad, setCantidad] = useState('1')
  const [items, setItems] = useState([])
  const [errorVenta, setErrorVenta] = useState('')
  const [guardando, setGuardando] = useState(false)

  const cargarProductos = useCallback(async () => {
    const { data } = await api.get('/productos', { params: { solo_activos: true } })
    setProductos(data)
  }, [])

  useEffect(() => {
    api.get('/clientes', { params: { solo_activos: true } })
      .then(({ data }) => {
        setClientes(data)
        const consumidor = data.find((c) => c.nombre === 'Consumidor final')
        if (consumidor) setClienteId(String(consumidor.id))
      })
      .catch((e) => alertas.error(mensajeError(e)))
    cargarProductos().catch((e) => alertas.error(mensajeError(e)))
  }, [alertas, cargarProductos])

  const productosFiltrados = useMemo(() => {
    const texto = filtro.trim().toLowerCase()
    if (!texto) return productos
    return productos.filter((p) => p.nombre.toLowerCase().includes(texto) || p.codigo.toLowerCase().includes(texto))
  }, [productos, filtro])

  const porId = useMemo(() => Object.fromEntries(productos.map((p) => [p.id, p])), [productos])

  function agregar(e) {
    e.preventDefault()
    const id = Number(productoId)
    const cant = Number(cantidad)
    if (!id || !Number.isInteger(cant) || cant < 1) {
      alertas.aviso('Seleccione un producto y una cantidad entera mayor que cero')
      return
    }
    setErrorVenta('')
    setItems((actuales) => {
      const existe = actuales.find((i) => i.producto_id === id)
      if (existe) return actuales.map((i) => (i.producto_id === id ? { ...i, cantidad: i.cantidad + cant } : i))
      return [...actuales, { producto_id: id, cantidad: cant }]
    })
    setProductoId('')
    setCantidad('1')
  }

  const cambiarCantidad = (id, valor) =>
    setItems(items.map((i) => (i.producto_id === id ? { ...i, cantidad: Math.max(1, Number(valor) || 1) } : i)))

  const quitar = (id) => setItems(items.filter((i) => i.producto_id !== id))

  const subtotal = items.reduce((s, i) => s + i.cantidad * Number(porId[i.producto_id]?.precio_venta ?? 0), 0)
  const iva = Math.round(subtotal * IVA)

  async function registrar() {
    setErrorVenta('')
    setGuardando(true)
    try {
      const { data } = await api.post('/ventas', { cliente_id: Number(clienteId), items })
      alertas.exito(`Venta #${data.id} registrada por ${formatoMoneda(data.total)}`)
      setItems([])
      await cargarProductos() // el stock bajó (trigger AFTER)
    } catch (error) {
      // Error controlado: mensaje del RAISE de la BD (ej. "Stock insuficiente ...")
      const mensaje = mensajeError(error)
      setErrorVenta(mensaje)
      alertas.error(mensaje)
    } finally {
      setGuardando(false)
    }
  }

  return (
    <>
      <Encabezado titulo="Nueva venta" icono="cart-plus">
        <Link to="/ventas" className="btn btn-outline-secondary">
          <i className="bi bi-list-ul me-1" />Ver ventas
        </Link>
      </Encabezado>

      <div className="row g-3">
        <div className="col-lg-5">
          <div className="tarjeta p-3 h-100">
            <label className="form-label fw-semibold">Cliente</label>
            <select className="form-select mb-4" value={clienteId} onChange={(e) => setClienteId(e.target.value)}>
              <option value="">Seleccione...</option>
              {clientes.map((c) => (
                <option key={c.id} value={c.id}>{c.nombre} · {c.documento}</option>
              ))}
            </select>

            <form onSubmit={agregar}>
              <label className="form-label fw-semibold">Agregar producto</label>
              <input
                type="search"
                className="form-control mb-2"
                placeholder="Filtrar por nombre o código"
                value={filtro}
                onChange={(e) => setFiltro(e.target.value)}
              />
              <select className="form-select mb-2" value={productoId} onChange={(e) => setProductoId(e.target.value)}>
                <option value="">Seleccione un producto ({productosFiltrados.length})</option>
                {productosFiltrados.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.codigo} · {p.nombre} · {formatoMoneda(p.precio_venta)} · stock {p.stock}
                  </option>
                ))}
              </select>
              <div className="input-group">
                <span className="input-group-text">Cantidad</span>
                <input type="number" className="form-control" min={1} step={1}
                  value={cantidad} onChange={(e) => setCantidad(e.target.value)} />
                <button type="submit" className="btn btn-outline-primary">
                  <i className="bi bi-plus-lg me-1" />Agregar
                </button>
              </div>
            </form>
          </div>
        </div>

        <div className="col-lg-7">
          <div className="tarjeta p-3 h-100 d-flex flex-column">
            <h2 className="h6">Productos de la venta</h2>
            {errorVenta && (
              <div className="alert alert-danger py-2">
                <i className="bi bi-x-octagon me-2" />
                <strong>La venta no se registró.</strong> {errorVenta}
              </div>
            )}
            <div className="table-responsive flex-grow-1">
              <table className="table table-sm align-middle">
                <thead>
                  <tr>
                    <th>Producto</th>
                    <th className="text-end">Precio</th>
                    <th style={{ width: 110 }}>Cant.</th>
                    <th className="text-end">Subtotal</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {items.length === 0 && (
                    <tr><td colSpan={5} className="text-center text-body-secondary py-4">Agregue productos a la venta</td></tr>
                  )}
                  {items.map((i) => {
                    const p = porId[i.producto_id]
                    const supera = p && i.cantidad > p.stock
                    return (
                      <tr key={i.producto_id}>
                        <td className="ajustar">
                          {p?.codigo} · {p?.nombre}
                          {supera && (
                            <div className="small text-warning-emphasis">
                              <i className="bi bi-exclamation-triangle me-1" />Supera el stock disponible ({p.stock})
                            </div>
                          )}
                        </td>
                        <td className="text-end">{formatoMoneda(p?.precio_venta)}</td>
                        <td>
                          <input type="number" min={1} step={1} className="form-control form-control-sm"
                            value={i.cantidad} onChange={(e) => cambiarCantidad(i.producto_id, e.target.value)} />
                        </td>
                        <td className="text-end">{formatoMoneda(i.cantidad * Number(p?.precio_venta ?? 0))}</td>
                        <td className="text-end">
                          <button className="btn btn-sm btn-outline-danger" title="Quitar" onClick={() => quitar(i.producto_id)}>
                            <i className="bi bi-x-lg" />
                          </button>
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
            <div className="border-top pt-3">
              <div className="d-flex justify-content-between small"><span>Subtotal</span><span>{formatoMoneda(subtotal)}</span></div>
              <div className="d-flex justify-content-between small"><span>IVA 19 %</span><span>{formatoMoneda(iva)}</span></div>
              <div className="d-flex justify-content-between fw-semibold fs-5"><span>Total</span><span>{formatoMoneda(subtotal + iva)}</span></div>
              <button
                className="btn btn-primary w-100 mt-3"
                disabled={!clienteId || items.length === 0 || guardando}
                onClick={registrar}
              >
                {guardando && <span className="spinner-border spinner-border-sm me-2" />}
                <i className="bi bi-check2-circle me-1" />Registrar venta
              </button>
            </div>
          </div>
        </div>
      </div>
    </>
  )
}
