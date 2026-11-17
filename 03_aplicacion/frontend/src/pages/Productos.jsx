// CRUD de productos. Crear llama a sp_crear_producto y editar a sp_actualizar_producto
// (a través de la API). La columna Estado viene de fn_estado_stock.
// El vendedor solo consulta; los botones de edición solo se muestran al admin.
import { useEffect, useState } from 'react'
import api, { mensajeError } from '../api'
import { useAuth } from '../auth'
import { useAlertas } from '../components/Alertas'
import Encabezado from '../components/Encabezado'
import FormularioModal, { Campo } from '../components/FormularioModal'
import { Activo, EstadoStock } from '../components/Insignias'
import ModalConfirmacion from '../components/ModalConfirmacion'
import TablaDatos, { Buscador } from '../components/TablaDatos'
import useListado from '../components/useListado'
import { formatoMoneda, formatoNumero } from '../formato'

const VACIO = {
  codigo: '', nombre: '', categoria_id: '', proveedor_id: '',
  precio_compra: '', precio_venta: '', stock: '0', stock_minimo: '5', activo: true,
}

export default function Productos() {
  const { esAdmin } = useAuth()
  const alertas = useAlertas()
  const { filas, cargando, recargar, setQ } = useListado('/productos')
  const [categorias, setCategorias] = useState([])
  const [proveedores, setProveedores] = useState([])
  const [form, setForm] = useState(VACIO)
  const [editandoId, setEditandoId] = useState(null)
  const [abierto, setAbierto] = useState(false)
  const [aEliminar, setAEliminar] = useState(null)

  // Listas para los <select> del formulario (solo el admin edita)
  useEffect(() => {
    if (!esAdmin) return
    api.get('/categorias').then(({ data }) => setCategorias(data)).catch(() => {})
    api.get('/proveedores').then(({ data }) => setProveedores(data)).catch(() => {})
  }, [esAdmin])

  const cambiar = (campo) => (e) =>
    setForm({ ...form, [campo]: e.target.type === 'checkbox' ? e.target.checked : e.target.value })

  function abrirNuevo() {
    setForm(VACIO)
    setEditandoId(null)
    setAbierto(true)
  }

  function abrirEditar(p) {
    setForm({ ...p, categoria_id: String(p.categoria_id), proveedor_id: String(p.proveedor_id) })
    setEditandoId(p.id)
    setAbierto(true)
  }

  async function guardar() {
    const datos = {
      codigo: form.codigo,
      nombre: form.nombre,
      categoria_id: Number(form.categoria_id),
      proveedor_id: Number(form.proveedor_id),
      precio_compra: Number(form.precio_compra),
      precio_venta: Number(form.precio_venta),
      stock_minimo: Number(form.stock_minimo),
    }
    try {
      if (editandoId) {
        await api.put(`/productos/${editandoId}`, { ...datos, activo: form.activo })
        alertas.exito('Producto actualizado')
      } else {
        await api.post('/productos', { ...datos, stock: Number(form.stock) })
        alertas.exito('Producto creado')
      }
      setAbierto(false)
      recargar()
    } catch (error) {
      alertas.error(mensajeError(error))
    }
  }

  async function eliminar() {
    try {
      await api.delete(`/productos/${aEliminar.id}`)
      alertas.exito('Producto eliminado')
      recargar()
    } catch (error) {
      alertas.error(mensajeError(error))
    } finally {
      setAEliminar(null)
    }
  }

  const columnas = [
    { titulo: 'Código', campo: 'codigo' },
    { titulo: 'Nombre', campo: 'nombre', className: 'ajustar' },
    { titulo: 'Categoría', campo: 'categoria' },
    { titulo: 'Precio venta', render: (p) => formatoMoneda(p.precio_venta), className: 'text-end' },
    { titulo: 'Stock', render: (p) => formatoNumero(p.stock), className: 'text-end' },
    { titulo: 'Estado', render: (p) => <EstadoStock estado={p.estado_stock} /> },
    { titulo: 'Activo', render: (p) => <Activo activo={p.activo} /> },
  ]
  if (esAdmin) {
    columnas.push({
      titulo: 'Acciones',
      className: 'text-end',
      render: (p) => (
        <div className="btn-group btn-group-sm">
          <button className="btn btn-outline-primary" title="Editar" onClick={() => abrirEditar(p)}>
            <i className="bi bi-pencil" />
          </button>
          <button className="btn btn-outline-danger" title="Eliminar" onClick={() => setAEliminar(p)}>
            <i className="bi bi-trash" />
          </button>
        </div>
      ),
    })
  }

  return (
    <>
      <Encabezado titulo="Productos" icono="box-seam">
        {esAdmin && (
          <button className="btn btn-primary" onClick={abrirNuevo}>
            <i className="bi bi-plus-lg me-1" />Nuevo producto
          </button>
        )}
      </Encabezado>

      <div className="tarjeta p-3">
        <div className="mb-3">
          <Buscador onBuscar={setQ} placeholder="Buscar por nombre o código" />
        </div>
        <TablaDatos columnas={columnas} filas={filas} cargando={cargando} vacio="No se encontraron productos" />
      </div>

      <FormularioModal
        titulo={editandoId ? 'Editar producto' : 'Nuevo producto'}
        abierto={abierto}
        onCerrar={() => setAbierto(false)}
        onGuardar={guardar}
        tamano="modal-lg"
      >
        <div className="row g-3">
          <Campo etiqueta="Código" className="col-md-4" error="Letras, números y guion (máx. 20)">
            <input className="form-control text-uppercase" required maxLength={20} pattern="[A-Za-z0-9\-]+"
              value={form.codigo} onChange={cambiar('codigo')} />
          </Campo>
          <Campo etiqueta="Nombre" className="col-md-8" error="Mínimo 2 caracteres">
            <input className="form-control" required minLength={2} maxLength={120}
              value={form.nombre} onChange={cambiar('nombre')} />
          </Campo>
          <Campo etiqueta="Categoría" className="col-md-6" error="Seleccione una categoría">
            <select className="form-select" required value={form.categoria_id} onChange={cambiar('categoria_id')}>
              <option value="">Seleccione...</option>
              {categorias.map((c) => <option key={c.id} value={c.id}>{c.nombre}</option>)}
            </select>
          </Campo>
          <Campo etiqueta="Proveedor" className="col-md-6" error="Seleccione un proveedor">
            <select className="form-select" required value={form.proveedor_id} onChange={cambiar('proveedor_id')}>
              <option value="">Seleccione...</option>
              {proveedores.map((p) => <option key={p.id} value={p.id}>{p.nombre}</option>)}
            </select>
          </Campo>
          <Campo etiqueta="Precio de compra" className="col-md-6" error="Número mayor o igual a 0">
            <input type="number" className="form-control" required min={0} step="0.01"
              value={form.precio_compra} onChange={cambiar('precio_compra')} />
          </Campo>
          <Campo etiqueta="Precio de venta (sin IVA)" className="col-md-6" error="Número mayor que 0"
            ayuda="Debe ser mayor o igual al precio de compra (lo valida un trigger)">
            <input type="number" className="form-control" required min={0.01} step="0.01"
              value={form.precio_venta} onChange={cambiar('precio_venta')} />
          </Campo>
          {!editandoId && (
            <Campo etiqueta="Stock inicial" className="col-md-6" error="Entero mayor o igual a 0"
              ayuda="Queda registrado como entrada en el kardex">
              <input type="number" className="form-control" required min={0} step={1}
                value={form.stock} onChange={cambiar('stock')} />
            </Campo>
          )}
          <Campo etiqueta="Stock mínimo" className="col-md-6" error="Entero mayor o igual a 0">
            <input type="number" className="form-control" required min={0} step={1}
              value={form.stock_minimo} onChange={cambiar('stock_minimo')} />
          </Campo>
          {editandoId && (
            <div className="col-md-6 d-flex align-items-end">
              <div className="form-check form-switch mb-2">
                <input className="form-check-input" type="checkbox" id="activo"
                  checked={form.activo} onChange={cambiar('activo')} />
                <label className="form-check-label" htmlFor="activo">Producto activo</label>
              </div>
            </div>
          )}
          {editandoId && (
            <div className="col-12 form-text">
              El stock no se edita aquí: cambia con las ventas, las anulaciones y las entradas de mercancía.
            </div>
          )}
        </div>
      </FormularioModal>

      <ModalConfirmacion
        abierto={!!aEliminar}
        titulo="Eliminar producto"
        mensaje={`¿Eliminar "${aEliminar?.nombre}"? Si tiene ventas no se podrá eliminar; en ese caso desactívelo.`}
        onConfirmar={eliminar}
        onCancelar={() => setAEliminar(null)}
      />
    </>
  )
}
