// CRUD de clientes (admin y vendedor). La clasificación viene de fn_clasificar_cliente.
// Eliminar llama a sp_eliminar_cliente: si el cliente tiene ventas lo desactiva.
import { useState } from 'react'
import api, { mensajeError } from '../api'
import { useAlertas } from '../components/Alertas'
import Encabezado from '../components/Encabezado'
import FormularioModal, { Campo } from '../components/FormularioModal'
import { Activo, Clasificacion } from '../components/Insignias'
import ModalConfirmacion from '../components/ModalConfirmacion'
import TablaDatos, { Buscador } from '../components/TablaDatos'
import useListado from '../components/useListado'

const VACIO = { documento: '', nombre: '', telefono: '', email: '', activo: true }

export default function Clientes() {
  const alertas = useAlertas()
  const { filas, cargando, recargar, setQ } = useListado('/clientes')
  const [form, setForm] = useState(VACIO)
  const [editandoId, setEditandoId] = useState(null)
  const [abierto, setAbierto] = useState(false)
  const [aEliminar, setAEliminar] = useState(null)

  const cambiar = (campo) => (e) =>
    setForm({ ...form, [campo]: e.target.type === 'checkbox' ? e.target.checked : e.target.value })

  function abrir(cliente = null) {
    setForm(cliente ? { ...cliente, telefono: cliente.telefono || '', email: cliente.email || '' } : VACIO)
    setEditandoId(cliente?.id ?? null)
    setAbierto(true)
  }

  async function guardar() {
    const datos = {
      documento: form.documento, nombre: form.nombre, telefono: form.telefono, email: form.email, activo: form.activo,
    }
    try {
      if (editandoId) {
        await api.put(`/clientes/${editandoId}`, datos)
        alertas.exito('Cliente actualizado')
      } else {
        await api.post('/clientes', datos)
        alertas.exito('Cliente creado')
      }
      setAbierto(false)
      recargar()
    } catch (error) {
      alertas.error(mensajeError(error))
    }
  }

  async function eliminar() {
    try {
      const { data } = await api.delete(`/clientes/${aEliminar.id}`)
      if (data.resultado === 'DESACTIVADO') alertas.aviso(data.detail)
      else alertas.exito(data.detail)
      recargar()
    } catch (error) {
      alertas.error(mensajeError(error))
    } finally {
      setAEliminar(null)
    }
  }

  const columnas = [
    { titulo: 'Documento', campo: 'documento' },
    { titulo: 'Nombre', campo: 'nombre', className: 'ajustar' },
    { titulo: 'Teléfono', campo: 'telefono' },
    { titulo: 'Correo', campo: 'email' },
    { titulo: 'Clasificación', render: (c) => <Clasificacion valor={c.clasificacion} /> },
    { titulo: 'Estado', render: (c) => <Activo activo={c.activo} /> },
    {
      titulo: 'Acciones',
      className: 'text-end',
      render: (c) => (
        <div className="btn-group btn-group-sm">
          <button className="btn btn-outline-primary" title="Editar" onClick={() => abrir(c)}>
            <i className="bi bi-pencil" />
          </button>
          <button className="btn btn-outline-danger" title="Eliminar" onClick={() => setAEliminar(c)}>
            <i className="bi bi-trash" />
          </button>
        </div>
      ),
    },
  ]

  return (
    <>
      <Encabezado titulo="Clientes" icono="people">
        <button className="btn btn-primary" onClick={() => abrir()}>
          <i className="bi bi-plus-lg me-1" />Nuevo cliente
        </button>
      </Encabezado>

      <div className="tarjeta p-3">
        <div className="d-flex flex-wrap gap-3 align-items-center mb-3">
          <Buscador onBuscar={setQ} placeholder="Buscar por nombre o documento" />
          <small className="text-body-secondary">
            Clasificación por compras: Premium ≥ $1.000.000 · Frecuente ≥ $300.000 · Básico
          </small>
        </div>
        <TablaDatos columnas={columnas} filas={filas} cargando={cargando} vacio="No se encontraron clientes" />
      </div>

      <FormularioModal
        titulo={editandoId ? 'Editar cliente' : 'Nuevo cliente'}
        abierto={abierto}
        onCerrar={() => setAbierto(false)}
        onGuardar={guardar}
      >
        <div className="row g-3">
          <Campo etiqueta="Documento o NIT" className="col-md-5" error="Solo números y guion (5 a 20)">
            <input className="form-control" required minLength={5} maxLength={20} pattern="[0-9\-]+"
              value={form.documento} onChange={cambiar('documento')} />
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
                <input className="form-check-input" type="checkbox" id="cli-activo"
                  checked={form.activo} onChange={cambiar('activo')} />
                <label className="form-check-label" htmlFor="cli-activo">Cliente activo</label>
              </div>
            </div>
          )}
        </div>
      </FormularioModal>

      <ModalConfirmacion
        abierto={!!aEliminar}
        titulo="Eliminar cliente"
        mensaje={`¿Eliminar a "${aEliminar?.nombre}"? Si tiene ventas registradas, se desactivará en lugar de eliminarse.`}
        onConfirmar={eliminar}
        onCancelar={() => setAEliminar(null)}
      />
    </>
  )
}
