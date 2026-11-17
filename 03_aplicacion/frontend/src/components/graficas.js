// Configuración común de Chart.js para los reportes.
// Paleta categórica validada (8 colores en orden fijo, segura para daltonismo en
// pares adyacentes). El color sigue a la entidad (la categoría por su id), nunca
// al ranking: si un filtro cambia las barras, cada categoría conserva su color.
import { BarElement, CategoryScale, Chart, Legend, LinearScale, Tooltip } from 'chart.js'

Chart.register(CategoryScale, LinearScale, BarElement, Tooltip, Legend)
Chart.defaults.font.family = 'system-ui, -apple-system, "Segoe UI", Roboto, sans-serif'
Chart.defaults.color = '#52514e'

export const PALETA = ['#2a78d6', '#eb6834', '#1baf7a', '#eda100', '#e87ba4', '#008300', '#6250d6', '#e34948']
export const COLOR_OTROS = '#8a8a86'
export const SUPERFICIE = '#ffffff'

// Ranura de color por id de categoría (ordenadas por id). De la 9.ª en adelante: gris "otros".
export function colorPorId(idsOrdenados, id) {
  const indice = idsOrdenados.indexOf(id)
  return indice >= 0 && indice < PALETA.length ? PALETA[indice] : COLOR_OTROS
}

const compacto = new Intl.NumberFormat('es-CO', { notation: 'compact', maximumFractionDigits: 1 })
export const pesosCompacto = (v) => `$${compacto.format(v)}`

// Ejes discretos: rejilla tenue, sin bordes; el valor de cada barra va en el tooltip.
export function opcionesBarras({ horizontal = false, apilado = false, leyenda = false, formatoValor }) {
  const ejeValor = {
    beginAtZero: true,
    stacked: apilado,
    grid: { color: '#ecebe8' },
    border: { display: false },
    ticks: { callback: (v) => (formatoValor ? formatoValor(v) : v) },
  }
  const ejeCategoria = { stacked: apilado, grid: { display: false }, border: { color: '#d6d4cf' } }
  return {
    responsive: true,
    maintainAspectRatio: false,
    indexAxis: horizontal ? 'y' : 'x',
    interaction: { mode: horizontal || !apilado ? 'nearest' : 'index', intersect: false },
    scales: horizontal ? { x: ejeValor, y: ejeCategoria } : { x: ejeCategoria, y: ejeValor },
    plugins: {
      legend: { display: leyenda, position: 'bottom', labels: { boxWidth: 12, boxHeight: 12, useBorderRadius: true, borderRadius: 3 } },
      tooltip: {
        callbacks: {
          label: (ctx) => {
            const valor = horizontal ? ctx.parsed.x : ctx.parsed.y
            const texto = formatoValor ? formatoValor(valor, true) : valor
            return apilado || leyenda ? `${ctx.dataset.label}: ${texto}` : ` ${texto}`
          },
        },
      },
    },
  }
}

// Estilo de barra: extremo redondeado de 4 px y separación de 2 px con el color de fondo.
export const estiloBarra = (color) => ({
  backgroundColor: color,
  borderColor: SUPERFICIE,
  borderWidth: 2,
  borderRadius: 4,
  borderSkipped: 'start',
  maxBarThickness: 36,
})
