// CRUD de categorías (solo admin).
import { useState } from 'react'
import api, { mensajeError } from '../api'
import { useAlertas } from '../components/Alertas'
import Encabezado from '../components/Encabezado'
import FormularioModal, { Campo } from '../components/FormularioModal'
import ModalConfirmacion from '../components/ModalConfirmacion'
import TablaDatos, { Buscador } from '../components/TablaDatos'
import useListado from '../components/useListado'

const VACIO = { nombre: '', descripcion: '' }

export default function Categorias() {
  const alertas = useAlertas()
  const { filas, cargando, recargar, setQ } = useListado('/categorias')
  const [form, setForm] = useState(VACIO)
  const [editandoId, setEditandoId] = useState(null)
  const [abierto, setAbierto] = useState(false)
  const [aEliminar, setAEliminar] = useState(null)

  const cambiar = (campo) => (e) => setForm({ ...form, [campo]: e.target.value })

  function abrir(categoria = null) {
    setForm(categoria ? { nombre: categoria.nombre, descripcion: categoria.descripcion || '' } : VACIO)
    setEditandoId(categoria?.id ?? null)
    setAbierto(true)
  }

  async function guardar() {
    try {
      if (editandoId) {
        await api.put(`/categorias/${editandoId}`, form)
        alertas.exito('Categoría actualizada')
      } else {
        await api.post('/categorias', form)
        alertas.exito('Categoría creada')
      }
      setAbierto(false)
      recargar()
    } catch (error) {
      alertas.error(mensajeError(error))
    }
  }

  async function eliminar() {
    try {
      await api.delete(`/categorias/${aEliminar.id}`)
      alertas.exito('Categoría eliminada')
      recargar()
    } catch (error) {
      alertas.error(mensajeError(error))
    } finally {
      setAEliminar(null)
    }
  }

  const columnas = [
    { titulo: 'Nombre', campo: 'nombre' },
    { titulo: 'Descripción', campo: 'descripcion', className: 'ajustar' },
    { titulo: 'Productos', campo: 'total_productos', className: 'text-end' },
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
      <Encabezado titulo="Categorías" icono="tags">
        <button className="btn btn-primary" onClick={() => abrir()}>
          <i className="bi bi-plus-lg me-1" />Nueva categoría
        </button>
      </Encabezado>

      <div className="tarjeta p-3">
        <div className="mb-3">
          <Buscador onBuscar={setQ} placeholder="Buscar por nombre o descripción" />
        </div>
        <TablaDatos columnas={columnas} filas={filas} cargando={cargando} vacio="No se encontraron categorías" />
      </div>

      <FormularioModal
        titulo={editandoId ? 'Editar categoría' : 'Nueva categoría'}
        abierto={abierto}
        onCerrar={() => setAbierto(false)}
        onGuardar={guardar}
      >
        <div className="row g-3">
          <Campo etiqueta="Nombre" error="Entre 2 y 60 caracteres">
            <input className="form-control" required minLength={2} maxLength={60}
              value={form.nombre} onChange={cambiar('nombre')} />
          </Campo>
          <Campo etiqueta="Descripción (opcional)" error="Máximo 500 caracteres">
            <textarea className="form-control" rows={3} maxLength={500}
              value={form.descripcion} onChange={cambiar('descripcion')} />
          </Campo>
        </div>
      </FormularioModal>

      <ModalConfirmacion
        abierto={!!aEliminar}
        titulo="Eliminar categoría"
        mensaje={`¿Eliminar la categoría "${aEliminar?.nombre}"? Si tiene productos no se podrá eliminar.`}
        onConfirmar={eliminar}
        onCancelar={() => setAEliminar(null)}
      />
    </>
  )
}
