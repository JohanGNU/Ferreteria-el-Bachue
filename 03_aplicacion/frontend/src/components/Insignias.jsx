// Insignias de estado reutilizadas en varias tablas.
const COLORES_STOCK = { OK: 'success', BAJO: 'warning', AGOTADO: 'danger' }
const COLORES_CLASE = { Premium: 'primary', Frecuente: 'info', Básico: 'secondary' }

export const EstadoStock = ({ estado }) => (
  <span className={`badge text-bg-${COLORES_STOCK[estado] || 'secondary'}`}>{estado}</span>
)

export const Clasificacion = ({ valor }) => (
  <span className={`badge text-bg-${COLORES_CLASE[valor] || 'secondary'}`}>{valor}</span>
)

export const Activo = ({ activo }) =>
  activo ? <span className="badge text-bg-success">Activo</span> : <span className="badge text-bg-secondary">Inactivo</span>

export const EstadoVenta = ({ estado }) => (
  <span className={`badge text-bg-${estado === 'PAGADA' ? 'success' : 'danger'}`}>{estado}</span>
)
