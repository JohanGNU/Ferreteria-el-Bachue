// Estructura de la app: barra superior con el menú según el rol y el contenido de la página.
// En celular el menú se colapsa en el botón de hamburguesa.
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

export default function Layout() {
  const { usuario, cerrarSesion } = useAuth()
  const navegar = useNavigate()
  const [menuAbierto, setMenuAbierto] = useState(false)

  const opciones = MENU.filter((op) => op.roles.includes(usuario.rol))

  function salir() {
    cerrarSesion()
    navegar('/login')
  }

  return (
    <>
      <nav className="navbar navbar-expand-xl navbar-dark barra-principal sticky-top">
        <div className="container-fluid">
          <NavLink className="navbar-brand fw-semibold" to="/" onClick={() => setMenuAbierto(false)}>
            <i className="bi bi-tools me-2" />El Bachué
          </NavLink>
          <button
            className="navbar-toggler"
            type="button"
            aria-label="Abrir menú"
            aria-expanded={menuAbierto}
            onClick={() => setMenuAbierto(!menuAbierto)}
          >
            <span className="navbar-toggler-icon" />
          </button>
          <div className={`collapse navbar-collapse ${menuAbierto ? 'show' : ''}`}>
            <ul className="navbar-nav me-auto">
              {opciones.map((op) => (
                <li className="nav-item" key={op.ruta}>
                  <NavLink
                    to={op.ruta}
                    end={op.ruta === '/' || op.ruta === '/ventas'}
                    className="nav-link"
                    onClick={() => setMenuAbierto(false)}
                  >
                    <i className={`bi bi-${op.icono} me-1`} />{op.texto}
                  </NavLink>
                </li>
              ))}
            </ul>
            <div className="d-flex align-items-center gap-2 text-white py-2 py-xl-0">
              <i className="bi bi-person-circle" />
              <span className="small">
                {/* En pantallas medianas solo se ve el rol, para que el menú quepa en una línea */}
                <span className="d-xl-none d-xxl-inline">{usuario.nombre}</span>
                <span className="badge text-bg-light text-uppercase ms-1">{usuario.rol}</span>
              </span>
              <button className="btn btn-sm btn-outline-light ms-2" onClick={salir}>
                <i className="bi bi-box-arrow-right me-1" />Salir
              </button>
            </div>
          </div>
        </div>
      </nav>
      <main className="container-xl py-4">
        <Outlet />
      </main>
    </>
  )
}
