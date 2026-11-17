// CRUD de proveedores (solo admin) y entrada de mercancía de sus productos,
// que llama a sp_registrar_entrada (suma stock y registra ENTRADA en el kardex).
import { useState } from 'react'
import api, { mensajeError } from '../api'
import { useAlertas } from '../components/Alertas'
import Encabezado from '../components/Encabezado'
import FormularioModal, { Campo } from '../components/FormularioModal'
import { Activo, EstadoStock } from '../components/Insignias'
import ModalConfirmacion from '../components/ModalConfirmacion'
import TablaDatos, { Buscador } from '../components/TablaDatos'
import useListado from '../components/useListado'

const VACIO = { nit: '', nombre: '', telefono: '', email: '', activo: true }

export default function Proveedores() {
  const alertas = useAlertas()
  const { filas, cargando, recargar, setQ } = useListado('/proveedores')
  const [form, setForm] = useState(VACIO)
  const [editandoId, setEditandoId] = useState(null)
  const [abierto, setAbierto] = useState(false)
  const [aEliminar, setAEliminar] = useState(null)

  // Entrada de mercancía
  const [proveedorEntrada, setProveedorEntrada] = useState(null)
  const [productosProveedor, setProductosProveedor] = useState([])
  const [entrada, setEntrada] = useState({ producto_id: '', cantidad: '' })

  const cambiar = (campo) => (e) =>
    setForm({ ...form, [campo]: e.target.type === 'checkbox' ? e.target.checked : e.target.value })

  function abrir(proveedor = null) {
    setForm(proveedor ? { ...proveedor, telefono: proveedor.telefono || '', email: proveedor.email || '' } : VACIO)
    setEditandoId(proveedor?.id ?? null)
    setAbierto(true)
  }

  async function guardar() {
    const datos = { nit: form.nit, nombre: form.nombre, telefono: form.telefono, email: form.email, activo: form.activo }
    try {
      if (editandoId) {
        await api.put(`/proveedores/${editandoId}`, datos)
        alertas.exito('Proveedor actualizado')
      } else {
        await api.post('/proveedores', datos)
        alertas.exito('Proveedor creado')
      }
      setAbierto(false)
      recargar()
    } catch (error) {
      alertas.error(mensajeError(error))
    }
  }

  async function eliminar() {
    try {
      await api.delete(`/proveedores/${aEliminar.id}`)
      alertas.exito('Proveedor eliminado')
      recargar()
    } catch (error) {
      alertas.error(mensajeError(error))
    } finally {
      setAEliminar(null)
    }
  }

  async function abrirEntrada(proveedor) {
    setEntrada({ producto_id: '', cantidad: '' })
    setProductosProveedor([])
    setProveedorEntrada(proveedor)
    try {
      const { data } = await api.get('/productos', { params: { proveedor_id: proveedor.id } })
      setProductosProveedor(data)
    } catch (error) {
      alertas.error(mensajeError(error))
    }
  }

  async function registrarEntrada() {
    try {
      const { data } = await api.post(`/productos/${entrada.producto_id}/entradas`, {
        cantidad: Number(entrada.cantidad),
      })
      alertas.exito(`Entrada registrada: ${data.nombre} ahora tiene ${data.stock} unidades`)
      setProveedorEntrada(null)
    } catch (error) {
      alertas.error(mensajeError(error))
    }
  }

  const productoElegido = productosProveedor.find((p) => String(p.id) === entrada.producto_id)

  const columnas = [
    { titulo: 'NIT', campo: 'nit' },
    { titulo: 'Nombre', campo: 'nombre', className: 'ajustar' },
    { titulo: 'Teléfono', campo: 'telefono' },
    { titulo: 'Correo', campo: 'email' },
    { titulo: 'Productos', campo: 'total_productos', className: 'text-end' },
    { titulo: 'Estado', render: (p) => <Activo activo={p.activo} /> },
    {
      titulo: 'Acciones',
      className: 'text-end',
      render: (p) => (
        <div className="btn-group btn-group-sm">
          <button className="btn btn-outline-success" title="Entrada de mercancía" onClick={() => abrirEntrada(p)}>
            <i className="bi bi-box-arrow-in-down" />
          </button>
          <button className="btn btn-outline-primary" title="Editar" onClick={() => abrir(p)}>
            <i className="bi bi-pencil" />
          </button>
          <button className="btn btn-outline-danger" title="Eliminar" onClick={() => setAEliminar(p)}>
            <i className="bi bi-trash" />
          </button>
        </div>
      ),
    },
  ]

  return (
    <>
      <Encabezado titulo="Proveedores" icono="truck">
        <button className="btn btn-primary" onClick={() => abrir()}>
          <i className="bi bi-plus-lg me-1" />Nuevo proveedor
        </button>
      </Encabezado>

      <div className="tarjeta p-3">
        <div className="mb-3">
          <Buscador onBuscar={setQ} placeholder="Buscar por nombre o NIT" />
        </div>
        <TablaDatos columnas={columnas} filas={filas} cargando={cargando} vacio="No se encontraron proveedores" />
      </div>

      <FormularioModal
        titulo={editandoId ? 'Editar proveedor' : 'Nuevo proveedor'}
        abierto={abierto}
        onCerrar={() => setAbierto(false)}
        onGuardar={guardar}
      >
        <div className="row g-3">
          <Campo etiqueta="NIT" className="col-md-5" error="Solo números y guion (5 a 20)">
            <input className="form-control" required minLength={5} maxLength={20} pattern="[0-9\-]+"
              placeholder="900123456-1" value={form.nit} onChange={cambiar('nit')} />
          </Campo>
          <Campo etiqueta="Nombre" className="col-md-7" error="Mínimo 2 caracteres">
            <input className="form-control" required minLength={2} maxLength={120}
              value={form.nombre} onChange={cambiar('nombre')} />
          </Campo>
          <Campo etiqueta="Teléfono" className="col-md-5" error="Solo números, espacios y + ( ) -">
            <input type="tel" className="form-control" maxLength={20} pattern="[0-9 +()\-]+"
              value={form.telefono} onChange={cambiar('telefono')} />
          </Campo>
          <Campo etiqueta="Correo" className="col-md-7" error="Correo no válido">
            <input type="email" className="form-control" maxLength={120}
              value={form.email} onChange={cambiar('email')} />
          </Campo>
          {editandoId && (
            <div className="col-12">
              <div className="form-check form-switch">
                <input className="form-check-input" type="checkbox" id="prov-activo"
                  checked={form.activo} onChange={cambiar('activo')} />
                <label className="form-check-label" htmlFor="prov-activo">Proveedor activo</label>
              </div>
            </div>
          )}
        </div>
      </FormularioModal>

      <FormularioModal
        titulo={`Entrada de mercancía · ${proveedorEntrada?.nombre ?? ''}`}
        abierto={!!proveedorEntrada}
        onCerrar={() => setProveedorEntrada(null)}
        onGuardar={registrarEntrada}
        textoGuardar="Registrar entrada"
      >
        <div className="row g-3">
          <Campo etiqueta="Producto" error="Seleccione un producto">
            <select className="form-select" required value={entrada.producto_id}
              onChange={(e) => setEntrada({ ...entrada, producto_id: e.target.value })}>
              <option value="">Seleccione...</option>
              {productosProveedor.map((p) => (
                <option key={p.id} value={p.id}>{p.codigo} · {p.nombre} (stock {p.stock})</option>
              ))}
            </select>
          </Campo>
          {productoElegido && (
            <div className="col-12 small">
              Stock actual: <strong>{productoElegido.stock}</strong> · mínimo {productoElegido.stock_minimo} ·{' '}
              <EstadoStock estado={productoElegido.estado_stock} />
            </div>
          )}
          <Campo etiqueta="Cantidad recibida" error="Entero mayor que 0">
            <input type="number" className="form-control" required min={1} max={100000} step={1}
              value={entrada.cantidad} onChange={(e) => setEntrada({ ...entrada, cantidad: e.target.value })} />
          </Campo>
        </div>
      </FormularioModal>

      <ModalConfirmacion
        abierto={!!aEliminar}
        titulo="Eliminar proveedor"
        mensaje={`¿Eliminar "${aEliminar?.nombre}"? Si tiene productos no se podrá eliminar; en ese caso desactívelo.`}
        onConfirmar={eliminar}
        onCancelar={() => setAEliminar(null)}
      />
    </>
  )
}
