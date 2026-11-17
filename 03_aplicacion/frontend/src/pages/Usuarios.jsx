// CRUD de usuarios (solo admin). La contraseña se envía a la API, que la guarda con bcrypt.
// Al editar, la contraseña es opcional: vacía significa "no cambiarla".
import { useState } from 'react'
import api, { mensajeError } from '../api'
import { useAuth } from '../auth'
import { useAlertas } from '../components/Alertas'
import Encabezado from '../components/Encabezado'
import FormularioModal, { Campo } from '../components/FormularioModal'
import { Activo } from '../components/Insignias'
import ModalConfirmacion from '../components/ModalConfirmacion'
import TablaDatos, { Buscador } from '../components/TablaDatos'
import useListado from '../components/useListado'

const VACIO = { nombre: '', email: '', rol: 'vendedor', password: '', activo: true }

export default function Usuarios() {
  const { usuario: actual } = useAuth()
  const alertas = useAlertas()
  const { filas, cargando, recargar, setQ } = useListado('/usuarios')
  const [form, setForm] = useState(VACIO)
  const [editandoId, setEditandoId] = useState(null)
  const [abierto, setAbierto] = useState(false)
  const [aEliminar, setAEliminar] = useState(null)

  const cambiar = (campo) => (e) =>
    setForm({ ...form, [campo]: e.target.type === 'checkbox' ? e.target.checked : e.target.value })

  function abrir(usuario = null) {
    setForm(usuario ? { ...usuario, password: '' } : VACIO)
    setEditandoId(usuario?.id ?? null)
    setAbierto(true)
  }

  async function guardar() {
    const datos = { nombre: form.nombre, email: form.email, rol: form.rol, activo: form.activo, password: form.password }
    try {
      if (editandoId) {
        await api.put(`/usuarios/${editandoId}`, datos)
        alertas.exito('Usuario actualizado')
      } else {
        await api.post('/usuarios', datos)
        alertas.exito('Usuario creado')
      }
      setAbierto(false)
      recargar()
    } catch (error) {
      alertas.error(mensajeError(error))
    }
  }

  async function eliminar() {
    try {
      await api.delete(`/usuarios/${aEliminar.id}`)
      alertas.exito('Usuario eliminado')
      recargar()
    } catch (error) {
      alertas.error(mensajeError(error))
    } finally {
      setAEliminar(null)
    }
  }

  const esYo = editandoId === actual.id

  const columnas = [
    { titulo: 'Nombre', campo: 'nombre' },
    { titulo: 'Correo', campo: 'email' },
    {
      titulo: 'Rol',
      render: (u) => (
        <span className={`badge ${u.rol === 'admin' ? 'text-bg-dark' : 'text-bg-light border'}`}>{u.rol}</span>
      ),
    },
    { titulo: 'Estado', render: (u) => <Activo activo={u.activo} /> },
    {
      titulo: 'Acciones',
      className: 'text-end',
      render: (u) => (
        <div className="btn-group btn-group-sm">
          <button className="btn btn-outline-primary" title="Editar" onClick={() => abrir(u)}>
            <i className="bi bi-pencil" />
          </button>
          <button className="btn btn-outline-danger" title="Eliminar" disabled={u.id === actual.id}
            onClick={() => setAEliminar(u)}>
            <i className="bi bi-trash" />
          </button>
        </div>
      ),
    },
  ]

  return (
    <>
      <Encabezado titulo="Usuarios" icono="person-gear">
        <button className="btn btn-primary" onClick={() => abrir()}>
          <i className="bi bi-plus-lg me-1" />Nuevo usuario
        </button>
      </Encabezado>

      <div className="tarjeta p-3">
        <div className="mb-3">
          <Buscador onBuscar={setQ} placeholder="Buscar por nombre o correo" />
        </div>
        <TablaDatos columnas={columnas} filas={filas} cargando={cargando} vacio="No se encontraron usuarios" />
      </div>

      <FormularioModal
        titulo={editandoId ? 'Editar usuario' : 'Nuevo usuario'}
        abierto={abierto}
        onCerrar={() => setAbierto(false)}
        onGuardar={guardar}
      >
        <div className="row g-3">
          <Campo etiqueta="Nombre" error="Entre 2 y 100 caracteres">
            <input className="form-control" required minLength={2} maxLength={100}
              value={form.nombre} onChange={cambiar('nombre')} />
          </Campo>
          <Campo etiqueta="Correo" className="col-md-7" error="Correo no válido">
            <input type="email" className="form-control" required maxLength={120} autoComplete="off"
              value={form.email} onChange={cambiar('email')} />
          </Campo>
          <Campo etiqueta="Rol" className="col-md-5">
            <select className="form-select" required value={form.rol} onChange={cambiar('rol')} disabled={esYo}>
              <option value="vendedor">Vendedor</option>
              <option value="admin">Administrador</option>
            </select>
          </Campo>
          <Campo
            etiqueta={editandoId ? 'Nueva contraseña (opcional)' : 'Contraseña'}
            error="Entre 8 y 72 caracteres"
            ayuda={editandoId ? 'Déjela vacía para conservar la actual' : undefined}
          >
            <input type="password" className="form-control" required={!editandoId} minLength={8} maxLength={72}
              autoComplete="new-password" value={form.password} onChange={cambiar('password')} />
          </Campo>
          {editandoId && (
            <div className="col-12">
              <div className="form-check form-switch">
                <input className="form-check-input" type="checkbox" id="usu-activo" disabled={esYo}
                  checked={form.activo} onChange={cambiar('activo')} />
                <label className="form-check-label" htmlFor="usu-activo">Usuario activo</label>
              </div>
            </div>
          )}
        </div>
      </FormularioModal>

      <ModalConfirmacion
        abierto={!!aEliminar}
        titulo="Eliminar usuario"
        mensaje={`¿Eliminar a "${aEliminar?.nombre}"? Si ya registró ventas no se podrá eliminar; en ese caso desactívelo.`}
        onConfirmar={eliminar}
        onCancelar={() => setAEliminar(null)}
      />
    </>
  )
}
