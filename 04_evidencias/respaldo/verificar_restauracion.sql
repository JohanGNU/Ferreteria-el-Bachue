-- Verificación de la restauración del respaldo en una BD nueva (ferreteria_restaurada).
-- Cuenta tablas, rutinas, triggers y vistas, y prueba que la lógica funciona.
\echo '--- Objetos restaurados ---'
SELECT 'tablas' AS objeto, count(*) FROM information_schema.tables
 WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
UNION ALL
SELECT 'vistas', count(*) FROM information_schema.views WHERE table_schema = 'public'
UNION ALL
SELECT 'procedimientos', count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'p'
UNION ALL
SELECT 'funciones (fn_*)', count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'f' AND p.proname LIKE 'fn\_%'
UNION ALL
SELECT 'triggers', count(*) FROM pg_trigger WHERE NOT tgisinternal
UNION ALL
SELECT 'índices idx_*', count(*) FROM pg_indexes WHERE schemaname = 'public' AND indexname LIKE 'idx\_%';

\echo '--- Datos restaurados ---'
SELECT (SELECT count(*) FROM productos) AS productos, (SELECT count(*) FROM clientes) AS clientes,
       (SELECT count(*) FROM ventas) AS ventas, (SELECT count(*) FROM auditoria) AS auditoria;

\echo '--- La lógica funciona en la copia: venta vía procedimiento y trigger de stock ---'
SELECT stock AS stock_antes FROM productos WHERE codigo = 'HM-001';
CALL sp_registrar_venta(1, 1, '[{"producto_id": 1, "cantidad": 2}]', NULL);
SELECT stock AS stock_despues, fn_estado_stock(stock, stock_minimo) AS estado FROM productos WHERE codigo = 'HM-001';
SELECT * FROM vw_top_productos ORDER BY puesto LIMIT 3;
