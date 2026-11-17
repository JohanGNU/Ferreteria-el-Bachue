// Rutas de la aplicación. Cada página indica qué roles pueden entrar.
import { Navigate, Route, Routes } from 'react-router-dom'
import Layout from './components/Layout'
import RutaProtegida from './components/RutaProtegida'
import Auditoria from './pages/Auditoria'
import Categorias from './pages/Categorias'
import Clientes from './pages/Clientes'
import Inicio from './pages/Inicio'
import Login from './pages/Login'
import NuevaVenta from './pages/NuevaVenta'
import Productos from './pages/Productos'
import Proveedores from './pages/Proveedores'
import Reportes from './pages/Reportes'
import Usuarios from './pages/Usuarios'
import Ventas from './pages/Ventas'

const AMBOS = ['admin', 'vendedor']
const ADMIN = ['admin']

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route
        element={
          <RutaProtegida roles={AMBOS}>
            <Layout />
          </RutaProtegida>
        }
      >
        {/* ---- Johan ---- */}
        <Route index element={<Inicio />} />
        <Route path="productos" element={<Productos />} />
        <Route path="categorias" element={<RutaProtegida roles={ADMIN}><Categorias /></RutaProtegida>} />
        <Route path="ventas" element={<Ventas />} />
        <Route path="ventas/nueva" element={<NuevaVenta />} />
        {/* ---- Michel ---- */}
        <Route path="clientes" element={<Clientes />} />
        <Route path="proveedores" element={<RutaProtegida roles={ADMIN}><Proveedores /></RutaProtegida>} />
        <Route path="usuarios" element={<RutaProtegida roles={ADMIN}><Usuarios /></RutaProtegida>} />
        <Route path="reportes" element={<RutaProtegida roles={ADMIN}><Reportes /></RutaProtegida>} />
        <Route path="auditoria" element={<RutaProtegida roles={ADMIN}><Auditoria /></RutaProtegida>} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}
