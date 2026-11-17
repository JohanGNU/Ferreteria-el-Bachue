-- =====================================================================
-- Ferretería El Bachué - vistas y consultas de reportes (init 03)
-- Vistas (A8): vw_ventas_detalle, vw_ventas_categoria_mes,
--              vw_top_productos, vw_stock_bajo
-- Consultas avanzadas (A9), empaquetadas como funciones para que la API
-- solo las llame con parámetros:
--   - JOIN de 3+ tablas:   vw_ventas_detalle (6 tablas)
--   - Subconsulta:         fn_reporte_clientes_sobre_promedio()
--   - GROUP BY + HAVING:   fn_reporte_categorias_sobre_monto(p_monto)
-- Montos de reportes: sin IVA (cantidad x precio histórico), salvo donde
-- se indique que usan fn_total_venta.
-- =====================================================================

-- ---------------------------------------------------------------------
-- vw_ventas_detalle: una fila por producto vendido, con todo su contexto.
-- JOIN de 6 tablas: ventas, clientes, usuarios, detalle_venta, productos,
-- categorias. Base de los demás reportes de ventas.
-- Uso en la app: reporte "Detalle de ventas" (filtro por fechas y categoría).
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_ventas_detalle AS
SELECT v.id                            AS venta_id,
       v.fecha,
       v.estado,
       v.cliente_id,
       c.nombre                        AS cliente,
       c.documento                     AS cliente_documento,
       v.usuario_id,
       u.nombre                        AS vendedor,
       d.producto_id,
       p.codigo,
       p.nombre                        AS producto,
       p.categoria_id,
       cat.nombre                      AS categoria,
       d.cantidad,
       d.precio_unitario,
       d.cantidad * d.precio_unitario  AS subtotal
FROM ventas v
JOIN clientes      c   ON c.id   = v.cliente_id
JOIN usuarios      u   ON u.id   = v.usuario_id
JOIN detalle_venta d   ON d.venta_id = v.id
JOIN productos     p   ON p.id   = d.producto_id
JOIN categorias    cat ON cat.id = p.categoria_id;

-- ---------------------------------------------------------------------
-- vw_ventas_categoria_mes: total vendido por categoría y mes (solo PAGADAS).
-- Uso en la app: gráfica de barras "Ventas por categoría y mes".
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_ventas_categoria_mes AS
SELECT date_trunc('month', fecha)::date  AS mes,
       categoria_id,
       categoria,
       SUM(cantidad)                     AS unidades,
       SUM(subtotal)                     AS total
FROM vw_ventas_detalle
WHERE estado = 'PAGADA'
GROUP BY date_trunc('month', fecha)::date, categoria_id, categoria;

-- ---------------------------------------------------------------------
-- vw_top_productos: ranking de productos por unidades vendidas (PAGADAS).
-- RANK() es una función de ventana: empates comparten puesto.
-- Uso en la app: gráfica "Top de productos más vendidos".
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_top_productos AS
SELECT RANK() OVER (ORDER BY SUM(d.cantidad) DESC)  AS puesto,
       p.id                                          AS producto_id,
       p.codigo,
       p.nombre                                      AS producto,
       cat.nombre                                    AS categoria,
       SUM(d.cantidad)                               AS unidades_vendidas,
       SUM(d.cantidad * d.precio_unitario)           AS total_vendido
FROM detalle_venta d
JOIN ventas     v   ON v.id   = d.venta_id
JOIN productos  p   ON p.id   = d.producto_id
JOIN categorias cat ON cat.id = p.categoria_id
WHERE v.estado = 'PAGADA'
GROUP BY p.id, p.codigo, p.nombre, cat.nombre;

-- ---------------------------------------------------------------------
-- vw_stock_bajo: productos activos en estado BAJO o AGOTADO (fn_estado_stock).
-- Uso en la app: alerta del dashboard (inicio).
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_stock_bajo AS
SELECT p.id                                    AS producto_id,
       p.codigo,
       p.nombre                                AS producto,
       cat.nombre                              AS categoria,
       pr.nombre                               AS proveedor,
       p.stock,
       p.stock_minimo,
       fn_estado_stock(p.stock, p.stock_minimo) AS estado,
       p.stock_minimo * 2 - p.stock            AS sugerido_pedir  -- para quedar en el doble del mínimo
FROM productos p
JOIN categorias  cat ON cat.id = p.categoria_id
JOIN proveedores pr  ON pr.id  = p.proveedor_id
WHERE p.activo
  AND fn_estado_stock(p.stock, p.stock_minimo) <> 'OK';

-- ---------------------------------------------------------------------
-- A9 - Subconsulta: clientes cuyo total comprado supera el promedio de
-- compras por cliente. La subconsulta interna calcula ese promedio.
-- Totales con IVA (fn_total_venta), solo ventas PAGADAS.
-- Uso en la app: reporte "Clientes sobre el promedio".
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_reporte_clientes_sobre_promedio()
RETURNS TABLE (cliente_id integer, cliente varchar, documento varchar,
               numero_compras bigint, total_comprado numeric,
               promedio_general numeric, clasificacion varchar)
LANGUAGE sql
STABLE
AS $$
    WITH compras AS (
        SELECT v.cliente_id,
               COUNT(*)                 AS numero_compras,
               SUM(fn_total_venta(v.id)) AS total_comprado
        FROM ventas v
        WHERE v.estado = 'PAGADA'
        GROUP BY v.cliente_id
    )
    SELECT c.id, c.nombre, c.documento,
           co.numero_compras,
           co.total_comprado,
           round((SELECT AVG(total_comprado) FROM compras), 2),
           fn_clasificar_cliente(c.id)
    FROM compras co
    JOIN clientes c ON c.id = co.cliente_id
    WHERE co.total_comprado > (SELECT AVG(total_comprado) FROM compras)
    ORDER BY co.total_comprado DESC;
$$;

-- ---------------------------------------------------------------------
-- A9 - GROUP BY + HAVING: categorías cuyas ventas (sin IVA, PAGADAS)
-- superan un monto. El monto llega como parámetro desde la app.
-- Uso en la app: reporte "Categorías sobre un monto".
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_reporte_categorias_sobre_monto(p_monto numeric)
RETURNS TABLE (categoria_id integer, categoria varchar, numero_ventas bigint,
               unidades bigint, total numeric)
LANGUAGE sql
STABLE
AS $$
    SELECT cat.id,
           cat.nombre,
           COUNT(DISTINCT v.id),
           SUM(d.cantidad),
           SUM(d.cantidad * d.precio_unitario)
    FROM categorias cat
    JOIN productos     p ON p.categoria_id = cat.id
    JOIN detalle_venta d ON d.producto_id  = p.id
    JOIN ventas        v ON v.id           = d.venta_id
    WHERE v.estado = 'PAGADA'
    GROUP BY cat.id, cat.nombre
    HAVING SUM(d.cantidad * d.precio_unitario) > p_monto
    ORDER BY SUM(d.cantidad * d.precio_unitario) DESC;
$$;
