// Título de cada pantalla con un botón de acción opcional a la derecha.
export default function Encabezado({ titulo, icono, children }) {
  return (
    <div className="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-3">
      <h1 className="h4 mb-0">
        {icono && <i className={`bi bi-${icono} me-2 text-primary`} />}
        {titulo}
      </h1>
      <div className="d-flex flex-wrap gap-2">{children}</div>
    </div>
  )
}
