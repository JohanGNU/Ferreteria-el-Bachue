import React from 'react'
import ReactDOM from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import 'bootstrap/dist/css/bootstrap.min.css'
import 'bootstrap-icons/font/bootstrap-icons.css'
// Archivo variable con eje de ancho (wdth): los títulos usan la versión condensada
import '@fontsource-variable/archivo/wdth.css'
import './estilos.css'
import App from './App'
import { AuthProvider } from './auth'
import { AlertasProvider } from './components/Alertas'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <BrowserRouter>
      <AlertasProvider>
        <AuthProvider>
          <App />
        </AuthProvider>
      </AlertasProvider>
    </BrowserRouter>
  </React.StrictMode>,
)
