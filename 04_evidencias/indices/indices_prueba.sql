-- =====================================================================
-- Evidencia de índices (A10): EXPLAIN ANALYZE antes y después.
-- Con los ~30 registros de prueba el planificador ignora los índices
-- (leer toda la tabla es más barato), por eso se usa una BD aparte con
-- datos masivos generados con generate_series.
--
-- Ejecutar dentro del contenedor (como postgres):
--   docker compose exec -T db psql -U postgres -d postgres < ../04_evidencias/indices/indices_prueba.sql
-- La salida queda en 04_evidencias/indices/resultado_explain.txt
-- =====================================================================
\set ON_ERROR_STOP 1
DROP DATABASE IF EXISTS ferreteria_indices;
CREATE DATABASE ferreteria_indices;
\c ferreteria_indices

-- Mismas tablas e índices del proyecto
\i /docker-entrypoint-initdb.d/01_script_creacion.sql

\echo '>>> Cargando datos masivos...'
INSERT INTO roles (nombre) VALUES ('admin');
INSERT INTO usuarios (nombre, email, password_hash, rol_id)
VALUES ('Admin', 'admin@prueba.com', 'x', 1);
INSERT INTO categorias (nombre) SELECT 'Categoría ' || g FROM generate_series(1, 8) g;
INSERT INTO proveedores (nit, nombre) VALUES ('900000000-0', 'Proveedor de prueba');

-- 100 000 productos con nombres variados
INSERT INTO productos (codigo, nombre, categoria_id, proveedor_id, precio_compra, precio_venta, stock)
SELECT 'P' || g,
       (ARRAY['Martillo','Taladro','Tornillo','Destornillador','Alicate','Llave','Cable','Tubo',
              'Pintura','Brocha','Cemento','Manguera','Sierra','Pulidora','Bombillo','Chazo'])[1 + g % 16]
       || ' ' ||
       (ARRAY['acero','PVC','cobre','industrial','básico','profesional','galvanizado','eléctrico'])[1 + (g / 16) % 8]
       || ' ' || g,
       1 + g % 8, 1, 1000, 1500, 1000
FROM generate_series(1, 100000) g;

INSERT INTO clientes (documento, nombre)
SELECT '10' || g, 'Cliente ' || g FROM generate_series(1, 5000) g;

-- 500 000 ventas repartidas en 2 años
INSERT INTO ventas (cliente_id, usuario_id, fecha, estado)
SELECT 1 + (g % 5000), 1, now() - random() * interval '730 days', 'PAGADA'
FROM generate_series(1, 500000) g;

-- 1 500 000 líneas de detalle (3 productos por venta). Se insertan sin los
-- triggers de la app porque esta BD solo tiene tablas e índices.
INSERT INTO detalle_venta (venta_id, producto_id, cantidad, precio_unitario)
SELECT v.id, 1 + ((v.id * 7 + k * 13) % 100000), 1 + k, 1500
FROM ventas v CROSS JOIN generate_series(1, 3) k;

SELECT (SELECT count(*) FROM productos) AS productos,
       (SELECT count(*) FROM ventas) AS ventas,
       (SELECT count(*) FROM detalle_venta) AS detalle_venta;

-- =====================================================================
-- ANTES: sin los 3 índices
-- =====================================================================
DROP INDEX idx_ventas_fecha;
DROP INDEX idx_detalle_venta_producto;
DROP INDEX idx_productos_nombre_trgm;
ANALYZE;

\echo ''
\echo '################ ANTES (sin índices) ################'
\echo '--- 1. Ventas de la última semana (reporte por rango de fechas) ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) AS ventas, min(fecha), max(fecha)
FROM ventas
WHERE fecha >= now() - interval '7 days';

\echo '--- 2. Unidades vendidas de un producto (detalle_venta por producto_id) ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT producto_id, sum(cantidad) AS unidades
FROM detalle_venta
WHERE producto_id = 4242
GROUP BY producto_id;

\echo '--- 3. Buscador de productos con ILIKE ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, codigo, nombre
FROM productos
WHERE nombre ILIKE '%pulidora cobre%';

-- =====================================================================
-- DESPUÉS: se crean los índices (mismas sentencias de script_creacion.sql)
-- =====================================================================
CREATE INDEX idx_ventas_fecha ON ventas (fecha);
CREATE INDEX idx_detalle_venta_producto ON detalle_venta (producto_id);
CREATE INDEX idx_productos_nombre_trgm ON productos USING gin (nombre gin_trgm_ops);
ANALYZE;

\echo ''
\echo '################ DESPUÉS (con índices) ################'
\echo '--- 1. Ventas de la última semana: idx_ventas_fecha ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) AS ventas, min(fecha), max(fecha)
FROM ventas
WHERE fecha >= now() - interval '7 days';

\echo '--- 2. Unidades vendidas de un producto: idx_detalle_venta_producto ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT producto_id, sum(cantidad) AS unidades
FROM detalle_venta
WHERE producto_id = 4242
GROUP BY producto_id;

\echo '--- 3. Buscador de productos con ILIKE: idx_productos_nombre_trgm ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, codigo, nombre
FROM productos
WHERE nombre ILIKE '%pulidora cobre%';

-- Limpieza: la BD de prueba no se necesita después de tomar la evidencia
\c postgres
DROP DATABASE ferreteria_indices;
