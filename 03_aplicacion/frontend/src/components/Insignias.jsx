// Insignias de estado reutilizadas en varias tablas. El color sigue la paleta de la marca:
// amarillo = atención, negro = lo más fuerte, rojo solo para lo anulado.
const ESTILO_STOCK = { OK: 'neutra', BAJO: 'amarilla', AGOTADO: 'negra' }
const ESTILO_CLASE = { Premium: 'negra', Frecuente: 'amarilla', Básico: 'neutra' }

const Insignia = ({ estilo, children }) => <span className={`insignia insignia-${estilo}`}>{children}</span>

export const EstadoStock = ({ estado }) => <Insignia estilo={ESTILO_STOCK[estado] || 'apagada'}>{estado}</Insignia>

export const Clasificacion = ({ valor }) => <Insignia estilo={ESTILO_CLASE[valor] || 'apagada'}>{valor}</Insignia>

export const Activo = ({ activo }) =>
  activo ? <Insignia estilo="neutra">Activo</Insignia> : <Insignia estilo="apagada">Inactivo</Insignia>

export const EstadoVenta = ({ estado }) => (
  <Insignia estilo={estado === 'PAGADA' ? 'neutra' : 'roja'}>{estado}</Insignia>
)
