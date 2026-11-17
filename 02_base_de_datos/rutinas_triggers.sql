-- =====================================================================
-- Ferretería El Bachué - rutinas y triggers (init 02)
-- Funciones, procedimientos almacenados y triggers.
-- Archivo compartido: cada integrante escribe solo en su sección.
-- =====================================================================


-- =====================================================================
-- SECCIÓN JOHAN
-- fn_total_venta, fn_estado_stock, sp_registrar_venta, sp_anular_venta,
-- sp_crear_producto, sp_actualizar_producto,
-- trg_detalle_venta_validar, trg_detalle_venta_stock
-- =====================================================================


-- =====================================================================
-- SECCIÓN MICHEL
-- fn_clasificar_cliente, sp_eliminar_cliente, sp_registrar_entrada,
-- trg_productos_validar_precio, trg_auditoria
--
-- Nota para trg_auditoria: la API ejecuta en cada request
--   SELECT set_config('app.usuario_id', '<id>', false)
-- y en el login lo deja en ''. Leerlo con:
--   NULLIF(current_setting('app.usuario_id', true), '')::integer
-- =====================================================================
