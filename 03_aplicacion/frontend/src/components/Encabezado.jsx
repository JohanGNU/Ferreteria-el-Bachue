// Título de cada pantalla (rótulo condensado con el icono en un cuadro amarillo),
// un subtítulo opcional y los botones de acción a la derecha.
export default function Encabezado({ titulo, icono, subtitulo, children }) {
  return (
    <header className="encabezado">
      <div>
        <h1 className="titulo-pagina">
          {icono && (
            <span className="icono" aria-hidden="true">
              <i className={`bi bi-${icono}`} />
            </span>
          )}
          {titulo}
        </h1>
        {subtitulo && <p className="subtitulo-pagina">{subtitulo}</p>}
      </div>
      {children && <div className="d-flex flex-wrap gap-2">{children}</div>}
    </header>
  )
}
