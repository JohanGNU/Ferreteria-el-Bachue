-- =====================================================================
-- Ferretería El Bachué - script de creación (init 01)
-- Tablas, restricciones e índices. Modelo en 3FN, 10 tablas.
-- Motor: PostgreSQL 17
-- =====================================================================

-- Extensión para búsqueda por similitud de texto (índice GIN trigram)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Hora de Colombia para fechas y reportes por día/mes (aplica a sesiones nuevas)
DO $$
BEGIN
    EXECUTE format('ALTER DATABASE %I SET timezone TO %L', current_database(), 'America/Bogota');
END;
$$;

-- ---------------------------------------------------------------------
-- 1. roles: perfiles de acceso a la aplicación (admin, vendedor)
-- ---------------------------------------------------------------------
CREATE TABLE roles (
    id      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre  varchar(30) NOT NULL UNIQUE
);

-- ---------------------------------------------------------------------
-- 2. usuarios: personas que inician sesión. La contraseña va con bcrypt.
-- ---------------------------------------------------------------------
CREATE TABLE usuarios (
    id             integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre         varchar(100) NOT NULL,
    email          varchar(120) NOT NULL UNIQUE,
    password_hash  varchar(100) NOT NULL,
    rol_id         integer NOT NULL REFERENCES roles (id),
    activo         boolean NOT NULL DEFAULT true,
    CONSTRAINT ck_usuarios_email CHECK (email LIKE '_%@_%._%')
);

-- ---------------------------------------------------------------------
-- 3. categorias
-- ---------------------------------------------------------------------
CREATE TABLE categorias (
    id           integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       varchar(60) NOT NULL UNIQUE,
    descripcion  text
);

-- ---------------------------------------------------------------------
-- 4. proveedores
-- ---------------------------------------------------------------------
CREATE TABLE proveedores (
    id        integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nit       varchar(20) NOT NULL UNIQUE,
    nombre    varchar(120) NOT NULL,
    telefono  varchar(20),
    email     varchar(120),
    activo    boolean NOT NULL DEFAULT true,
    CONSTRAINT ck_proveedores_email CHECK (email IS NULL OR email LIKE '_%@_%._%')
);

-- ---------------------------------------------------------------------
-- 5. productos. stock = saldo actual, mantenido por triggers y procedimientos;
--    el historial está en movimientos_inventario.
-- ---------------------------------------------------------------------
CREATE TABLE productos (
    id             integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo         varchar(20) NOT NULL UNIQUE,
    nombre         varchar(120) NOT NULL,
    categoria_id   integer NOT NULL REFERENCES categorias (id),
    proveedor_id   integer NOT NULL REFERENCES proveedores (id),
    precio_compra  numeric(12,2) NOT NULL CHECK (precio_compra >= 0),
    precio_venta   numeric(12,2) NOT NULL CHECK (precio_venta > 0),
    stock          integer NOT NULL DEFAULT 0 CHECK (stock >= 0),
    stock_minimo   integer NOT NULL DEFAULT 5 CHECK (stock_minimo >= 0),
    activo         boolean NOT NULL DEFAULT true
);

-- ---------------------------------------------------------------------
-- 6. clientes
-- ---------------------------------------------------------------------
CREATE TABLE clientes (
    id         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    documento  varchar(20) NOT NULL UNIQUE,
    nombre     varchar(120) NOT NULL,
    telefono   varchar(20),
    email      varchar(120),
    activo     boolean NOT NULL DEFAULT true,
    CONSTRAINT ck_clientes_email CHECK (email IS NULL OR email LIKE '_%@_%._%')
);

-- ---------------------------------------------------------------------
-- 7. ventas. No guarda el total: se calcula con fn_total_venta (evita
--    datos derivados que se puedan desincronizar del detalle).
-- ---------------------------------------------------------------------
CREATE TABLE ventas (
    id          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cliente_id  integer NOT NULL REFERENCES clientes (id),
    usuario_id  integer NOT NULL REFERENCES usuarios (id),
    fecha       timestamptz NOT NULL DEFAULT now(),
    estado      varchar(10) NOT NULL DEFAULT 'PAGADA'
                CHECK (estado IN ('PAGADA', 'ANULADA'))
);

-- ---------------------------------------------------------------------
-- 8. detalle_venta. precio_unitario es el precio histórico del momento de
--    la venta (lo fija el trigger), no una copia redundante del producto.
-- ---------------------------------------------------------------------
CREATE TABLE detalle_venta (
    id               integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    venta_id         integer NOT NULL REFERENCES ventas (id),
    producto_id      integer NOT NULL REFERENCES productos (id),
    cantidad         integer NOT NULL CHECK (cantidad > 0),
    precio_unitario  numeric(12,2) NOT NULL CHECK (precio_unitario > 0),
    CONSTRAINT uq_detalle_venta_producto UNIQUE (venta_id, producto_id)
);

-- ---------------------------------------------------------------------
-- 9. movimientos_inventario (kardex). ENTRADA no tiene venta;
--    SALIDA y DEVOLUCION siempre apuntan a la venta que las causó.
--    ON DELETE CASCADE: si se borra un producto sin ventas, se borra su kardex.
-- ---------------------------------------------------------------------
CREATE TABLE movimientos_inventario (
    id           integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    producto_id  integer NOT NULL REFERENCES productos (id) ON DELETE CASCADE,
    tipo         varchar(12) NOT NULL
                 CHECK (tipo IN ('ENTRADA', 'SALIDA', 'DEVOLUCION')),
    cantidad     integer NOT NULL CHECK (cantidad > 0),
    usuario_id   integer NOT NULL REFERENCES usuarios (id),
    venta_id     integer REFERENCES ventas (id),
    fecha        timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_movimientos_venta CHECK (tipo = 'ENTRADA' OR venta_id IS NOT NULL)
);

-- ---------------------------------------------------------------------
-- 10. auditoria. Sin FK a propósito: debe conservar el rastro de filas
--     borradas y de usuarios que ya no existan. La llena trg_auditoria.
-- ---------------------------------------------------------------------
CREATE TABLE auditoria (
    id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tabla          varchar(50) NOT NULL,
    operacion      varchar(10) NOT NULL
                   CHECK (operacion IN ('INSERT', 'UPDATE', 'DELETE')),
    registro_id    integer,
    usuario_id     integer,
    datos_antes    jsonb,
    datos_despues  jsonb,
    fecha          timestamptz NOT NULL DEFAULT now()
);

-- =====================================================================
-- Índices (A10). La evidencia EXPLAIN ANALYZE está en 04_evidencias/.
-- =====================================================================

-- Reportes de ventas por rango de fechas (WHERE fecha BETWEEN ...)
CREATE INDEX idx_ventas_fecha ON ventas (fecha);

-- PostgreSQL no indexa las FK automáticamente; acelera el top de productos
-- (JOIN/GROUP BY por producto_id en detalle_venta)
CREATE INDEX idx_detalle_venta_producto ON detalle_venta (producto_id);

-- Búsqueda de productos con ILIKE '%texto%' (un B-tree no sirve para eso)
CREATE INDEX idx_productos_nombre_trgm ON productos USING gin (nombre gin_trgm_ops);
