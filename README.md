# Ferretería El Bachué

Aplicativo web de inventario y ventas para una ferretería de barrio: catálogo de productos, clientes, proveedores, ventas con control de stock, reportes con gráficas y auditoría de cambios.

Proyecto final de **Bases de Datos II**. Ruta A (relacional, PostgreSQL). La lógica de negocio vive en la base de datos: procedimientos almacenados, funciones, triggers, vistas y transacciones.

**Integrantes:** Johan González y Michel Yepez.

- Repositorio: https://github.com/JohanGNU/Ferreteria-el-Bachue
- Despliegue: _pendiente_

## Tecnologías

| Capa | Tecnología |
|---|---|
| Base de datos | PostgreSQL 17, PL/pgSQL, extensión `pg_trgm` |
| Backend | Python 3.13, FastAPI, psycopg 3 (SQL con parámetros, sin ORM), Pydantic, PyJWT, bcrypt |
| Frontend | React 18 + Vite, React Router, Bootstrap 5, Chart.js (react-chartjs-2), axios |
| Infraestructura | Docker Compose: `db`, `api`, `web` y `pgadmin` |

## Requisitos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) con Docker Compose v2.
- Git.
- Puertos libres: `5432` (PostgreSQL), `8000` (API), `5173` (web) y `5050` (pgAdmin).

No hace falta instalar Python, Node ni PostgreSQL en el equipo: todo corre en contenedores.

## Instalación paso a paso

### 1. Clonar el repositorio

```bash
git clone https://github.com/JohanGNU/Ferreteria-el-Bachue.git
cd Ferreteria-el-Bachue/03_aplicacion
```

### 2. Configurar el archivo `.env`

Copie la plantilla y cambie las contraseñas por valores propios:

```bash
cp .env.example .env
```

| Variable | Para qué sirve |
|---|---|
| `POSTGRES_DB` | Nombre de la base de datos (`ferreteria`) |
| `POSTGRES_USER`, `POSTGRES_PASSWORD` | Superusuario de PostgreSQL. Solo se usa para crear la BD y correr los scripts. |
| `APP_DB_USER`, `APP_DB_PASSWORD` | Usuario limitado `app_ferreteria` con el que se conecta la aplicación |
| `DATABASE_URL` | Cadena de conexión de la API. Debe usar `APP_DB_USER`, `APP_DB_PASSWORD` y el host `db`. |
| `JWT_SECRET` | Clave para firmar los tokens de sesión (cadena larga y aleatoria) |
| `JWT_EXPIRE_MINUTES` | Duración de la sesión en minutos |
| `PGADMIN_EMAIL`, `PGADMIN_PASSWORD` | Acceso a pgAdmin |

La contraseña de `APP_DB_PASSWORD` debe ser la misma que va dentro de `DATABASE_URL`.

> El archivo `.env` está en `.gitignore`: nunca se sube a GitHub. Solo se sube `.env.example`, sin contraseñas reales.

### 3. Levantar la aplicación (crea la base de datos automáticamente)

```bash
docker compose up --build
```

La primera vez, el contenedor de PostgreSQL ejecuta en orden los scripts de `02_base_de_datos/`:

| Orden | Script | Contenido |
|---|---|---|
| 01 | `script_creacion.sql` | 10 tablas, restricciones e índices |
| 02 | `rutinas_triggers.sql` | Funciones, procedimientos y triggers |
| 03 | `consultas_reportes.sql` | Vistas y consultas de reportes |
| 04 | `datos_prueba.sql` | Datos de prueba: 22 productos, 10 clientes y 31 ventas registradas con `CALL sp_registrar_venta` |
| 05 | `init_usuario_app.sh` | Usuario `app_ferreteria` con permisos limitados |

Cuando termine, abra:

- **Aplicación:** http://localhost:5173
- **API (documentación interactiva):** http://localhost:8000/docs
- **pgAdmin:** http://localhost:5050. Para conectar el servidor use el host `db`, el puerto `5432` y el usuario y la clave de `.env`.

### Recrear la base de datos desde cero

Los scripts de inicio solo corren cuando el volumen de datos está vacío. Para volver al estado inicial **(borra todos los datos)**:

```bash
docker compose down -v
docker compose up --build
```

## Usuarios de prueba

| Rol | Correo | Contraseña | Puede |
|---|---|---|---|
| Administrador | `admin@ferreteria.com` | `Admin123*` | Todo: productos, categorías, proveedores, clientes, usuarios, ventas (incluida la anulación), reportes y auditoría |
| Vendedor | `vendedor@ferreteria.com` | `Vendedor123*` | Registrar y consultar ventas, gestionar clientes y consultar productos (solo lectura) |

El menú cambia según el rol. El control real lo hace la API, que valida el rol en cada petición y responde 403 si no corresponde.

## Módulos

- **Inicio:** indicadores del día y del mes, y alerta de stock bajo (vista `vw_stock_bajo`).
- **Productos:** CRUD. Crear y editar van por procedimiento almacenado. La columna de estado de stock viene de `fn_estado_stock`.
- **Categorías, proveedores, clientes y usuarios:** CRUD con búsqueda, validación y confirmación al eliminar.
- **Entrada de mercancía:** desde Proveedores, con `sp_registrar_entrada`.
- **Ventas:** nueva venta (transacción en `sp_registrar_venta`), listado con total (`fn_total_venta`), detalle y anulación (`sp_anular_venta`).
- **Reportes:** ventas por categoría y mes, top de productos, clientes sobre el promedio, categorías sobre un monto y detalle de ventas.
- **Auditoría:** cambios en productos, clientes y usuarios, con el usuario que los hizo.

## Lógica en la base de datos

| Tipo | Objetos |
|---|---|
| Procedimientos (6) | `sp_registrar_venta` (IN/OUT, WHILE, COMMIT/ROLLBACK), `sp_anular_venta` (cursor), `sp_crear_producto` (OUT), `sp_actualizar_producto`, `sp_eliminar_cliente` (IF/ELSE, OUT), `sp_registrar_entrada` |
| Funciones (3) | `fn_total_venta` (subtotal + IVA 19 %), `fn_estado_stock` (IF/ELSIF/ELSE), `fn_clasificar_cliente` (CASE) |
| Triggers (4) | `trg_detalle_venta_validar` (BEFORE), `trg_detalle_venta_stock` (AFTER), `trg_productos_validar_precio` (BEFORE), `trg_auditoria` (AFTER, en 3 tablas) |
| Vistas (4) | `vw_ventas_detalle` (JOIN de 6 tablas), `vw_ventas_categoria_mes`, `vw_top_productos`, `vw_stock_bajo` |
| Consultas A9 | `fn_reporte_clientes_sobre_promedio` (subconsulta) y `fn_reporte_categorias_sobre_monto` (GROUP BY + HAVING) |
| Índices (3) | `idx_ventas_fecha`, `idx_detalle_venta_producto`, `idx_productos_nombre_trgm` (GIN) |

**Error controlado para la demostración:** en *Nueva venta*, agregue un producto con una cantidad mayor que su stock. El trigger `trg_detalle_venta_validar` lanza `RAISE EXCEPTION 'Stock insuficiente ...'`. `sp_registrar_venta` hace `ROLLBACK` de toda la venta y la pantalla muestra el mensaje de la base de datos.

## Seguridad

- Contraseñas guardadas con **bcrypt**; la auditoría nunca guarda el hash.
- Todas las consultas usan **parámetros** (`%s` de psycopg): nunca se concatena texto del usuario.
- La aplicación se conecta como **`app_ferreteria`**:
  - Tiene SELECT, INSERT, UPDATE y DELETE sobre las tablas y EXECUTE sobre las rutinas.
  - No puede crear objetos ni escribir en `auditoria`; esa tabla solo la llena el trigger, que es `SECURITY DEFINER`.
- Sesiones con **JWT**: header `Authorization: Bearer <token>`.
- Validación doble: HTML5 en los formularios y Pydantic en la API. Los errores se devuelven en español.

## Evidencias

- `04_evidencias/indices/`: `EXPLAIN ANALYZE` antes y después de los índices, con 100 000 productos, 500 000 ventas y 1 500 000 líneas de detalle generadas con `generate_series`.

  | Consulta | Sin índice | Con índice |
  |---|---|---|
  | Ventas de la última semana (`idx_ventas_fecha`) | 42,3 ms (Seq Scan) | 1,0 ms (Index Only Scan) |
  | Unidades vendidas de un producto (`idx_detalle_venta_producto`) | 45,5 ms (Seq Scan) | 0,07 ms (Bitmap Index Scan) |
  | Búsqueda `ILIKE '%pulidora cobre%'` (`idx_productos_nombre_trgm`) | 79,2 ms (Seq Scan) | 3,8 ms (Bitmap Index Scan) |

- `04_evidencias/respaldo/prueba_restauracion.txt`: restauración del respaldo en una BD nueva, con conteo de objetos y una venta de prueba.

## Respaldo y restauración

El respaldo completo (estructura, rutinas, triggers, vistas y datos) está en `02_base_de_datos/respaldo/ferreteria_respaldo.sql`.

Para generarlo de nuevo, se crea dentro del contenedor y se copia afuera (en PowerShell no se redirige con `>`, porque cambia la codificación):

```bash
docker compose exec db pg_dump -U postgres -d ferreteria --encoding=UTF8 -f /tmp/ferreteria_respaldo.sql
docker compose cp db:/tmp/ferreteria_respaldo.sql ../02_base_de_datos/respaldo/ferreteria_respaldo.sql
```

Para restaurarlo en una base de datos nueva:

```bash
docker compose cp ../02_base_de_datos/respaldo/ferreteria_respaldo.sql db:/tmp/ferreteria_respaldo.sql
docker compose exec db createdb -U postgres ferreteria_restaurada
docker compose exec db psql -U postgres -d ferreteria_restaurada -v ON_ERROR_STOP=1 -f /tmp/ferreteria_respaldo.sql
```

El respaldo incluye los permisos de `app_ferreteria`, así que ese rol debe existir en el servidor donde se restaura. Dentro del contenedor ya existe. El archivo usa `\restrict`, por lo que requiere `psql` 17.6 o superior; el del contenedor cumple.

## Estructura del repositorio

```text
01_documento/          Informe del proyecto (PDF)
02_base_de_datos/      Modelo ER, scripts SQL y respaldo
03_aplicacion/         docker-compose.yml, .env.example, backend/ (FastAPI) y frontend/ (React)
04_evidencias/         Capturas y evidencias de índices y respaldo
```

## Problemas frecuentes

- **El puerto 5432 está ocupado:** hay un PostgreSQL local corriendo. Deténgalo o cambie el puerto publicado en `docker-compose.yml` (por ejemplo `"5433:5432"`).
- **Cambié un script SQL y no se aplica:** los scripts solo corren con el volumen vacío. Use `docker compose down -v`.
- **`invalid transaction termination` al llamar un procedimiento:** los procedimientos con `COMMIT`/`ROLLBACK` deben llamarse en autocommit. La API ya lo hace.
