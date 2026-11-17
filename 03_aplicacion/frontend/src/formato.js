// Formatos para Colombia: pesos sin decimales y fechas en hora de Bogotá.
const moneda = new Intl.NumberFormat('es-CO', {
  style: 'currency',
  currency: 'COP',
  maximumFractionDigits: 0,
})

const numero = new Intl.NumberFormat('es-CO')

export const formatoMoneda = (valor) => moneda.format(Number(valor ?? 0))
export const formatoNumero = (valor) => numero.format(Number(valor ?? 0))

export function formatoFecha(valor, conHora = true) {
  if (!valor) return ''
  return new Date(valor).toLocaleString('es-CO', {
    timeZone: 'America/Bogota',
    year: 'numeric',
    month: 'short',
    day: '2-digit',
    ...(conHora ? { hour: '2-digit', minute: '2-digit' } : {}),
  })
}

export function formatoMes(valor) {
  // "2026-10-01" -> "oct 2026" (se arma a mano para no correr el día por la zona horaria)
  const [anio, mes] = String(valor).split('-').map(Number)
  const nombres = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic']
  return `${nombres[mes - 1]} ${anio}`
}

export const IVA = 0.19
