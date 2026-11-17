--
-- PostgreSQL database dump
--

\restrict PsaEAwNmuwGUN0mm3NK6eE6sU16o6h6a6ai7UlS7DJnLqeje97fTLgxVgLnvv5w

-- Dumped from database version 17.12 (Debian 17.12-1.pgdg13+1)
-- Dumped by pg_dump version 17.12 (Debian 17.12-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: fn_clasificar_cliente(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_clasificar_cliente(p_cliente_id integer) RETURNS character varying
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_total numeric(14,2);
BEGIN
    SELECT COALESCE(SUM(fn_total_venta(v.id)), 0)
      INTO v_total
      FROM ventas v
     WHERE v.cliente_id = p_cliente_id
       AND v.estado = 'PAGADA';

    RETURN CASE
        WHEN v_total >= 1000000 THEN 'Premium'
        WHEN v_total >= 300000  THEN 'Frecuente'
        ELSE 'Básico'
    END;
END;
$$;


ALTER FUNCTION public.fn_clasificar_cliente(p_cliente_id integer) OWNER TO postgres;

--
-- Name: fn_estado_stock(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_estado_stock(p_stock integer, p_minimo integer) RETURNS character varying
    LANGUAGE plpgsql IMMUTABLE
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


ALTER FUNCTION public.fn_estado_stock(p_stock integer, p_minimo integer) OWNER TO postgres;

--
-- Name: fn_reporte_categorias_sobre_monto(numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_reporte_categorias_sobre_monto(p_monto numeric) RETURNS TABLE(categoria_id integer, categoria character varying, numero_ventas bigint, unidades bigint, total numeric)
    LANGUAGE sql STABLE
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


ALTER FUNCTION public.fn_reporte_categorias_sobre_monto(p_monto numeric) OWNER TO postgres;

--
-- Name: fn_reporte_clientes_sobre_promedio(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_reporte_clientes_sobre_promedio() RETURNS TABLE(cliente_id integer, cliente character varying, documento character varying, numero_compras bigint, total_comprado numeric, promedio_general numeric, clasificacion character varying)
    LANGUAGE sql STABLE
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


ALTER FUNCTION public.fn_reporte_clientes_sobre_promedio() OWNER TO postgres;

--
-- Name: fn_total_venta(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_total_venta(p_venta_id integer) RETURNS numeric
    LANGUAGE plpgsql STABLE
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


ALTER FUNCTION public.fn_total_venta(p_venta_id integer) OWNER TO postgres;

--
-- Name: fn_trg_auditoria(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_trg_auditoria() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_usuario  integer := NULLIF(current_setting('app.usuario_id', true), '')::integer;
    v_antes    jsonb;
    v_despues  jsonb;
BEGIN
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        v_antes := to_jsonb(OLD) - 'password_hash';
    END IF;
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        v_despues := to_jsonb(NEW) - 'password_hash';
    END IF;

    IF TG_OP = 'UPDATE' AND (v_antes - 'stock') = (v_despues - 'stock') THEN
        RETURN NULL;
    END IF;

    CASE TG_OP
        WHEN 'INSERT' THEN
            INSERT INTO auditoria (tabla, operacion, registro_id, usuario_id, datos_despues)
            VALUES (TG_TABLE_NAME, TG_OP, NEW.id, v_usuario, v_despues);
        WHEN 'UPDATE' THEN
            INSERT INTO auditoria (tabla, operacion, registro_id, usuario_id, datos_antes, datos_despues)
            VALUES (TG_TABLE_NAME, TG_OP, NEW.id, v_usuario, v_antes, v_despues);
        WHEN 'DELETE' THEN
            INSERT INTO auditoria (tabla, operacion, registro_id, usuario_id, datos_antes)
            VALUES (TG_TABLE_NAME, TG_OP, OLD.id, v_usuario, v_antes);
    END CASE;

    RETURN NULL;  -- trigger AFTER: el valor de retorno se ignora
END;
$$;


ALTER FUNCTION public.fn_trg_auditoria() OWNER TO postgres;

--
-- Name: fn_trg_detalle_venta_stock(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_trg_detalle_venta_stock() RETURNS trigger
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


ALTER FUNCTION public.fn_trg_detalle_venta_stock() OWNER TO postgres;

--
-- Name: fn_trg_detalle_venta_validar(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_trg_detalle_venta_validar() RETURNS trigger
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


ALTER FUNCTION public.fn_trg_detalle_venta_validar() OWNER TO postgres;

--
-- Name: fn_trg_productos_validar_precio(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_trg_productos_validar_precio() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.precio_venta < NEW.precio_compra THEN
        RAISE EXCEPTION 'El precio de venta (%) no puede ser menor que el precio de compra (%)',
                        NEW.precio_venta, NEW.precio_compra;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_trg_productos_validar_precio() OWNER TO postgres;

--
-- Name: sp_actualizar_producto(integer, character varying, character varying, integer, integer, numeric, numeric, integer, boolean); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_actualizar_producto(IN p_producto_id integer, IN p_codigo character varying, IN p_nombre character varying, IN p_categoria_id integer, IN p_proveedor_id integer, IN p_precio_compra numeric, IN p_precio_venta numeric, IN p_stock_minimo integer, IN p_activo boolean)
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


ALTER PROCEDURE public.sp_actualizar_producto(IN p_producto_id integer, IN p_codigo character varying, IN p_nombre character varying, IN p_categoria_id integer, IN p_proveedor_id integer, IN p_precio_compra numeric, IN p_precio_venta numeric, IN p_stock_minimo integer, IN p_activo boolean) OWNER TO postgres;

--
-- Name: sp_anular_venta(integer, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_anular_venta(IN p_venta_id integer, IN p_usuario_id integer)
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


ALTER PROCEDURE public.sp_anular_venta(IN p_venta_id integer, IN p_usuario_id integer) OWNER TO postgres;

--
-- Name: sp_crear_producto(character varying, character varying, integer, integer, numeric, numeric, integer, integer, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_crear_producto(IN p_codigo character varying, IN p_nombre character varying, IN p_categoria_id integer, IN p_proveedor_id integer, IN p_precio_compra numeric, IN p_precio_venta numeric, IN p_stock integer, IN p_stock_minimo integer, IN p_usuario_id integer, OUT p_producto_id integer)
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


ALTER PROCEDURE public.sp_crear_producto(IN p_codigo character varying, IN p_nombre character varying, IN p_categoria_id integer, IN p_proveedor_id integer, IN p_precio_compra numeric, IN p_precio_venta numeric, IN p_stock integer, IN p_stock_minimo integer, IN p_usuario_id integer, OUT p_producto_id integer) OWNER TO postgres;

--
-- Name: sp_eliminar_cliente(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_eliminar_cliente(IN p_cliente_id integer, OUT p_resultado character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM clientes WHERE id = p_cliente_id) THEN
        RAISE EXCEPTION 'El cliente % no existe', p_cliente_id;
    END IF;

    IF EXISTS (SELECT 1 FROM ventas WHERE cliente_id = p_cliente_id) THEN
        UPDATE clientes SET activo = false WHERE id = p_cliente_id;
        p_resultado := 'DESACTIVADO';
    ELSE
        DELETE FROM clientes WHERE id = p_cliente_id;
        p_resultado := 'ELIMINADO';
    END IF;
END;
$$;


ALTER PROCEDURE public.sp_eliminar_cliente(IN p_cliente_id integer, OUT p_resultado character varying) OWNER TO postgres;

--
-- Name: sp_registrar_entrada(integer, integer, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_registrar_entrada(IN p_producto_id integer, IN p_cantidad integer, IN p_usuario_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad de la entrada debe ser mayor que cero';
    END IF;

    UPDATE productos
       SET stock = stock + p_cantidad
     WHERE id = p_producto_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El producto % no existe', p_producto_id;
    END IF;

    INSERT INTO movimientos_inventario (producto_id, tipo, cantidad, usuario_id)
    VALUES (p_producto_id, 'ENTRADA', p_cantidad, p_usuario_id);
END;
$$;


ALTER PROCEDURE public.sp_registrar_entrada(IN p_producto_id integer, IN p_cantidad integer, IN p_usuario_id integer) OWNER TO postgres;

--
-- Name: sp_registrar_venta(integer, integer, jsonb); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_registrar_venta(IN p_cliente_id integer, IN p_usuario_id integer, IN p_items jsonb, OUT p_venta_id integer)
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


ALTER PROCEDURE public.sp_registrar_venta(IN p_cliente_id integer, IN p_usuario_id integer, IN p_items jsonb, OUT p_venta_id integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: auditoria; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.auditoria (
    id bigint NOT NULL,
    tabla character varying(50) NOT NULL,
    operacion character varying(10) NOT NULL,
    registro_id integer,
    usuario_id integer,
    datos_antes jsonb,
    datos_despues jsonb,
    fecha timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT auditoria_operacion_check CHECK (((operacion)::text = ANY ((ARRAY['INSERT'::character varying, 'UPDATE'::character varying, 'DELETE'::character varying])::text[])))
);


ALTER TABLE public.auditoria OWNER TO postgres;

--
-- Name: auditoria_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.auditoria ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.auditoria_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: categorias; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.categorias (
    id integer NOT NULL,
    nombre character varying(60) NOT NULL,
    descripcion text
);


ALTER TABLE public.categorias OWNER TO postgres;

--
-- Name: categorias_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.categorias ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.categorias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: clientes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.clientes (
    id integer NOT NULL,
    documento character varying(20) NOT NULL,
    nombre character varying(120) NOT NULL,
    telefono character varying(20),
    email character varying(120),
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_clientes_email CHECK (((email IS NULL) OR ((email)::text ~~ '_%@_%._%'::text)))
);


ALTER TABLE public.clientes OWNER TO postgres;

--
-- Name: clientes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.clientes ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.clientes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: detalle_venta; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.detalle_venta (
    id integer NOT NULL,
    venta_id integer NOT NULL,
    producto_id integer NOT NULL,
    cantidad integer NOT NULL,
    precio_unitario numeric(12,2) NOT NULL,
    CONSTRAINT detalle_venta_cantidad_check CHECK ((cantidad > 0)),
    CONSTRAINT detalle_venta_precio_unitario_check CHECK ((precio_unitario > (0)::numeric))
);


ALTER TABLE public.detalle_venta OWNER TO postgres;

--
-- Name: detalle_venta_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.detalle_venta ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.detalle_venta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: movimientos_inventario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.movimientos_inventario (
    id integer NOT NULL,
    producto_id integer NOT NULL,
    tipo character varying(12) NOT NULL,
    cantidad integer NOT NULL,
    usuario_id integer NOT NULL,
    venta_id integer,
    fecha timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_movimientos_venta CHECK ((((tipo)::text = 'ENTRADA'::text) OR (venta_id IS NOT NULL))),
    CONSTRAINT movimientos_inventario_cantidad_check CHECK ((cantidad > 0)),
    CONSTRAINT movimientos_inventario_tipo_check CHECK (((tipo)::text = ANY ((ARRAY['ENTRADA'::character varying, 'SALIDA'::character varying, 'DEVOLUCION'::character varying])::text[])))
);


ALTER TABLE public.movimientos_inventario OWNER TO postgres;

--
-- Name: movimientos_inventario_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.movimientos_inventario ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.movimientos_inventario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: productos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.productos (
    id integer NOT NULL,
    codigo character varying(20) NOT NULL,
    nombre character varying(120) NOT NULL,
    categoria_id integer NOT NULL,
    proveedor_id integer NOT NULL,
    precio_compra numeric(12,2) NOT NULL,
    precio_venta numeric(12,2) NOT NULL,
    stock integer DEFAULT 0 NOT NULL,
    stock_minimo integer DEFAULT 5 NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT productos_precio_compra_check CHECK ((precio_compra >= (0)::numeric)),
    CONSTRAINT productos_precio_venta_check CHECK ((precio_venta > (0)::numeric)),
    CONSTRAINT productos_stock_check CHECK ((stock >= 0)),
    CONSTRAINT productos_stock_minimo_check CHECK ((stock_minimo >= 0))
);


ALTER TABLE public.productos OWNER TO postgres;

--
-- Name: productos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.productos ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.productos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: proveedores; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.proveedores (
    id integer NOT NULL,
    nit character varying(20) NOT NULL,
    nombre character varying(120) NOT NULL,
    telefono character varying(20),
    email character varying(120),
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_proveedores_email CHECK (((email IS NULL) OR ((email)::text ~~ '_%@_%._%'::text)))
);


ALTER TABLE public.proveedores OWNER TO postgres;

--
-- Name: proveedores_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.proveedores ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.proveedores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: roles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.roles (
    id integer NOT NULL,
    nombre character varying(30) NOT NULL
);


ALTER TABLE public.roles OWNER TO postgres;

--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.roles ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: usuarios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuarios (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    email character varying(120) NOT NULL,
    password_hash character varying(100) NOT NULL,
    rol_id integer NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_usuarios_email CHECK (((email)::text ~~ '_%@_%._%'::text))
);


ALTER TABLE public.usuarios OWNER TO postgres;

--
-- Name: usuarios_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.usuarios ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.usuarios_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: ventas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ventas (
    id integer NOT NULL,
    cliente_id integer NOT NULL,
    usuario_id integer NOT NULL,
    fecha timestamp with time zone DEFAULT now() NOT NULL,
    estado character varying(10) DEFAULT 'PAGADA'::character varying NOT NULL,
    CONSTRAINT ventas_estado_check CHECK (((estado)::text = ANY ((ARRAY['PAGADA'::character varying, 'ANULADA'::character varying])::text[])))
);


ALTER TABLE public.ventas OWNER TO postgres;

--
-- Name: ventas_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.ventas ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.ventas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: vw_stock_bajo; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_stock_bajo AS
 SELECT p.id AS producto_id,
    p.codigo,
    p.nombre AS producto,
    cat.nombre AS categoria,
    pr.nombre AS proveedor,
    p.stock,
    p.stock_minimo,
    public.fn_estado_stock(p.stock, p.stock_minimo) AS estado,
    ((p.stock_minimo * 2) - p.stock) AS sugerido_pedir
   FROM ((public.productos p
     JOIN public.categorias cat ON ((cat.id = p.categoria_id)))
     JOIN public.proveedores pr ON ((pr.id = p.proveedor_id)))
  WHERE (p.activo AND ((public.fn_estado_stock(p.stock, p.stock_minimo))::text <> 'OK'::text));


ALTER VIEW public.vw_stock_bajo OWNER TO postgres;

--
-- Name: vw_top_productos; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_top_productos AS
 SELECT rank() OVER (ORDER BY (sum(d.cantidad)) DESC) AS puesto,
    p.id AS producto_id,
    p.codigo,
    p.nombre AS producto,
    cat.nombre AS categoria,
    sum(d.cantidad) AS unidades_vendidas,
    sum(((d.cantidad)::numeric * d.precio_unitario)) AS total_vendido
   FROM (((public.detalle_venta d
     JOIN public.ventas v ON ((v.id = d.venta_id)))
     JOIN public.productos p ON ((p.id = d.producto_id)))
     JOIN public.categorias cat ON ((cat.id = p.categoria_id)))
  WHERE ((v.estado)::text = 'PAGADA'::text)
  GROUP BY p.id, p.codigo, p.nombre, cat.nombre;


ALTER VIEW public.vw_top_productos OWNER TO postgres;

--
-- Name: vw_ventas_detalle; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_ventas_detalle AS
 SELECT v.id AS venta_id,
    v.fecha,
    v.estado,
    v.cliente_id,
    c.nombre AS cliente,
    c.documento AS cliente_documento,
    v.usuario_id,
    u.nombre AS vendedor,
    d.producto_id,
    p.codigo,
    p.nombre AS producto,
    p.categoria_id,
    cat.nombre AS categoria,
    d.cantidad,
    d.precio_unitario,
    ((d.cantidad)::numeric * d.precio_unitario) AS subtotal
   FROM (((((public.ventas v
     JOIN public.clientes c ON ((c.id = v.cliente_id)))
     JOIN public.usuarios u ON ((u.id = v.usuario_id)))
     JOIN public.detalle_venta d ON ((d.venta_id = v.id)))
     JOIN public.productos p ON ((p.id = d.producto_id)))
     JOIN public.categorias cat ON ((cat.id = p.categoria_id)));


ALTER VIEW public.vw_ventas_detalle OWNER TO postgres;

--
-- Name: vw_ventas_categoria_mes; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_ventas_categoria_mes AS
 SELECT (date_trunc('month'::text, fecha))::date AS mes,
    categoria_id,
    categoria,
    sum(cantidad) AS unidades,
    sum(subtotal) AS total
   FROM public.vw_ventas_detalle
  WHERE ((estado)::text = 'PAGADA'::text)
  GROUP BY ((date_trunc('month'::text, fecha))::date), categoria_id, categoria;


ALTER VIEW public.vw_ventas_categoria_mes OWNER TO postgres;

--
-- Data for Name: auditoria; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.auditoria (id, tabla, operacion, registro_id, usuario_id, datos_antes, datos_despues, fecha) FROM stdin;
1	usuarios	INSERT	1	\N	\N	{"id": 1, "email": "admin@ferreteria.com", "activo": true, "nombre": "Administrador del sistema", "rol_id": 1}	2026-11-17 12:39:58.456838-05
2	usuarios	INSERT	2	\N	\N	{"id": 2, "email": "vendedor@ferreteria.com", "activo": true, "nombre": "Vendedor de mostrador", "rol_id": 2}	2026-11-17 12:39:58.456838-05
3	productos	INSERT	1	\N	\N	{"id": 1, "stock": 40, "activo": true, "codigo": "HM-001", "nombre": "Martillo de uña 16 oz", "categoria_id": 1, "precio_venta": 26000.00, "proveedor_id": 2, "stock_minimo": 5, "precio_compra": 18000.00}	2026-11-17 12:39:58.471218-05
4	productos	INSERT	2	\N	\N	{"id": 2, "stock": 60, "activo": true, "codigo": "HM-002", "nombre": "Destornillador de pala 1/4\\"", "categoria_id": 1, "precio_venta": 8500.00, "proveedor_id": 2, "stock_minimo": 10, "precio_compra": 5500.00}	2026-11-17 12:39:58.471218-05
5	productos	INSERT	3	\N	\N	{"id": 3, "stock": 35, "activo": true, "codigo": "HM-003", "nombre": "Alicate universal 8\\"", "categoria_id": 1, "precio_venta": 24000.00, "proveedor_id": 2, "stock_minimo": 5, "precio_compra": 16000.00}	2026-11-17 12:39:58.471218-05
6	productos	INSERT	4	\N	\N	{"id": 4, "stock": 50, "activo": true, "codigo": "HM-004", "nombre": "Flexómetro 5 m", "categoria_id": 1, "precio_venta": 14000.00, "proveedor_id": 1, "stock_minimo": 8, "precio_compra": 9000.00}	2026-11-17 12:39:58.471218-05
7	productos	INSERT	5	\N	\N	{"id": 5, "stock": 12, "activo": true, "codigo": "HE-001", "nombre": "Taladro percutor 1/2\\" 650 W", "categoria_id": 2, "precio_venta": 229000.00, "proveedor_id": 2, "stock_minimo": 3, "precio_compra": 165000.00}	2026-11-17 12:39:58.471218-05
8	productos	INSERT	6	\N	\N	{"id": 6, "stock": 3, "activo": true, "codigo": "HE-002", "nombre": "Pulidora angular 4-1/2\\" 850 W", "categoria_id": 2, "precio_venta": 210000.00, "proveedor_id": 2, "stock_minimo": 4, "precio_compra": 150000.00}	2026-11-17 12:39:58.471218-05
9	productos	INSERT	7	\N	\N	{"id": 7, "stock": 6, "activo": true, "codigo": "HE-003", "nombre": "Sierra circular 7-1/4\\" 1400 W", "categoria_id": 2, "precio_venta": 389000.00, "proveedor_id": 2, "stock_minimo": 2, "precio_compra": 280000.00}	2026-11-17 12:39:58.471218-05
10	productos	INSERT	8	\N	\N	{"id": 8, "stock": 120, "activo": true, "codigo": "TF-001", "nombre": "Tornillo drywall 6x1\\" (caja x100)", "categoria_id": 3, "precio_venta": 10000.00, "proveedor_id": 1, "stock_minimo": 20, "precio_compra": 6500.00}	2026-11-17 12:39:58.471218-05
11	productos	INSERT	9	\N	\N	{"id": 9, "stock": 90, "activo": true, "codigo": "TF-002", "nombre": "Chazo plástico 1/4\\" (bolsa x100)", "categoria_id": 3, "precio_venta": 6500.00, "proveedor_id": 1, "stock_minimo": 15, "precio_compra": 4000.00}	2026-11-17 12:39:58.471218-05
12	productos	INSERT	10	\N	\N	{"id": 10, "stock": 150, "activo": true, "codigo": "TF-003", "nombre": "Puntilla con cabeza 2\\" (libra)", "categoria_id": 3, "precio_venta": 5500.00, "proveedor_id": 1, "stock_minimo": 20, "precio_compra": 3500.00}	2026-11-17 12:39:58.471218-05
13	productos	INSERT	11	\N	\N	{"id": 11, "stock": 500, "activo": true, "codigo": "EL-001", "nombre": "Cable THHN calibre 12 (metro)", "categoria_id": 4, "precio_venta": 3500.00, "proveedor_id": 3, "stock_minimo": 100, "precio_compra": 2200.00}	2026-11-17 12:39:58.471218-05
14	productos	INSERT	12	\N	\N	{"id": 12, "stock": 80, "activo": true, "codigo": "EL-002", "nombre": "Toma doble con polo a tierra", "categoria_id": 4, "precio_venta": 9000.00, "proveedor_id": 3, "stock_minimo": 10, "precio_compra": 5500.00}	2026-11-17 12:39:58.471218-05
15	productos	INSERT	13	\N	\N	{"id": 13, "stock": 100, "activo": true, "codigo": "EL-003", "nombre": "Bombillo LED 12 W", "categoria_id": 4, "precio_venta": 7500.00, "proveedor_id": 3, "stock_minimo": 15, "precio_compra": 4500.00}	2026-11-17 12:39:58.471218-05
16	productos	INSERT	14	\N	\N	{"id": 14, "stock": 0, "activo": true, "codigo": "EL-004", "nombre": "Breaker monopolar 20 A", "categoria_id": 4, "precio_venta": 21000.00, "proveedor_id": 3, "stock_minimo": 5, "precio_compra": 14000.00}	2026-11-17 12:39:58.471218-05
17	productos	INSERT	15	\N	\N	{"id": 15, "stock": 70, "activo": true, "codigo": "PL-001", "nombre": "Tubo PVC presión 1/2\\" x 6 m", "categoria_id": 5, "precio_venta": 16500.00, "proveedor_id": 1, "stock_minimo": 10, "precio_compra": 11000.00}	2026-11-17 12:39:58.471218-05
18	productos	INSERT	16	\N	\N	{"id": 16, "stock": 4, "activo": true, "codigo": "PL-002", "nombre": "Llave de paso 1/2\\"", "categoria_id": 5, "precio_venta": 19500.00, "proveedor_id": 1, "stock_minimo": 6, "precio_compra": 13000.00}	2026-11-17 12:39:58.471218-05
19	productos	INSERT	17	\N	\N	{"id": 17, "stock": 200, "activo": true, "codigo": "PL-003", "nombre": "Cinta teflón 1/2\\" x 10 m", "categoria_id": 5, "precio_venta": 2500.00, "proveedor_id": 1, "stock_minimo": 30, "precio_compra": 1200.00}	2026-11-17 12:39:58.471218-05
20	productos	INSERT	18	\N	\N	{"id": 18, "stock": 45, "activo": true, "codigo": "PI-001", "nombre": "Pintura vinilo blanco tipo 1 (galón)", "categoria_id": 6, "precio_venta": 59000.00, "proveedor_id": 4, "stock_minimo": 8, "precio_compra": 42000.00}	2026-11-17 12:39:58.471218-05
21	productos	INSERT	19	\N	\N	{"id": 19, "stock": 60, "activo": true, "codigo": "PI-002", "nombre": "Brocha 3\\"", "categoria_id": 6, "precio_venta": 7500.00, "proveedor_id": 4, "stock_minimo": 10, "precio_compra": 4500.00}	2026-11-17 12:39:58.471218-05
22	productos	INSERT	20	\N	\N	{"id": 20, "stock": 200, "activo": true, "codigo": "CO-001", "nombre": "Cemento gris uso general 50 kg", "categoria_id": 7, "precio_venta": 36500.00, "proveedor_id": 5, "stock_minimo": 30, "precio_compra": 29000.00}	2026-11-17 12:39:58.471218-05
23	productos	INSERT	21	\N	\N	{"id": 21, "stock": 150, "activo": true, "codigo": "CO-002", "nombre": "Arena de río (bulto 40 kg)", "categoria_id": 7, "precio_venta": 9500.00, "proveedor_id": 5, "stock_minimo": 20, "precio_compra": 6000.00}	2026-11-17 12:39:58.471218-05
24	productos	INSERT	22	\N	\N	{"id": 22, "stock": 20, "activo": true, "codigo": "JA-001", "nombre": "Manguera de jardín 1/2\\" x 15 m", "categoria_id": 8, "precio_venta": 42000.00, "proveedor_id": 1, "stock_minimo": 4, "precio_compra": 28000.00}	2026-11-17 12:39:58.471218-05
25	clientes	INSERT	1	\N	\N	{"id": 1, "email": null, "activo": true, "nombre": "Consumidor final", "telefono": null, "documento": "222222222222"}	2026-11-17 12:39:58.483389-05
26	clientes	INSERT	2	\N	\N	{"id": 2, "email": "carlos.perez@gmail.com", "activo": true, "nombre": "Carlos Andrés Pérez Rojas", "telefono": "3104567890", "documento": "1052345678"}	2026-11-17 12:39:58.483389-05
27	clientes	INSERT	3	\N	\N	{"id": 3, "email": "luzmarina.gomez@hotmail.com", "activo": true, "nombre": "Luz Marina Gómez Vargas", "telefono": "3115678901", "documento": "1053456789"}	2026-11-17 12:39:58.483389-05
28	clientes	INSERT	4	\N	\N	{"id": 4, "email": null, "activo": true, "nombre": "Jorge Eliécer Suárez Mora", "telefono": "3126789012", "documento": "1054567890"}	2026-11-17 12:39:58.483389-05
29	clientes	INSERT	5	\N	\N	{"id": 5, "email": "diana.rodriguez@gmail.com", "activo": true, "nombre": "Diana Carolina Rodríguez Niño", "telefono": "3137890123", "documento": "1055678901"}	2026-11-17 12:39:58.483389-05
30	clientes	INSERT	6	\N	\N	{"id": 6, "email": "afcastro@outlook.com", "activo": true, "nombre": "Andrés Felipe Castro León", "telefono": "3148901234", "documento": "1056789012"}	2026-11-17 12:39:58.483389-05
31	clientes	INSERT	7	\N	\N	{"id": 7, "email": "mafe.lopez@gmail.com", "activo": true, "nombre": "María Fernanda López Díaz", "telefono": "3159012345", "documento": "1057890123"}	2026-11-17 12:39:58.483389-05
32	clientes	INSERT	8	\N	\N	{"id": 8, "email": null, "activo": true, "nombre": "Óscar Iván Torres Cely", "telefono": "3160123456", "documento": "1058901234"}	2026-11-17 12:39:58.483389-05
33	clientes	INSERT	9	\N	\N	{"id": 9, "email": "compras@loscerezos.com.co", "activo": true, "nombre": "Constructora Los Cerezos S.A.S.", "telefono": "6087712345", "documento": "901234567-8"}	2026-11-17 12:39:58.483389-05
34	clientes	INSERT	10	\N	\N	{"id": 10, "email": "almacen@mantsugamuxi.com", "activo": true, "nombre": "Mantenimientos Industriales del Sugamuxi S.A.S.", "telefono": "6087723456", "documento": "901345678-9"}	2026-11-17 12:39:58.483389-05
\.


--
-- Data for Name: categorias; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.categorias (id, nombre, descripcion) FROM stdin;
1	Herramientas manuales	Martillos, destornilladores, alicates y medición
2	Herramientas eléctricas	Taladros, pulidoras y sierras
3	Tornillería y fijaciones	Tornillos, chazos y puntillas
4	Electricidad	Cables, tomas, iluminación y protecciones
5	Plomería	Tubería, llaves y accesorios
6	Pinturas	Pinturas, brochas y rodillos
7	Construcción	Cemento, arena y agregados
8	Jardinería	Mangueras y herramientas de jardín
\.


--
-- Data for Name: clientes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.clientes (id, documento, nombre, telefono, email, activo) FROM stdin;
1	222222222222	Consumidor final	\N	\N	t
2	1052345678	Carlos Andrés Pérez Rojas	3104567890	carlos.perez@gmail.com	t
3	1053456789	Luz Marina Gómez Vargas	3115678901	luzmarina.gomez@hotmail.com	t
4	1054567890	Jorge Eliécer Suárez Mora	3126789012	\N	t
5	1055678901	Diana Carolina Rodríguez Niño	3137890123	diana.rodriguez@gmail.com	t
6	1056789012	Andrés Felipe Castro León	3148901234	afcastro@outlook.com	t
7	1057890123	María Fernanda López Díaz	3159012345	mafe.lopez@gmail.com	t
8	1058901234	Óscar Iván Torres Cely	3160123456	\N	t
9	901234567-8	Constructora Los Cerezos S.A.S.	6087712345	compras@loscerezos.com.co	t
10	901345678-9	Mantenimientos Industriales del Sugamuxi S.A.S.	6087723456	almacen@mantsugamuxi.com	t
\.


--
-- Data for Name: detalle_venta; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.detalle_venta (id, venta_id, producto_id, cantidad, precio_unitario) FROM stdin;
1	1	20	40	36500.00
2	1	21	30	9500.00
3	1	10	10	5500.00
4	2	2	2	8500.00
5	2	17	3	2500.00
6	3	1	1	26000.00
7	3	4	1	14000.00
8	3	8	2	10000.00
9	4	5	2	229000.00
10	4	3	3	24000.00
11	5	12	2	9000.00
12	5	13	6	7500.00
13	6	18	3	59000.00
14	6	19	2	7500.00
15	7	15	6	16500.00
16	7	17	4	2500.00
17	8	20	30	36500.00
18	8	8	10	10000.00
19	9	9	2	6500.00
20	9	10	3	5500.00
21	10	11	40	3500.00
22	10	12	4	9000.00
23	11	5	1	229000.00
24	11	9	2	6500.00
25	12	22	1	42000.00
26	12	17	2	2500.00
27	13	7	1	389000.00
28	13	2	6	8500.00
29	14	13	4	7500.00
30	14	17	2	2500.00
31	15	4	1	14000.00
32	15	18	2	59000.00
33	15	19	3	7500.00
34	16	18	4	59000.00
35	16	19	4	7500.00
36	17	20	25	36500.00
37	17	21	40	9500.00
38	17	11	60	3500.00
39	18	1	1	26000.00
40	18	10	2	5500.00
41	19	8	3	10000.00
42	19	9	1	6500.00
43	20	11	30	3500.00
44	20	13	5	7500.00
45	21	12	6	9000.00
46	21	5	1	229000.00
47	21	3	2	24000.00
48	22	15	2	16500.00
49	22	17	1	2500.00
50	23	1	1	26000.00
51	23	22	1	42000.00
52	24	20	4	36500.00
53	24	18	2	59000.00
54	25	20	35	36500.00
55	25	21	20	9500.00
56	25	8	15	10000.00
57	26	12	1	9000.00
58	26	13	3	7500.00
59	27	2	2	8500.00
60	27	3	1	24000.00
61	28	11	50	3500.00
62	28	7	1	389000.00
63	29	15	3	16500.00
64	29	17	2	2500.00
65	30	4	1	14000.00
66	30	9	1	6500.00
67	31	20	2	36500.00
68	31	21	5	9500.00
\.


--
-- Data for Name: movimientos_inventario; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.movimientos_inventario (id, producto_id, tipo, cantidad, usuario_id, venta_id, fecha) FROM stdin;
1	1	ENTRADA	40	1	\N	2026-08-09 12:39:58.478784-05
2	2	ENTRADA	60	1	\N	2026-08-09 12:39:58.478784-05
3	3	ENTRADA	35	1	\N	2026-08-09 12:39:58.478784-05
4	4	ENTRADA	50	1	\N	2026-08-09 12:39:58.478784-05
5	5	ENTRADA	12	1	\N	2026-08-09 12:39:58.478784-05
6	6	ENTRADA	3	1	\N	2026-08-09 12:39:58.478784-05
7	7	ENTRADA	6	1	\N	2026-08-09 12:39:58.478784-05
8	8	ENTRADA	120	1	\N	2026-08-09 12:39:58.478784-05
9	9	ENTRADA	90	1	\N	2026-08-09 12:39:58.478784-05
10	10	ENTRADA	150	1	\N	2026-08-09 12:39:58.478784-05
11	11	ENTRADA	500	1	\N	2026-08-09 12:39:58.478784-05
12	12	ENTRADA	80	1	\N	2026-08-09 12:39:58.478784-05
13	13	ENTRADA	100	1	\N	2026-08-09 12:39:58.478784-05
14	15	ENTRADA	70	1	\N	2026-08-09 12:39:58.478784-05
15	16	ENTRADA	4	1	\N	2026-08-09 12:39:58.478784-05
16	17	ENTRADA	200	1	\N	2026-08-09 12:39:58.478784-05
17	18	ENTRADA	45	1	\N	2026-08-09 12:39:58.478784-05
18	19	ENTRADA	60	1	\N	2026-08-09 12:39:58.478784-05
19	20	ENTRADA	200	1	\N	2026-08-09 12:39:58.478784-05
20	21	ENTRADA	150	1	\N	2026-08-09 12:39:58.478784-05
21	22	ENTRADA	20	1	\N	2026-08-09 12:39:58.478784-05
22	20	SALIDA	40	1	1	2026-08-24 08:17:00-05
23	21	SALIDA	30	1	1	2026-08-24 08:17:00-05
24	10	SALIDA	10	1	1	2026-08-24 08:17:00-05
25	2	SALIDA	2	2	2	2026-08-26 09:17:00-05
26	17	SALIDA	3	2	2	2026-08-26 09:17:00-05
27	1	SALIDA	1	2	3	2026-08-29 10:17:00-05
28	4	SALIDA	1	2	3	2026-08-29 10:17:00-05
29	8	SALIDA	2	2	3	2026-08-29 10:17:00-05
30	5	SALIDA	2	1	4	2026-08-31 11:17:00-05
31	3	SALIDA	3	1	4	2026-08-31 11:17:00-05
32	12	SALIDA	2	2	5	2026-09-03 12:17:00-05
33	13	SALIDA	6	2	5	2026-09-03 12:17:00-05
34	18	SALIDA	3	2	6	2026-09-06 13:17:00-05
35	19	SALIDA	2	2	6	2026-09-06 13:17:00-05
36	15	SALIDA	6	2	7	2026-09-08 14:17:00-05
37	17	SALIDA	4	2	7	2026-09-08 14:17:00-05
38	20	SALIDA	30	2	8	2026-09-11 15:17:00-05
39	8	SALIDA	10	2	8	2026-09-11 15:17:00-05
40	9	SALIDA	2	2	9	2026-09-14 16:17:00-05
41	10	SALIDA	3	2	9	2026-09-14 16:17:00-05
42	11	SALIDA	40	2	10	2026-09-16 08:17:00-05
43	12	SALIDA	4	2	10	2026-09-16 08:17:00-05
44	5	SALIDA	1	2	11	2026-09-19 09:17:00-05
45	9	SALIDA	2	2	11	2026-09-19 09:17:00-05
46	22	SALIDA	1	2	12	2026-09-22 10:17:00-05
47	17	SALIDA	2	2	12	2026-09-22 10:17:00-05
48	7	SALIDA	1	1	13	2026-09-24 11:17:00-05
49	2	SALIDA	6	1	13	2026-09-24 11:17:00-05
50	13	SALIDA	4	2	14	2026-09-27 12:17:00-05
51	17	SALIDA	2	2	14	2026-09-27 12:17:00-05
52	4	SALIDA	1	2	15	2026-09-30 13:17:00-05
53	18	SALIDA	2	2	15	2026-09-30 13:17:00-05
54	19	SALIDA	3	2	15	2026-09-30 13:17:00-05
55	18	SALIDA	4	2	16	2026-10-02 14:17:00-05
56	19	SALIDA	4	2	16	2026-10-02 14:17:00-05
57	20	SALIDA	25	1	17	2026-10-05 15:17:00-05
58	21	SALIDA	40	1	17	2026-10-05 15:17:00-05
59	11	SALIDA	60	1	17	2026-10-05 15:17:00-05
60	1	SALIDA	1	2	18	2026-10-08 16:17:00-05
61	10	SALIDA	2	2	18	2026-10-08 16:17:00-05
62	1	DEVOLUCION	1	1	18	2026-10-08 18:17:00-05
63	10	DEVOLUCION	2	1	18	2026-10-08 18:17:00-05
64	8	SALIDA	3	2	19	2026-10-11 08:17:00-05
65	9	SALIDA	1	2	19	2026-10-11 08:17:00-05
66	11	SALIDA	30	2	20	2026-10-13 09:17:00-05
67	13	SALIDA	5	2	20	2026-10-13 09:17:00-05
68	12	SALIDA	6	2	21	2026-10-16 10:17:00-05
69	5	SALIDA	1	2	21	2026-10-16 10:17:00-05
70	3	SALIDA	2	2	21	2026-10-16 10:17:00-05
71	15	SALIDA	2	2	22	2026-10-19 11:17:00-05
72	17	SALIDA	1	2	22	2026-10-19 11:17:00-05
73	1	SALIDA	1	2	23	2026-10-22 12:17:00-05
74	22	SALIDA	1	2	23	2026-10-22 12:17:00-05
75	20	SALIDA	4	2	24	2026-10-25 13:17:00-05
76	18	SALIDA	2	2	24	2026-10-25 13:17:00-05
77	20	SALIDA	35	2	25	2026-10-28 14:17:00-05
78	21	SALIDA	20	2	25	2026-10-28 14:17:00-05
79	8	SALIDA	15	2	25	2026-10-28 14:17:00-05
80	12	SALIDA	1	2	26	2026-11-01 15:17:00-05
81	13	SALIDA	3	2	26	2026-11-01 15:17:00-05
82	2	SALIDA	2	2	27	2026-11-04 16:17:00-05
83	3	SALIDA	1	2	27	2026-11-04 16:17:00-05
84	11	SALIDA	50	1	28	2026-11-08 08:17:00-05
85	7	SALIDA	1	1	28	2026-11-08 08:17:00-05
86	15	SALIDA	3	2	29	2026-11-11 09:17:00-05
87	17	SALIDA	2	2	29	2026-11-11 09:17:00-05
88	4	SALIDA	1	2	30	2026-11-14 10:17:00-05
89	9	SALIDA	1	2	30	2026-11-14 10:17:00-05
90	20	SALIDA	2	2	31	2026-11-16 11:17:00-05
91	21	SALIDA	5	2	31	2026-11-16 11:17:00-05
\.


--
-- Data for Name: productos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.productos (id, codigo, nombre, categoria_id, proveedor_id, precio_compra, precio_venta, stock, stock_minimo, activo) FROM stdin;
6	HE-002	Pulidora angular 4-1/2" 850 W	2	2	150000.00	210000.00	3	4	t
14	EL-004	Breaker monopolar 20 A	4	3	14000.00	21000.00	0	5	t
16	PL-002	Llave de paso 1/2"	5	1	13000.00	19500.00	4	6	t
1	HM-001	Martillo de uña 16 oz	1	2	18000.00	26000.00	38	5	t
22	JA-001	Manguera de jardín 1/2" x 15 m	8	1	28000.00	42000.00	18	4	t
18	PI-001	Pintura vinilo blanco tipo 1 (galón)	6	4	42000.00	59000.00	34	8	t
8	TF-001	Tornillo drywall 6x1" (caja x100)	3	1	6500.00	10000.00	90	20	t
12	EL-002	Toma doble con polo a tierra	4	3	5500.00	9000.00	67	10	t
13	EL-003	Bombillo LED 12 W	4	3	4500.00	7500.00	82	15	t
2	HM-002	Destornillador de pala 1/4"	1	2	5500.00	8500.00	50	10	t
3	HM-003	Alicate universal 8"	1	2	16000.00	24000.00	29	5	t
11	EL-001	Cable THHN calibre 12 (metro)	4	3	2200.00	3500.00	320	100	t
7	HE-003	Sierra circular 7-1/4" 1400 W	2	2	280000.00	389000.00	4	2	t
15	PL-001	Tubo PVC presión 1/2" x 6 m	5	1	11000.00	16500.00	59	10	t
17	PL-003	Cinta teflón 1/2" x 10 m	5	1	1200.00	2500.00	186	30	t
4	HM-004	Flexómetro 5 m	1	1	9000.00	14000.00	47	8	t
9	TF-002	Chazo plástico 1/4" (bolsa x100)	3	1	4000.00	6500.00	84	15	t
20	CO-001	Cemento gris uso general 50 kg	7	5	29000.00	36500.00	64	30	t
21	CO-002	Arena de río (bulto 40 kg)	7	5	6000.00	9500.00	55	20	t
19	PI-002	Brocha 3"	6	4	4500.00	7500.00	51	10	t
10	TF-003	Puntilla con cabeza 2" (libra)	3	1	3500.00	5500.00	137	20	t
5	HE-001	Taladro percutor 1/2" 650 W	2	2	165000.00	229000.00	8	3	t
\.


--
-- Data for Name: proveedores; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.proveedores (id, nit, nombre, telefono, email, activo) FROM stdin;
1	900123456-1	Distribuidora Ferretera Andina S.A.S.	6087701234	ventas@ferreandina.com	t
2	900234567-2	Herramientas Pro Colombia Ltda.	6017452233	pedidos@herramientaspro.co	t
3	900345678-3	Eléctricos del Centro S.A.S.	6087623344	comercial@electricoscentro.com	t
4	900456789-4	Pinturas y Acabados Boyacá S.A.S.	6087405566	contacto@pinturasboyaca.com	t
5	900567890-5	Cementos y Agregados del Altiplano S.A.	6087718899	despachos@cementosaltiplano.com	t
\.


--
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.roles (id, nombre) FROM stdin;
1	admin
2	vendedor
\.


--
-- Data for Name: usuarios; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.usuarios (id, nombre, email, password_hash, rol_id, activo) FROM stdin;
1	Administrador del sistema	admin@ferreteria.com	$2b$12$0SzmGu6S34Ty62VwuDdNT.0SMM3sx5XB2p8sLI2jpAN0hWvsNYi2K	1	t
2	Vendedor de mostrador	vendedor@ferreteria.com	$2b$12$jK5nL72SKLecOs8.2G5xHOOgo3zZTfzTRWBAJwQm5J8KreAjrb/ta	2	t
\.


--
-- Data for Name: ventas; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ventas (id, cliente_id, usuario_id, fecha, estado) FROM stdin;
1	9	1	2026-08-24 08:17:00-05	PAGADA
2	1	2	2026-08-26 09:17:00-05	PAGADA
3	2	2	2026-08-29 10:17:00-05	PAGADA
4	10	1	2026-08-31 11:17:00-05	PAGADA
5	1	2	2026-09-03 12:17:00-05	PAGADA
6	3	2	2026-09-06 13:17:00-05	PAGADA
7	5	2	2026-09-08 14:17:00-05	PAGADA
8	9	2	2026-09-11 15:17:00-05	PAGADA
9	1	2	2026-09-14 16:17:00-05	PAGADA
10	4	2	2026-09-16 08:17:00-05	PAGADA
11	2	2	2026-09-19 09:17:00-05	PAGADA
12	6	2	2026-09-22 10:17:00-05	PAGADA
13	10	1	2026-09-24 11:17:00-05	PAGADA
14	1	2	2026-09-27 12:17:00-05	PAGADA
15	7	2	2026-09-30 13:17:00-05	PAGADA
16	5	2	2026-10-02 14:17:00-05	PAGADA
17	9	1	2026-10-05 15:17:00-05	PAGADA
18	1	2	2026-10-08 16:17:00-05	ANULADA
19	8	2	2026-10-11 08:17:00-05	PAGADA
20	4	2	2026-10-13 09:17:00-05	PAGADA
21	10	2	2026-10-16 10:17:00-05	PAGADA
22	1	2	2026-10-19 11:17:00-05	PAGADA
23	3	2	2026-10-22 12:17:00-05	PAGADA
24	2	2	2026-10-25 13:17:00-05	PAGADA
25	9	2	2026-10-28 14:17:00-05	PAGADA
26	1	2	2026-11-01 15:17:00-05	PAGADA
27	6	2	2026-11-04 16:17:00-05	PAGADA
28	10	1	2026-11-08 08:17:00-05	PAGADA
29	7	2	2026-11-11 09:17:00-05	PAGADA
30	1	2	2026-11-14 10:17:00-05	PAGADA
31	5	2	2026-11-16 11:17:00-05	PAGADA
\.


--
-- Name: auditoria_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.auditoria_id_seq', 34, true);


--
-- Name: categorias_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.categorias_id_seq', 8, true);


--
-- Name: clientes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.clientes_id_seq', 10, true);


--
-- Name: detalle_venta_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.detalle_venta_id_seq', 68, true);


--
-- Name: movimientos_inventario_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.movimientos_inventario_id_seq', 91, true);


--
-- Name: productos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.productos_id_seq', 22, true);


--
-- Name: proveedores_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.proveedores_id_seq', 5, true);


--
-- Name: roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.roles_id_seq', 2, true);


--
-- Name: usuarios_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.usuarios_id_seq', 2, true);


--
-- Name: ventas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ventas_id_seq', 31, true);


--
-- Name: auditoria auditoria_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auditoria
    ADD CONSTRAINT auditoria_pkey PRIMARY KEY (id);


--
-- Name: categorias categorias_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT categorias_nombre_key UNIQUE (nombre);


--
-- Name: categorias categorias_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT categorias_pkey PRIMARY KEY (id);


--
-- Name: clientes clientes_documento_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clientes
    ADD CONSTRAINT clientes_documento_key UNIQUE (documento);


--
-- Name: clientes clientes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clientes
    ADD CONSTRAINT clientes_pkey PRIMARY KEY (id);


--
-- Name: detalle_venta detalle_venta_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_venta
    ADD CONSTRAINT detalle_venta_pkey PRIMARY KEY (id);


--
-- Name: movimientos_inventario movimientos_inventario_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movimientos_inventario
    ADD CONSTRAINT movimientos_inventario_pkey PRIMARY KEY (id);


--
-- Name: productos productos_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.productos
    ADD CONSTRAINT productos_codigo_key UNIQUE (codigo);


--
-- Name: productos productos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.productos
    ADD CONSTRAINT productos_pkey PRIMARY KEY (id);


--
-- Name: proveedores proveedores_nit_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proveedores
    ADD CONSTRAINT proveedores_nit_key UNIQUE (nit);


--
-- Name: proveedores proveedores_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proveedores
    ADD CONSTRAINT proveedores_pkey PRIMARY KEY (id);


--
-- Name: roles roles_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_nombre_key UNIQUE (nombre);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: detalle_venta uq_detalle_venta_producto; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_venta
    ADD CONSTRAINT uq_detalle_venta_producto UNIQUE (venta_id, producto_id);


--
-- Name: usuarios usuarios_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_email_key UNIQUE (email);


--
-- Name: usuarios usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id);


--
-- Name: ventas ventas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ventas
    ADD CONSTRAINT ventas_pkey PRIMARY KEY (id);


--
-- Name: idx_detalle_venta_producto; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_detalle_venta_producto ON public.detalle_venta USING btree (producto_id);


--
-- Name: idx_productos_nombre_trgm; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_productos_nombre_trgm ON public.productos USING gin (nombre public.gin_trgm_ops);


--
-- Name: idx_ventas_fecha; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ventas_fecha ON public.ventas USING btree (fecha);


--
-- Name: clientes trg_auditoria; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria AFTER INSERT OR DELETE OR UPDATE ON public.clientes FOR EACH ROW EXECUTE FUNCTION public.fn_trg_auditoria();


--
-- Name: productos trg_auditoria; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria AFTER INSERT OR DELETE OR UPDATE ON public.productos FOR EACH ROW EXECUTE FUNCTION public.fn_trg_auditoria();


--
-- Name: usuarios trg_auditoria; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria AFTER INSERT OR DELETE OR UPDATE ON public.usuarios FOR EACH ROW EXECUTE FUNCTION public.fn_trg_auditoria();


--
-- Name: detalle_venta trg_detalle_venta_stock; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_detalle_venta_stock AFTER INSERT ON public.detalle_venta FOR EACH ROW EXECUTE FUNCTION public.fn_trg_detalle_venta_stock();


--
-- Name: detalle_venta trg_detalle_venta_validar; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_detalle_venta_validar BEFORE INSERT ON public.detalle_venta FOR EACH ROW EXECUTE FUNCTION public.fn_trg_detalle_venta_validar();


--
-- Name: productos trg_productos_validar_precio; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_productos_validar_precio BEFORE INSERT OR UPDATE OF precio_compra, precio_venta ON public.productos FOR EACH ROW EXECUTE FUNCTION public.fn_trg_productos_validar_precio();


--
-- Name: detalle_venta detalle_venta_producto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_venta
    ADD CONSTRAINT detalle_venta_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES public.productos(id);


--
-- Name: detalle_venta detalle_venta_venta_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_venta
    ADD CONSTRAINT detalle_venta_venta_id_fkey FOREIGN KEY (venta_id) REFERENCES public.ventas(id);


--
-- Name: movimientos_inventario movimientos_inventario_producto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movimientos_inventario
    ADD CONSTRAINT movimientos_inventario_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES public.productos(id) ON DELETE CASCADE;


--
-- Name: movimientos_inventario movimientos_inventario_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movimientos_inventario
    ADD CONSTRAINT movimientos_inventario_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id);


--
-- Name: movimientos_inventario movimientos_inventario_venta_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movimientos_inventario
    ADD CONSTRAINT movimientos_inventario_venta_id_fkey FOREIGN KEY (venta_id) REFERENCES public.ventas(id);


--
-- Name: productos productos_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.productos
    ADD CONSTRAINT productos_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorias(id);


--
-- Name: productos productos_proveedor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.productos
    ADD CONSTRAINT productos_proveedor_id_fkey FOREIGN KEY (proveedor_id) REFERENCES public.proveedores(id);


--
-- Name: usuarios usuarios_rol_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_rol_id_fkey FOREIGN KEY (rol_id) REFERENCES public.roles(id);


--
-- Name: ventas ventas_cliente_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ventas
    ADD CONSTRAINT ventas_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.clientes(id);


--
-- Name: ventas ventas_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ventas
    ADD CONSTRAINT ventas_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA public TO app_ferreteria;


--
-- Name: FUNCTION gtrgm_in(cstring); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.gtrgm_in(cstring) TO app_ferreteria;


--
-- Name: FUNCTION gtrgm_out(public.gtrgm); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.gtrgm_out(public.gtrgm) TO app_ferreteria;


--
-- Name: FUNCTION fn_clasificar_cliente(p_cliente_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fn_clasificar_cliente(p_cliente_id integer) TO app_ferreteria;


--
-- Name: FUNCTION fn_estado_stock(p_stock integer, p_minimo integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fn_estado_stock(p_stock integer, p_minimo integer) TO app_ferreteria;


--
-- Name: FUNCTION fn_reporte_categorias_sobre_monto(p_monto numeric); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fn_reporte_categorias_sobre_monto(p_monto numeric) TO app_ferreteria;


--
-- Name: FUNCTION fn_reporte_clientes_sobre_promedio(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fn_reporte_clientes_sobre_promedio() TO app_ferreteria;


--
-- Name: FUNCTION fn_total_venta(p_venta_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fn_total_venta(p_venta_id integer) TO app_ferreteria;


--
-- Name: FUNCTION fn_trg_auditoria(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fn_trg_auditoria() TO app_ferreteria;


--
-- Name: FUNCTION fn_trg_detalle_venta_stock(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fn_trg_detalle_venta_stock() TO app_ferreteria;


--
-- Name: FUNCTION fn_trg_detalle_venta_validar(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fn_trg_detalle_venta_validar() TO app_ferreteria;


--
-- Name: FUNCTION fn_trg_productos_validar_precio(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fn_trg_productos_validar_precio() TO app_ferreteria;


--
-- Name: FUNCTION gin_extract_query_trgm(text, internal, smallint, internal, internal, internal, internal); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.gin_extract_query_trgm(text, internal, smallint, internal, internal, internal, internal) TO app_ferreteria;


--
-- Name: FUNCTION gin_extract_value_trgm(text, internal); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.gin_extract_value_trgm(text, internal) TO app_ferreteria;


--
-- Name: FUNCTION gin_trgm_consistent(internal, smallint, text, integer, internal, internal, internal, internal); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.gin_trgm_consistent(internal, smallint, text, integer, internal, internal, internal, internal) TO app_ferreteria;


--
-- Name: FUNCTION gin_trgm_triconsistent(internal, smallint, text, integer, internal, internal, internal); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.gin_trgm_triconsistent(internal, smallint, text, integer, internal, internal, internal) TO app_ferreteria;


--
-- Name: FUNCTION gtrgm_compress(internal); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.gtrgm_compress(internal) TO app_ferreteria;


--
-- Name: FUNCTION gtrgm_consistent(internal, text, smallint, oid, internal); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.gtrgm_consistent(internal, text, smallint, oid, internal) TO app_ferreteria;


--
-- Name: FUNCTION gtrgm_decompress(internal); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.gtrgm_decompress(internal) TO app_ferreteria;


--
-- Name: FUNCTION gtrgm_distance(internal, text, smallint, oid, internal); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.gtrgm_distance(internal, text, smallint, oid, internal) TO app_ferreteria;


--
-- Name: FUNCTION gtrgm_options(internal); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.gtrgm_options(internal) TO app_ferreteria;


--
-- Name: FUNCTION gtrgm_penalty(internal, internal, internal); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.gtrgm_penalty(internal, internal, internal) TO app_ferreteria;


--
-- Name: FUNCTION gtrgm_picksplit(internal, internal); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.gtrgm_picksplit(internal, internal) TO app_ferreteria;


--
-- Name: FUNCTION gtrgm_same(public.gtrgm, public.gtrgm, internal); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.gtrgm_same(public.gtrgm, public.gtrgm, internal) TO app_ferreteria;


--
-- Name: FUNCTION gtrgm_union(internal, internal); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.gtrgm_union(internal, internal) TO app_ferreteria;


--
-- Name: FUNCTION set_limit(real); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.set_limit(real) TO app_ferreteria;


--
-- Name: FUNCTION show_limit(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.show_limit() TO app_ferreteria;


--
-- Name: FUNCTION show_trgm(text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.show_trgm(text) TO app_ferreteria;


--
-- Name: FUNCTION similarity(text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.similarity(text, text) TO app_ferreteria;


--
-- Name: FUNCTION similarity_dist(text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.similarity_dist(text, text) TO app_ferreteria;


--
-- Name: FUNCTION similarity_op(text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.similarity_op(text, text) TO app_ferreteria;


--
-- Name: PROCEDURE sp_actualizar_producto(IN p_producto_id integer, IN p_codigo character varying, IN p_nombre character varying, IN p_categoria_id integer, IN p_proveedor_id integer, IN p_precio_compra numeric, IN p_precio_venta numeric, IN p_stock_minimo integer, IN p_activo boolean); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.sp_actualizar_producto(IN p_producto_id integer, IN p_codigo character varying, IN p_nombre character varying, IN p_categoria_id integer, IN p_proveedor_id integer, IN p_precio_compra numeric, IN p_precio_venta numeric, IN p_stock_minimo integer, IN p_activo boolean) TO app_ferreteria;


--
-- Name: PROCEDURE sp_anular_venta(IN p_venta_id integer, IN p_usuario_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.sp_anular_venta(IN p_venta_id integer, IN p_usuario_id integer) TO app_ferreteria;


--
-- Name: PROCEDURE sp_crear_producto(IN p_codigo character varying, IN p_nombre character varying, IN p_categoria_id integer, IN p_proveedor_id integer, IN p_precio_compra numeric, IN p_precio_venta numeric, IN p_stock integer, IN p_stock_minimo integer, IN p_usuario_id integer, OUT p_producto_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.sp_crear_producto(IN p_codigo character varying, IN p_nombre character varying, IN p_categoria_id integer, IN p_proveedor_id integer, IN p_precio_compra numeric, IN p_precio_venta numeric, IN p_stock integer, IN p_stock_minimo integer, IN p_usuario_id integer, OUT p_producto_id integer) TO app_ferreteria;


--
-- Name: PROCEDURE sp_eliminar_cliente(IN p_cliente_id integer, OUT p_resultado character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.sp_eliminar_cliente(IN p_cliente_id integer, OUT p_resultado character varying) TO app_ferreteria;


--
-- Name: PROCEDURE sp_registrar_entrada(IN p_producto_id integer, IN p_cantidad integer, IN p_usuario_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.sp_registrar_entrada(IN p_producto_id integer, IN p_cantidad integer, IN p_usuario_id integer) TO app_ferreteria;


--
-- Name: PROCEDURE sp_registrar_venta(IN p_cliente_id integer, IN p_usuario_id integer, IN p_items jsonb, OUT p_venta_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.sp_registrar_venta(IN p_cliente_id integer, IN p_usuario_id integer, IN p_items jsonb, OUT p_venta_id integer) TO app_ferreteria;


--
-- Name: FUNCTION strict_word_similarity(text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.strict_word_similarity(text, text) TO app_ferreteria;


--
-- Name: FUNCTION strict_word_similarity_commutator_op(text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.strict_word_similarity_commutator_op(text, text) TO app_ferreteria;


--
-- Name: FUNCTION strict_word_similarity_dist_commutator_op(text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.strict_word_similarity_dist_commutator_op(text, text) TO app_ferreteria;


--
-- Name: FUNCTION strict_word_similarity_dist_op(text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.strict_word_similarity_dist_op(text, text) TO app_ferreteria;


--
-- Name: FUNCTION strict_word_similarity_op(text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.strict_word_similarity_op(text, text) TO app_ferreteria;


--
-- Name: FUNCTION word_similarity(text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.word_similarity(text, text) TO app_ferreteria;


--
-- Name: FUNCTION word_similarity_commutator_op(text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.word_similarity_commutator_op(text, text) TO app_ferreteria;


--
-- Name: FUNCTION word_similarity_dist_commutator_op(text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.word_similarity_dist_commutator_op(text, text) TO app_ferreteria;


--
-- Name: FUNCTION word_similarity_dist_op(text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.word_similarity_dist_op(text, text) TO app_ferreteria;


--
-- Name: FUNCTION word_similarity_op(text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.word_similarity_op(text, text) TO app_ferreteria;


--
-- Name: TABLE auditoria; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.auditoria TO app_ferreteria;


--
-- Name: SEQUENCE auditoria_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.auditoria_id_seq TO app_ferreteria;


--
-- Name: TABLE categorias; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.categorias TO app_ferreteria;


--
-- Name: SEQUENCE categorias_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.categorias_id_seq TO app_ferreteria;


--
-- Name: TABLE clientes; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.clientes TO app_ferreteria;


--
-- Name: SEQUENCE clientes_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.clientes_id_seq TO app_ferreteria;


--
-- Name: TABLE detalle_venta; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.detalle_venta TO app_ferreteria;


--
-- Name: SEQUENCE detalle_venta_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.detalle_venta_id_seq TO app_ferreteria;


--
-- Name: TABLE movimientos_inventario; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.movimientos_inventario TO app_ferreteria;


--
-- Name: SEQUENCE movimientos_inventario_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.movimientos_inventario_id_seq TO app_ferreteria;


--
-- Name: TABLE productos; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.productos TO app_ferreteria;


--
-- Name: SEQUENCE productos_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.productos_id_seq TO app_ferreteria;


--
-- Name: TABLE proveedores; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.proveedores TO app_ferreteria;


--
-- Name: SEQUENCE proveedores_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.proveedores_id_seq TO app_ferreteria;


--
-- Name: TABLE roles; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.roles TO app_ferreteria;


--
-- Name: SEQUENCE roles_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.roles_id_seq TO app_ferreteria;


--
-- Name: TABLE usuarios; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.usuarios TO app_ferreteria;


--
-- Name: SEQUENCE usuarios_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.usuarios_id_seq TO app_ferreteria;


--
-- Name: TABLE ventas; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.ventas TO app_ferreteria;


--
-- Name: SEQUENCE ventas_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.ventas_id_seq TO app_ferreteria;


--
-- Name: TABLE vw_stock_bajo; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.vw_stock_bajo TO app_ferreteria;


--
-- Name: TABLE vw_top_productos; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.vw_top_productos TO app_ferreteria;


--
-- Name: TABLE vw_ventas_detalle; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.vw_ventas_detalle TO app_ferreteria;


--
-- Name: TABLE vw_ventas_categoria_mes; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.vw_ventas_categoria_mes TO app_ferreteria;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO app_ferreteria;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO app_ferreteria;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO app_ferreteria;


--
-- PostgreSQL database dump complete
--

\unrestrict PsaEAwNmuwGUN0mm3NK6eE6sU16o6h6a6ai7UlS7DJnLqeje97fTLgxVgLnvv5w

