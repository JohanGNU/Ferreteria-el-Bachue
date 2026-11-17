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

-- ---------------------------------------------------------------------
-- fn_total_venta: total de una venta = subtotal + IVA 19 %.
-- La venta no guarda el total; se calcula desde el detalle (precio histórico).
-- Uso en la app: listado y detalle de ventas (GET /api/ventas).
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_total_venta(p_venta_id integer)
RETURNS numeric
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    c_iva       CONSTANT numeric := 0.19;
    v_subtotal  numeric(12,2);
BEGIN
    SELECT COALESCE(SUM(cantidad * precio_unitario), 0)
      INTO v_subtotal
      FROM detalle_venta
     WHERE venta_id = p_venta_id;

    RETURN round(v_subtotal * (1 + c_iva), 2);
END;
$$;

-- ---------------------------------------------------------------------
-- fn_estado_stock: IF / ELSEIF / ELSE que clasifica el stock.
-- Uso en la app: columna "Estado" del listado de productos.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_estado_stock(p_stock integer, p_minimo integer)
RETURNS varchar
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF p_stock <= 0 THEN
        RETURN 'AGOTADO';
    ELSIF p_stock <= p_minimo THEN
        RETURN 'BAJO';
    ELSE
        RETURN 'OK';
    END IF;
END;
$$;

-- ---------------------------------------------------------------------
-- trg_detalle_venta_validar (BEFORE INSERT en detalle_venta)
-- Bloquea la fila del producto (FOR UPDATE) para que dos ventas simultáneas
-- no vendan el mismo stock, valida y fija el precio histórico.
-- Si algo falla hace RAISE: la venta completa se revierte.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_detalle_venta_validar()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock   integer;
    v_precio  numeric(12,2);
    v_nombre  varchar;
    v_activo  boolean;
BEGIN
    IF NEW.cantidad IS NULL OR NEW.cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad debe ser mayor que cero';
    END IF;

    SELECT stock, precio_venta, nombre, activo
      INTO v_stock, v_precio, v_nombre, v_activo
      FROM productos
     WHERE id = NEW.producto_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El producto con id % no existe', NEW.producto_id;
    ELSIF NOT v_activo THEN
        RAISE EXCEPTION 'El producto "%" está inactivo y no se puede vender', v_nombre;
    ELSIF v_stock < NEW.cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente para "%": disponible %, solicitado %',
                        v_nombre, v_stock, NEW.cantidad;
    END IF;

    -- Precio histórico: el del producto en el momento de la venta
    NEW.precio_unitario := v_precio;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_detalle_venta_validar
    BEFORE INSERT ON detalle_venta
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_detalle_venta_validar();

-- ---------------------------------------------------------------------
-- trg_detalle_venta_stock (AFTER INSERT en detalle_venta)
-- Descuenta el stock y deja el movimiento SALIDA en el kardex.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_detalle_venta_stock()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE productos
       SET stock = stock - NEW.cantidad
     WHERE id = NEW.producto_id;

    INSERT INTO movimientos_inventario (producto_id, tipo, cantidad, usuario_id, venta_id)
    SELECT NEW.producto_id, 'SALIDA', NEW.cantidad, v.usuario_id, NEW.venta_id
      FROM ventas v
     WHERE v.id = NEW.venta_id;

    RETURN NULL;  -- en un trigger AFTER el valor de retorno se ignora
END;
$$;

CREATE TRIGGER trg_detalle_venta_stock
    AFTER INSERT ON detalle_venta
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_detalle_venta_stock();

-- ---------------------------------------------------------------------
-- sp_registrar_venta: transacción completa de una venta.
--   p_items: '[{"producto_id": 1, "cantidad": 2}, ...]'
--   p_venta_id (OUT): id de la venta creada.
-- WHILE recorre los ítems; cada INSERT dispara los triggers de detalle_venta.
-- Manejo de errores: COMMIT no puede ir dentro de un bloque con EXCEPTION,
-- así que el bloque interno solo guarda el mensaje del error y el externo
-- decide: COMMIT si todo salió bien, o ROLLBACK + RAISE si algo falló.
-- (En MySQL: START TRANSACTION + DECLARE ... HANDLER + SIGNAL.)
-- Requiere CALL en autocommit (la transacción empieza con el CALL).
-- Uso en la app: POST /api/ventas (pantalla "Nueva venta").
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_registrar_venta(
    IN  p_cliente_id  integer,
    IN  p_usuario_id  integer,
    IN  p_items       jsonb,
    OUT p_venta_id    integer
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_items  integer;
    v_i            integer := 0;
    v_item         jsonb;
    v_error        text;
BEGIN
    BEGIN
        IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array'
           OR jsonb_array_length(p_items) = 0 THEN
            RAISE EXCEPTION 'La venta debe tener al menos un producto';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM clientes WHERE id = p_cliente_id AND activo) THEN
            RAISE EXCEPTION 'El cliente no existe o está inactivo';
        END IF;

        INSERT INTO ventas (cliente_id, usuario_id)
        VALUES (p_cliente_id, p_usuario_id)
        RETURNING id INTO p_venta_id;

        v_total_items := jsonb_array_length(p_items);
        WHILE v_i < v_total_items LOOP
            v_item := p_items -> v_i;
            INSERT INTO detalle_venta (venta_id, producto_id, cantidad)
            VALUES (p_venta_id,
                    (v_item ->> 'producto_id')::integer,
                    (v_item ->> 'cantidad')::integer);
            v_i := v_i + 1;
        END LOOP;
    EXCEPTION
        WHEN unique_violation THEN
            v_error := 'Un producto aparece repetido en la venta';
        WHEN foreign_key_violation THEN
            v_error := 'El usuario o uno de los productos no existe';
        WHEN invalid_text_representation THEN
            v_error := 'Los ítems de la venta tienen un formato inválido';
        WHEN OTHERS THEN
            v_error := SQLERRM;  -- ej. 'Stock insuficiente ...' del trigger
    END;

    IF v_error IS NULL THEN
        COMMIT;
    ELSE
        ROLLBACK;
        p_venta_id := NULL;
        RAISE EXCEPTION '%', v_error;
    END IF;
END;
$$;

-- ---------------------------------------------------------------------
-- sp_anular_venta: devuelve el stock de cada ítem con un CURSOR, registra
-- el movimiento DEVOLUCION y marca la venta como ANULADA.
-- Uso en la app: botón "Anular" del detalle de venta (solo admin).
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_anular_venta(
    IN p_venta_id    integer,
    IN p_usuario_id  integer
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado  varchar;
    v_item    record;
    cur_detalle CURSOR FOR
        SELECT producto_id, cantidad
          FROM detalle_venta
         WHERE venta_id = p_venta_id;
BEGIN
    SELECT estado INTO v_estado
      FROM ventas
     WHERE id = p_venta_id
       FOR UPDATE;  -- evita que dos usuarios anulen la misma venta a la vez

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La venta % no existe', p_venta_id;
    ELSIF v_estado = 'ANULADA' THEN
        RAISE EXCEPTION 'La venta % ya está anulada', p_venta_id;
    END IF;

    OPEN cur_detalle;
    LOOP
        FETCH cur_detalle INTO v_item;
        EXIT WHEN NOT FOUND;

        UPDATE productos
           SET stock = stock + v_item.cantidad
         WHERE id = v_item.producto_id;

        INSERT INTO movimientos_inventario (producto_id, tipo, cantidad, usuario_id, venta_id)
        VALUES (v_item.producto_id, 'DEVOLUCION', v_item.cantidad, p_usuario_id, p_venta_id);
    END LOOP;
    CLOSE cur_detalle;

    UPDATE ventas SET estado = 'ANULADA' WHERE id = p_venta_id;
END;
$$;

-- ---------------------------------------------------------------------
-- sp_crear_producto: INSERT vía procedimiento con parámetro OUT.
-- Si trae stock inicial, lo registra en el kardex como ENTRADA.
-- Uso en la app: POST /api/productos.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_crear_producto(
    IN  p_codigo         varchar,
    IN  p_nombre         varchar,
    IN  p_categoria_id   integer,
    IN  p_proveedor_id   integer,
    IN  p_precio_compra  numeric,
    IN  p_precio_venta   numeric,
    IN  p_stock          integer,
    IN  p_stock_minimo   integer,
    IN  p_usuario_id     integer,
    OUT p_producto_id    integer
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_codigo varchar := upper(trim(p_codigo));
BEGIN
    IF EXISTS (SELECT 1 FROM productos WHERE codigo = v_codigo) THEN
        RAISE EXCEPTION 'Ya existe un producto con el código %', v_codigo;
    END IF;

    INSERT INTO productos (codigo, nombre, categoria_id, proveedor_id,
                           precio_compra, precio_venta, stock, stock_minimo)
    VALUES (v_codigo, trim(p_nombre), p_categoria_id, p_proveedor_id,
            p_precio_compra, p_precio_venta, COALESCE(p_stock, 0), COALESCE(p_stock_minimo, 5))
    RETURNING id INTO p_producto_id;

    IF COALESCE(p_stock, 0) > 0 THEN
        INSERT INTO movimientos_inventario (producto_id, tipo, cantidad, usuario_id)
        VALUES (p_producto_id, 'ENTRADA', p_stock, p_usuario_id);
    END IF;
END;
$$;

-- ---------------------------------------------------------------------
-- sp_actualizar_producto: UPDATE vía procedimiento.
-- No cambia el stock: el saldo solo se mueve con ventas, anulaciones y
-- entradas de mercancía, para que el kardex siempre cuadre.
-- Uso en la app: PUT /api/productos/{id}.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_actualizar_producto(
    IN p_producto_id    integer,
    IN p_codigo         varchar,
    IN p_nombre         varchar,
    IN p_categoria_id   integer,
    IN p_proveedor_id   integer,
    IN p_precio_compra  numeric,
    IN p_precio_venta   numeric,
    IN p_stock_minimo   integer,
    IN p_activo         boolean
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_codigo varchar := upper(trim(p_codigo));
BEGIN
    IF EXISTS (SELECT 1 FROM productos
                WHERE codigo = v_codigo AND id <> p_producto_id) THEN
        RAISE EXCEPTION 'Ya existe otro producto con el código %', v_codigo;
    END IF;

    UPDATE productos
       SET codigo        = v_codigo,
           nombre        = trim(p_nombre),
           categoria_id  = p_categoria_id,
           proveedor_id  = p_proveedor_id,
           precio_compra = p_precio_compra,
           precio_venta  = p_precio_venta,
           stock_minimo  = p_stock_minimo,
           activo        = p_activo
     WHERE id = p_producto_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El producto % no existe', p_producto_id;
    END IF;
END;
$$;


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
