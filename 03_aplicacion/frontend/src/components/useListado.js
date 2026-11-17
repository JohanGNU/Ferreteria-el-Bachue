// Hook para cargar un listado de la API con búsqueda y filtros.
// Devuelve las filas, el estado de carga y una función para recargar después de guardar.
import { useCallback, useEffect, useState } from 'react'
import api, { mensajeError } from '../api'
import { useAlertas } from './Alertas'

export default function useListado(ruta, filtros = {}) {
  const alertas = useAlertas()
  const [filas, setFilas] = useState([])
  const [cargando, setCargando] = useState(true)
  const [q, setQ] = useState('')
  const clave = JSON.stringify(filtros)

  const recargar = useCallback(async () => {
    setCargando(true)
    try {
      const params = { ...JSON.parse(clave), q: q || undefined }
      const { data } = await api.get(ruta, { params })
      setFilas(data)
    } catch (error) {
      alertas.error(mensajeError(error))
    } finally {
      setCargando(false)
    }
  }, [ruta, clave, q, alertas])

  useEffect(() => {
    recargar()
  }, [recargar])

  return { filas, cargando, recargar, setQ }
}
