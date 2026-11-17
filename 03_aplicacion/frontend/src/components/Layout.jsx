// Estructura de la app: menú lateral negro con las opciones según el rol y el contenido a la derecha.
// En celular y tableta el menú pasa a una barra superior que se despliega con el botón de menú.
import { useState } from 'react'
import { NavLink, Outlet, useNavigate } from 'react-router-dom'
import { useAuth } from '../auth'

// roles: quién ve cada opción. La API vuelve a validar el rol en cada petición.
export const MENU = [
  { ruta: '/', texto: 'Inicio', icono: 'house', roles: ['admin', 'vendedor'] },
  { ruta: '/ventas/nueva', texto: 'Nueva venta', icono: 'cart-plus', roles: ['admin', 'vendedor'] },
  { ruta: '/ventas', texto: 'Ventas', icono: 'receipt', roles: ['admin', 'vendedor'] },
  { ruta: '/productos', texto: 'Productos', icono: 'box-seam', roles: ['admin', 'vendedor'] },
  { ruta: '/clientes', texto: 'Clientes', icono: 'people', roles: ['admin', 'vendedor'] },
  { ruta: '/categorias', texto: 'Categorías', icono: 'tags', roles: ['admin'] },
  { ruta: '/proveedores', texto: 'Proveedores', icono: 'truck', roles: ['admin'] },
  { ruta: '/usuarios', texto: 'Usuarios', icono: 'person-gear', roles: ['admin'] },
  { ruta: '/reportes', texto: 'Reportes', icono: 'bar-chart', roles: ['admin'] },
  { ruta: '/auditoria', texto: 'Auditoría', icono: 'shield-check', roles: ['admin'] },
]

const NOMBRE_ROL = { admin: 'Administrador', vendedor: 'Vendedor' }

export default function Layout() {
  const { usuario, cerrarSesion } = useAuth()
  const navegar = useNavigate()
  const [menuAbierto, setMenuAbierto] = useState(false)

  // Las opciones de ambos roles van arriba; las exclusivas del admin, en su propio grupo.
  const comunes = MENU.filter((op) => op.roles.includes(usuario.rol) && op.roles.length > 1)
  const soloAdmin = MENU.filter((op) => op.roles.includes(usuario.rol) && op.roles.length === 1)
  const cerrarMenu = () => setMenuAbierto(false)

  function salir() {
    cerrarSesion()
    navegar('/login')
  }

  const enlace = (op) => (
    <li key={op.ruta}>
      <NavLink to={op.ruta} end={op.ruta === '/' || op.ruta === '/ventas'} onClick={cerrarMenu}>
        <i className={`bi bi-${op.icono}`} aria-hidden="true" />{op.texto}
      </NavLink>
    </li>
  )

  return (
    <div className="marco">
      <aside className={`lateral ${menuAbierto ? 'abierto' : ''}`}>
        <div className="lateral-cabeza">
          <NavLink className="marca" to="/" onClick={cerrarMenu}>
            El Bachué
            <small>Ferretería</small>
          </NavLink>
          <button
            className="boton-menu"
            type="button"
            aria-label={menuAbierto ? 'Cerrar menú' : 'Abrir menú'}
            aria-expanded={menuAbierto}
            onClick={() => setMenuAbierto(!menuAbierto)}
          >
            <i className={`bi bi-${menuAbierto ? 'x-lg' : 'list'}`} />
          </button>
        </div>
        <div className="lateral-cuerpo">
          <nav className="menu" aria-label="Menú principal">
            <ul className="list-unstyled m-0">{comunes.map(enlace)}</ul>
            {soloAdmin.length > 0 && (
              <>
                <div className="menu-grupo">Administración</div>
                <ul className="list-unstyled m-0">{soloAdmin.map(enlace)}</ul>
              </>
            )}
          </nav>
          <div className="lateral-pie">
            <div className="fw-semibold text-truncate">{usuario.nombre}</div>
            <div className="rol mb-2">{NOMBRE_ROL[usuario.rol] || usuario.rol}</div>
            <button className="btn btn-sm btn-salir w-100" onClick={salir}>
              <i className="bi bi-box-arrow-right me-1" />Cerrar sesión
            </button>
          </div>
        </div>
      </aside>
      <main className="contenido">
        <Outlet />
      </main>
    </div>
  )
}
