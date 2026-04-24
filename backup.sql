--
-- PostgreSQL database dump
--

\restrict sfdPigVbMJQqglariw5cAhs0eHVHcOAAbxF9dYvVirMPJphBamNgxCHaGUCGlsn

-- Dumped from database version 18.3
-- Dumped by pg_dump version 18.3

-- Started on 2026-04-24 00:25:44

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
-- TOC entry 241 (class 1255 OID 16868)
-- Name: actualizar_stock(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.actualizar_stock() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Verificar stock disponible
    IF (SELECT cantidad FROM stock WHERE producto_id = NEW.producto_id) < NEW.cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente para producto_id %', NEW.producto_id;
    END IF;
    
    -- Descontar stock
    UPDATE stock 
    SET cantidad = cantidad - NEW.cantidad,
        ultima_actualizacion = CURRENT_TIMESTAMP
    WHERE producto_id = NEW.producto_id;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.actualizar_stock() OWNER TO postgres;

--
-- TOC entry 243 (class 1255 OID 16872)
-- Name: actualizar_total_pedido(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.actualizar_total_pedido() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE pedido
    SET total = (
        SELECT COALESCE(SUM(subtotal), 0)
        FROM pedido_producto
        WHERE pedido_id = NEW.pedido_id
    )
    WHERE id = NEW.pedido_id;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.actualizar_total_pedido() OWNER TO postgres;

--
-- TOC entry 244 (class 1255 OID 16888)
-- Name: asignar_piloto(integer, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.asignar_piloto(IN p_pedido_id integer, IN p_piloto_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE pedido
    SET piloto_id = p_piloto_id,
        fecha_asignacion = CURRENT_TIMESTAMP
    WHERE id = p_pedido_id;
END;
$$;


ALTER PROCEDURE public.asignar_piloto(IN p_pedido_id integer, IN p_piloto_id integer) OWNER TO postgres;

--
-- TOC entry 245 (class 1255 OID 16889)
-- Name: cambiar_estado_pedido(integer, character varying, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.cambiar_estado_pedido(IN p_pedido_id integer, IN p_estado_nombre character varying, IN p_motivo text DEFAULT NULL::text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_estado_id INT;
BEGIN
    -- Obtener ID del estado
    SELECT id INTO v_estado_id FROM estado WHERE nombre = p_estado_nombre;
    
    -- Actualizar pedido
    UPDATE pedido
    SET estado_id = v_estado_id,
        fecha_entrega = CASE WHEN p_estado_nombre = 'Entregado' THEN CURRENT_TIMESTAMP ELSE fecha_entrega END,
        motivo_no_entrega = CASE WHEN p_estado_nombre = 'No entregado' THEN p_motivo ELSE motivo_no_entrega END
    WHERE id = p_pedido_id;
END;
$$;


ALTER PROCEDURE public.cambiar_estado_pedido(IN p_pedido_id integer, IN p_estado_nombre character varying, IN p_motivo text) OWNER TO postgres;

--
-- TOC entry 242 (class 1255 OID 16870)
-- Name: registrar_log_estado(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.registrar_log_estado() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF OLD.estado_id != NEW.estado_id THEN
        INSERT INTO log_entrega (pedido_id, estado_anterior_id, estado_nuevo_id, usuario_id)
        VALUES (NEW.id, OLD.estado_id, NEW.estado_id, NEW.piloto_id);
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.registrar_log_estado() OWNER TO postgres;

--
-- TOC entry 263 (class 1255 OID 16909)
-- Name: sp_actualizar_cliente(integer, character varying, character varying, character varying, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sp_actualizar_cliente(p_id integer, p_nombre character varying DEFAULT NULL::character varying, p_telefono character varying DEFAULT NULL::character varying, p_email character varying DEFAULT NULL::character varying, p_activo boolean DEFAULT NULL::boolean) RETURNS TABLE(id integer, nombre character varying, telefono character varying, email character varying, activo boolean, mensaje character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_cliente_existe INT;
BEGIN
    SELECT COUNT(*) INTO v_cliente_existe FROM cliente WHERE id = p_id;
    IF v_cliente_existe = 0 THEN
        RETURN QUERY SELECT NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::BOOLEAN,
                     'Error: Cliente no encontrado'::VARCHAR;
        RETURN;
    END IF;
    
    UPDATE cliente 
    SET 
        nombre = COALESCE(p_nombre, nombre),
        telefono = COALESCE(p_telefono, telefono),
        email = COALESCE(p_email, email),
        activo = COALESCE(p_activo, activo)
    WHERE id = p_id;
    
    RETURN QUERY
    SELECT c.id, c.nombre, c.telefono, c.email, c.activo,
           'Cliente actualizado exitosamente'::VARCHAR
    FROM cliente c
    WHERE c.id = p_id;
END;
$$;


ALTER FUNCTION public.sp_actualizar_cliente(p_id integer, p_nombre character varying, p_telefono character varying, p_email character varying, p_activo boolean) OWNER TO postgres;

--
-- TOC entry 275 (class 1255 OID 16922)
-- Name: sp_actualizar_producto(integer, character varying, text, numeric, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sp_actualizar_producto(p_id integer, p_nombre character varying DEFAULT NULL::character varying, p_descripcion text DEFAULT NULL::text, p_precio numeric DEFAULT NULL::numeric, p_activo boolean DEFAULT NULL::boolean) RETURNS TABLE(id integer, nombre character varying, descripcion text, precio numeric, activo boolean, mensaje character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_producto_existe INT;
BEGIN
    SELECT COUNT(*) INTO v_producto_existe FROM producto WHERE id = p_id;
    IF v_producto_existe = 0 THEN
        RETURN QUERY SELECT NULL::INT, NULL::VARCHAR, NULL::TEXT, NULL::DECIMAL, NULL::BOOLEAN,
                     'Error: Producto no encontrado'::VARCHAR;
        RETURN;
    END IF;
    
    IF p_precio IS NOT NULL AND p_precio < 0 THEN
        RETURN QUERY SELECT NULL::INT, NULL::VARCHAR, NULL::TEXT, NULL::DECIMAL, NULL::BOOLEAN,
                     'Error: El precio no puede ser negativo'::VARCHAR;
        RETURN;
    END IF;
    
    UPDATE producto 
    SET 
        nombre = COALESCE(p_nombre, nombre),
        descripcion = COALESCE(p_descripcion, descripcion),
        precio = COALESCE(p_precio, precio),
        activo = COALESCE(p_activo, activo)
    WHERE id = p_id;
    
    RETURN QUERY
    SELECT p.id, p.nombre, p.descripcion, p.precio, p.activo,
           'Producto actualizado exitosamente'::VARCHAR
    FROM producto p
    WHERE p.id = p_id;
END;
$$;


ALTER FUNCTION public.sp_actualizar_producto(p_id integer, p_nombre character varying, p_descripcion text, p_precio numeric, p_activo boolean) OWNER TO postgres;

--
-- TOC entry 271 (class 1255 OID 16914)
-- Name: sp_actualizar_stock(integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sp_actualizar_stock(p_producto_id integer, p_cantidad integer, p_operacion character varying DEFAULT 'sumar'::character varying) RETURNS TABLE(producto_id integer, cantidad_anterior integer, cantidad_nueva integer, mensaje character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_stock_actual INT;
    v_nueva_cantidad INT;
BEGIN
    SELECT cantidad INTO v_stock_actual FROM stock WHERE producto_id = p_producto_id;
    
    IF v_stock_actual IS NULL THEN
        RETURN QUERY SELECT NULL::INT, NULL::INT, NULL::INT,
                     'Error: Producto no tiene registro de stock'::VARCHAR;
        RETURN;
    END IF;
    
    IF p_operacion = 'sumar' THEN
        v_nueva_cantidad := v_stock_actual + p_cantidad;
    ELSIF p_operacion = 'restar' THEN
        v_nueva_cantidad := v_stock_actual - p_cantidad;
        IF v_nueva_cantidad < 0 THEN
            RETURN QUERY SELECT NULL::INT, NULL::INT, NULL::INT,
                         'Error: Stock insuficiente'::VARCHAR;
            RETURN;
        END IF;
    ELSIF p_operacion = 'establecer' THEN
        v_nueva_cantidad := p_cantidad;
        IF v_nueva_cantidad < 0 THEN
            RETURN QUERY SELECT NULL::INT, NULL::INT, NULL::INT,
                         'Error: La cantidad no puede ser negativa'::VARCHAR;
            RETURN;
        END IF;
    ELSE
        RETURN QUERY SELECT NULL::INT, NULL::INT, NULL::INT,
                     'Error: Operación no válida'::VARCHAR;
        RETURN;
    END IF;
    
    UPDATE stock 
    SET cantidad = v_nueva_cantidad, ultima_actualizacion = CURRENT_TIMESTAMP
    WHERE producto_id = p_producto_id;
    
    RETURN QUERY SELECT 
        p_producto_id, v_stock_actual, v_nueva_cantidad,
        'Stock actualizado exitosamente'::VARCHAR;
END;
$$;


ALTER FUNCTION public.sp_actualizar_stock(p_producto_id integer, p_cantidad integer, p_operacion character varying) OWNER TO postgres;

--
-- TOC entry 279 (class 1255 OID 16927)
-- Name: sp_actualizar_usuario(integer, character varying, character varying, character varying, integer, boolean, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sp_actualizar_usuario(p_id integer, p_nombre character varying DEFAULT NULL::character varying, p_telefono character varying DEFAULT NULL::character varying, p_email character varying DEFAULT NULL::character varying, p_rol_id integer DEFAULT NULL::integer, p_activo boolean DEFAULT NULL::boolean, p_contrasena_hash character varying DEFAULT NULL::character varying) RETURNS TABLE(usuario_id integer, usuario_nombre character varying, usuario_telefono character varying, usuario_email character varying, usuario_rol_id integer, rol_nombre character varying, usuario_activo boolean, mensaje character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_usuario_existe INT;
    v_rol_nombre VARCHAR;
BEGIN
    -- 1. Verificar que el usuario existe
    SELECT COUNT(*) INTO v_usuario_existe FROM usuario WHERE id = p_id;
    IF v_usuario_existe = 0 THEN
        RETURN QUERY SELECT NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, 
                     NULL::INT, NULL::VARCHAR, NULL::BOOLEAN, 'Error: Usuario no encontrado'::VARCHAR;
        RETURN;
    END IF;
    
    -- 2. Validar rol si se actualiza
    IF p_rol_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM rol WHERE id = p_rol_id) THEN
            RETURN QUERY SELECT NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, 
                         NULL::INT, NULL::VARCHAR, NULL::BOOLEAN, 'Error: El rol no existe'::VARCHAR;
            RETURN;
        END IF;
    END IF;
    
    -- 3. Validar teléfono único si se actualiza
    IF p_telefono IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM usuario WHERE telefono = p_telefono AND id != p_id) THEN
            RETURN QUERY SELECT NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, 
                         NULL::INT, NULL::VARCHAR, NULL::BOOLEAN, 'Error: El teléfono ya está registrado por otro usuario'::VARCHAR;
            RETURN;
        END IF;
    END IF;
    
    -- 4. Validar email único si se actualiza
    IF p_email IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM usuario WHERE email = p_email AND id != p_id) THEN
            RETURN QUERY SELECT NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, 
                         NULL::INT, NULL::VARCHAR, NULL::BOOLEAN, 'Error: El email ya está registrado por otro usuario'::VARCHAR;
            RETURN;
        END IF;
    END IF;
    
    -- 5. Actualizar usuario (usando COALESCE con los parámetros)
    UPDATE usuario 
    SET 
        nombre = COALESCE(p_nombre, usuario.nombre),
        telefono = COALESCE(p_telefono, usuario.telefono),
        email = COALESCE(p_email, usuario.email),
        rol_id = COALESCE(p_rol_id, usuario.rol_id),
        activo = COALESCE(p_activo, usuario.activo),
        contrasena_hash = COALESCE(p_contrasena_hash, usuario.contrasena_hash)
    WHERE id = p_id;
    
    -- 6. Obtener nombre del rol
    SELECT r.nombre INTO v_rol_nombre 
    FROM usuario u 
    JOIN rol r ON r.id = u.rol_id 
    WHERE u.id = p_id;
    
    -- 7. Retornar éxito
    RETURN QUERY
    SELECT u.id, u.nombre, u.telefono, u.email, 
           u.rol_id, v_rol_nombre, u.activo,
           'Usuario actualizado exitosamente'::VARCHAR
    FROM usuario u
    WHERE u.id = p_id;
    
END;
$$;


ALTER FUNCTION public.sp_actualizar_usuario(p_id integer, p_nombre character varying, p_telefono character varying, p_email character varying, p_rol_id integer, p_activo boolean, p_contrasena_hash character varying) OWNER TO postgres;

--
-- TOC entry 269 (class 1255 OID 16918)
-- Name: sp_asignar_piloto(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sp_asignar_piloto(p_pedido_id integer, p_piloto_id integer) RETURNS TABLE(success boolean, mensaje character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_pedido_existe INT;
    v_piloto_valido INT;
    v_estado_actual VARCHAR;
BEGIN
    -- Verificar pedido existe y está en estado correcto
    SELECT COUNT(*), e.nombre INTO v_pedido_existe, v_estado_actual
    FROM pedido p
    JOIN estado e ON e.id = p.estado_id
    WHERE p.id = p_pedido_id
    GROUP BY e.nombre;
    
    IF v_pedido_existe = 0 THEN
        RETURN QUERY SELECT FALSE::BOOLEAN, 'Error: Pedido no encontrado'::VARCHAR;
        RETURN;
    END IF;
    
    IF v_estado_actual != 'Por entregar' THEN
        RETURN QUERY SELECT FALSE::BOOLEAN, 'Error: El pedido no está en estado "Por entregar"'::VARCHAR;
        RETURN;
    END IF;
    
    -- Verificar piloto existe y es piloto
    SELECT COUNT(*) INTO v_piloto_valido 
    FROM usuario WHERE id = p_piloto_id AND rol_id = 2 AND activo = true;
    
    IF v_piloto_valido = 0 THEN
        RETURN QUERY SELECT FALSE::BOOLEAN, 'Error: Piloto no válido o inactivo'::VARCHAR;
        RETURN;
    END IF;
    
    -- Asignar piloto y cambiar estado
    UPDATE pedido 
    SET piloto_id = p_piloto_id, 
        fecha_asignacion = CURRENT_TIMESTAMP,
        estado_id = 2 -- 'En camino'
    WHERE id = p_pedido_id;
    
    RETURN QUERY SELECT TRUE::BOOLEAN, 'Piloto asignado exitosamente'::VARCHAR;
END;
$$;


ALTER FUNCTION public.sp_asignar_piloto(p_pedido_id integer, p_piloto_id integer) OWNER TO postgres;

--
-- TOC entry 260 (class 1255 OID 16906)
-- Name: sp_crear_cliente(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sp_crear_cliente(p_nombre character varying, p_telefono character varying, p_email character varying DEFAULT NULL::character varying) RETURNS TABLE(id integer, nombre character varying, telefono character varying, email character varying, fecha_registro timestamp without time zone, mensaje character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_telefono_existe INT;
    v_email_existe INT;
    v_cliente_id INT;
BEGIN
    -- Validar teléfono único
    SELECT COUNT(*) INTO v_telefono_existe FROM cliente WHERE telefono = p_telefono;
    IF v_telefono_existe > 0 THEN
        RETURN QUERY SELECT NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::TIMESTAMP, 
                     'Error: El teléfono ya está registrado'::VARCHAR;
        RETURN;
    END IF;
    
    -- Validar email único si se proporcionó
    IF p_email IS NOT NULL THEN
        SELECT COUNT(*) INTO v_email_existe FROM cliente WHERE email = p_email;
        IF v_email_existe > 0 THEN
            RETURN QUERY SELECT NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::TIMESTAMP,
                         'Error: El email ya está registrado'::VARCHAR;
            RETURN;
        END IF;
    END IF;
    
    -- Insertar cliente
    INSERT INTO cliente (nombre, telefono, email)
    VALUES (p_nombre, p_telefono, p_email)
    RETURNING id INTO v_cliente_id;
    
    RETURN QUERY SELECT 
        v_cliente_id, p_nombre, p_telefono, p_email, CURRENT_TIMESTAMP,
        'Cliente creado exitosamente'::VARCHAR;
END;
$$;


ALTER FUNCTION public.sp_crear_cliente(p_nombre character varying, p_telefono character varying, p_email character varying) OWNER TO postgres;

--
-- TOC entry 267 (class 1255 OID 16916)
-- Name: sp_crear_pedido(integer, integer, integer, jsonb); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sp_crear_pedido(p_cliente_id integer, p_ubicacion_id integer, p_receptor_id integer, p_productos jsonb) RETURNS TABLE(pedido_id integer, estado character varying, total numeric, mensaje character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_pedido_id INT;
    v_total DECIMAL := 0;
    v_item RECORD;
    v_precio DECIMAL;
    v_subtotal DECIMAL;
    v_stock_suficiente BOOLEAN;
BEGIN
    -- Validar cliente
    IF NOT EXISTS (SELECT 1 FROM cliente WHERE id = p_cliente_id AND activo = true) THEN
        RETURN QUERY SELECT NULL::INT, NULL::VARCHAR, NULL::DECIMAL,
                     'Error: Cliente no existe o está inactivo'::VARCHAR;
        RETURN;
    END IF;
    
    -- Validar ubicación
    IF NOT EXISTS (SELECT 1 FROM ubicacion WHERE id = p_ubicacion_id AND cliente_id = p_cliente_id) THEN
        RETURN QUERY SELECT NULL::INT, NULL::VARCHAR, NULL::DECIMAL,
                     'Error: Ubicación no válida para este cliente'::VARCHAR;
        RETURN;
    END IF;
    
    -- Validar receptor
    IF NOT EXISTS (SELECT 1 FROM usuario WHERE id = p_receptor_id AND rol_id = 1 AND activo = true) THEN
        RETURN QUERY SELECT NULL::INT, NULL::VARCHAR, NULL::DECIMAL,
                     'Error: Receptor no válido'::VARCHAR;
        RETURN;
    END IF;
    
    -- Verificar stock de cada producto
    FOR v_item IN SELECT * FROM jsonb_to_recordset(p_productos) AS x(producto_id INT, cantidad INT)
    LOOP
        SELECT * INTO v_stock_suficiente FROM sp_verificar_stock(v_item.producto_id, v_item.cantidad);
        IF v_stock_suficiente = false THEN
            RETURN QUERY SELECT NULL::INT, NULL::VARCHAR, NULL::DECIMAL,
                         'Error: Stock insuficiente para producto ID ' || v_item.producto_id;
            RETURN;
        END IF;
    END LOOP;
    
    -- Crear pedido
    INSERT INTO pedido (cliente_id, ubicacion_id, receptor_id, estado_id)
    VALUES (p_cliente_id, p_ubicacion_id, p_receptor_id, 1) -- estado_id 1 = 'Por entregar'
    RETURNING id INTO v_pedido_id;
    
    -- Agregar productos y calcular total
    FOR v_item IN SELECT * FROM jsonb_to_recordset(p_productos) AS x(producto_id INT, cantidad INT)
    LOOP
        SELECT precio INTO v_precio FROM producto WHERE id = v_item.producto_id;
        v_subtotal := v_precio * v_item.cantidad;
        v_total := v_total + v_subtotal;
        
        INSERT INTO pedido_producto (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
        VALUES (v_pedido_id, v_item.producto_id, v_item.cantidad, v_precio, v_subtotal);
        
        -- Descontar stock
        PERFORM sp_actualizar_stock(v_item.producto_id, v_item.cantidad, 'restar');
    END LOOP;
    
    -- Actualizar total del pedido
    UPDATE pedido SET total = v_total WHERE id = v_pedido_id;
    
    RETURN QUERY SELECT 
        v_pedido_id, 'Por entregar'::VARCHAR, v_total,
        'Pedido creado exitosamente'::VARCHAR;
END;
$$;


ALTER FUNCTION public.sp_crear_pedido(p_cliente_id integer, p_ubicacion_id integer, p_receptor_id integer, p_productos jsonb) OWNER TO postgres;

--
-- TOC entry 273 (class 1255 OID 16920)
-- Name: sp_crear_producto(character varying, numeric, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sp_crear_producto(p_nombre character varying, p_precio numeric, p_descripcion text DEFAULT NULL::text) RETURNS TABLE(id integer, nombre character varying, descripcion text, precio numeric, mensaje character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_producto_id INT;
BEGIN
    IF p_precio < 0 THEN
        RETURN QUERY SELECT NULL::INT, NULL::VARCHAR, NULL::TEXT, NULL::DECIMAL,
                     'Error: El precio no puede ser negativo'::VARCHAR;
        RETURN;
    END IF;
    
    INSERT INTO producto (nombre, descripcion, precio)
    VALUES (p_nombre, p_descripcion, p_precio)
    RETURNING id INTO v_producto_id;
    
    -- Crear registro de stock automáticamente
    INSERT INTO stock (producto_id, cantidad) VALUES (v_producto_id, 0);
    
    RETURN QUERY SELECT 
        v_producto_id, p_nombre, p_descripcion, p_precio,
        'Producto creado exitosamente'::VARCHAR;
END;
$$;


ALTER FUNCTION public.sp_crear_producto(p_nombre character varying, p_precio numeric, p_descripcion text) OWNER TO postgres;

--
-- TOC entry 265 (class 1255 OID 16911)
-- Name: sp_crear_ubicacion(integer, text, text, numeric, numeric, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sp_crear_ubicacion(p_cliente_id integer, p_direccion text, p_referencia text DEFAULT NULL::text, p_lat numeric DEFAULT NULL::numeric, p_lng numeric DEFAULT NULL::numeric, p_predeterminada boolean DEFAULT false) RETURNS TABLE(id integer, cliente_id integer, direccion text, referencia text, lat numeric, lng numeric, predeterminada boolean, mensaje character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_cliente_existe INT;
    v_ubicacion_id INT;
BEGIN
    -- Validar que el cliente existe
    SELECT COUNT(*) INTO v_cliente_existe FROM cliente WHERE id = p_cliente_id AND activo = true;
    IF v_cliente_existe = 0 THEN
        RETURN QUERY SELECT NULL::INT, NULL::INT, NULL::TEXT, NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL, NULL::BOOLEAN,
                     'Error: Cliente no existe o está inactivo'::VARCHAR;
        RETURN;
    END IF;
    
    -- Si es predeterminada, quitar predeterminada de otras ubicaciones del mismo cliente
    IF p_predeterminada = true THEN
        UPDATE ubicacion SET predeterminada = false WHERE cliente_id = p_cliente_id;
    END IF;
    
    INSERT INTO ubicacion (cliente_id, direccion, referencia, lat, lng, predeterminada)
    VALUES (p_cliente_id, p_direccion, p_referencia, p_lat, p_lng, p_predeterminada)
    RETURNING id INTO v_ubicacion_id;
    
    RETURN QUERY SELECT 
        v_ubicacion_id, p_cliente_id, p_direccion, p_referencia, p_lat, p_lng, p_predeterminada,
        'Ubicación creada exitosamente'::VARCHAR;
END;
$$;


ALTER FUNCTION public.sp_crear_ubicacion(p_cliente_id integer, p_direccion text, p_referencia text, p_lat numeric, p_lng numeric, p_predeterminada boolean) OWNER TO postgres;

--
-- TOC entry 278 (class 1255 OID 16925)
-- Name: sp_crear_usuario(character varying, character varying, character varying, integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sp_crear_usuario(p_nombre character varying, p_telefono character varying, p_email character varying, p_rol_id integer, p_contrasena_hash character varying) RETURNS TABLE(usuario_id integer, usuario_nombre character varying, usuario_telefono character varying, usuario_email character varying, usuario_rol_id integer, rol_nombre character varying, mensaje character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_rol_existe INT;
    v_telefono_existe INT;
    v_email_existe INT;
    v_user_id INT;
    v_rol_nombre VARCHAR;
BEGIN
    -- 1. Validar que el rol existe
    SELECT COUNT(*) INTO v_rol_existe FROM rol WHERE id = p_rol_id;
    IF v_rol_existe = 0 THEN
        RETURN QUERY SELECT NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::INT, NULL::VARCHAR, 
                     'Error: El rol no existe'::VARCHAR;
        RETURN;
    END IF;
    
    -- 2. Validar que el teléfono no esté registrado
    SELECT COUNT(*) INTO v_telefono_existe FROM usuario WHERE telefono = p_telefono;
    IF v_telefono_existe > 0 THEN
        RETURN QUERY SELECT NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::INT, NULL::VARCHAR,
                     'Error: El teléfono ya está registrado'::VARCHAR;
        RETURN;
    END IF;
    
    -- 3. Validar email único (si se proporcionó)
    IF p_email IS NOT NULL THEN
        SELECT COUNT(*) INTO v_email_existe FROM usuario WHERE email = p_email;
        IF v_email_existe > 0 THEN
            RETURN QUERY SELECT NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::INT, NULL::VARCHAR,
                         'Error: El email ya está registrado'::VARCHAR;
            RETURN;
        END IF;
    END IF;
    
    -- 4. Insertar usuario
    INSERT INTO usuario (nombre, telefono, email, rol_id, contrasena_hash)
    VALUES (p_nombre, p_telefono, p_email, p_rol_id, p_contrasena_hash)
    RETURNING id INTO v_user_id;
    
    -- 5. Obtener nombre del rol
    SELECT nombre INTO v_rol_nombre FROM rol WHERE id = p_rol_id;
    
    -- 6. Retornar éxito
    RETURN QUERY SELECT 
        v_user_id, 
        p_nombre, 
        p_telefono, 
        p_email, 
        p_rol_id, 
        v_rol_nombre,
        'Usuario creado exitosamente'::VARCHAR;
    
END;
$$;


ALTER FUNCTION public.sp_crear_usuario(p_nombre character varying, p_telefono character varying, p_email character varying, p_rol_id integer, p_contrasena_hash character varying) OWNER TO postgres;

--
-- TOC entry 264 (class 1255 OID 16910)
-- Name: sp_eliminar_cliente(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sp_eliminar_cliente(p_id integer) RETURNS TABLE(success boolean, mensaje character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_cliente_existe INT;
    v_pedidos_activos INT;
BEGIN
    SELECT COUNT(*) INTO v_cliente_existe FROM cliente WHERE id = p_id AND activo = true;
    IF v_cliente_existe = 0 THEN
        RETURN QUERY SELECT FALSE::BOOLEAN, 'Error: Cliente no encontrado o ya eliminado'::VARCHAR;
        RETURN;
    END IF;
    
    -- Verificar pedidos activos
    SELECT COUNT(*) INTO v_pedidos_activos 
    FROM pedido p
    JOIN estado e ON e.id = p.estado_id
    WHERE p.cliente_id = p_id AND e.nombre IN ('Por entregar', 'En camino');
    
    IF v_pedidos_activos > 0 THEN
        RETURN QUERY SELECT FALSE::BOOLEAN, 'Error: Cliente tiene pedidos activos pendientes'::VARCHAR;
        RETURN;
    END IF;
    
    UPDATE cliente SET activo = false WHERE id = p_id;
    RETURN QUERY SELECT TRUE::BOOLEAN, 'Cliente eliminado exitosamente'::VARCHAR;
END;
$$;


ALTER FUNCTION public.sp_eliminar_cliente(p_id integer) OWNER TO postgres;

--
-- TOC entry 266 (class 1255 OID 16913)
-- Name: sp_eliminar_ubicacion(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sp_eliminar_ubicacion(p_id integer) RETURNS TABLE(success boolean, mensaje character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_ubicacion_existe INT;
    v_pedidos_asociados INT;
BEGIN
    SELECT COUNT(*) INTO v_ubicacion_existe FROM ubicacion WHERE id = p_id;
    IF v_ubicacion_existe = 0 THEN
        RETURN QUERY SELECT FALSE::BOOLEAN, 'Error: Ubicación no encontrada'::VARCHAR;
        RETURN;
    END IF;
    
    -- Verificar si tiene pedidos asociados
    SELECT COUNT(*) INTO v_pedidos_asociados FROM pedido WHERE ubicacion_id = p_id;
    IF v_pedidos_asociados > 0 THEN
        RETURN QUERY SELECT FALSE::BOOLEAN, 'Error: Ubicación tiene pedidos asociados'::VARCHAR;
        RETURN;
    END IF;
    
    DELETE FROM ubicacion WHERE id = p_id;
    RETURN QUERY SELECT TRUE::BOOLEAN, 'Ubicación eliminada exitosamente'::VARCHAR;
END;
$$;


ALTER FUNCTION public.sp_eliminar_ubicacion(p_id integer) OWNER TO postgres;

--
-- TOC entry 257 (class 1255 OID 16896)
-- Name: sp_eliminar_usuario(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sp_eliminar_usuario(p_id integer) RETURNS TABLE(success boolean, mensaje character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_usuario_existe INT;
BEGIN
    -- Verificar si existe
    SELECT COUNT(*) INTO v_usuario_existe FROM usuario WHERE id = p_id AND activo = true;
    
    IF v_usuario_existe = 0 THEN
        RETURN QUERY SELECT FALSE::BOOLEAN, 'Error: Usuario no encontrado o ya eliminado'::VARCHAR;
        RETURN;
    END IF;
    
    -- Borrado lógico
    UPDATE usuario SET activo = false WHERE id = p_id;
    
    RETURN QUERY SELECT TRUE::BOOLEAN, 'Usuario eliminado exitosamente'::VARCHAR;
END;
$$;


ALTER FUNCTION public.sp_eliminar_usuario(p_id integer) OWNER TO postgres;

--
-- TOC entry 261 (class 1255 OID 16907)
-- Name: sp_listar_clientes(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sp_listar_clientes() RETURNS TABLE(id integer, nombre character varying, telefono character varying, email character varying, fecha_registro timestamp without time zone, activo boolean, total_pedidos bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT c.id, c.nombre, c.telefono, c.email, c.fecha_registro, c.activo,
           COUNT(p.id) AS total_pedidos
    FROM cliente c
    LEFT JOIN pedido p ON p.cliente_id = c.id
    WHERE c.activo = true
    GROUP BY c.id
    ORDER BY c.id ASC;
END;
$$;


ALTER FUNCTION public.sp_listar_clientes() OWNER TO postgres;

--
-- TOC entry 268 (class 1255 OID 16917)
-- Name: sp_listar_pedidos(integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sp_listar_pedidos(p_piloto_id integer DEFAULT NULL::integer, p_estado_nombre character varying DEFAULT NULL::character varying) RETURNS TABLE(id integer, cliente_nombre character varying, cliente_telefono character varying, ubicacion_direccion text, estado character varying, total numeric, fecha_creacion timestamp without time zone, piloto_nombre character varying, receptor_nombre character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF p_piloto_id IS NOT NULL AND p_estado_nombre IS NOT NULL THEN
        -- Filtrar por piloto y estado
        RETURN QUERY
        SELECT p.id, c.nombre, c.telefono, u.direccion, e.nombre, p.total, p.fecha_creacion,
               pil.nombre, rec.nombre
        FROM pedido p
        JOIN cliente c ON c.id = p.cliente_id
        JOIN ubicacion u ON u.id = p.ubicacion_id
        JOIN estado e ON e.id = p.estado_id
        LEFT JOIN usuario pil ON pil.id = p.piloto_id
        JOIN usuario rec ON rec.id = p.receptor_id
        WHERE p.piloto_id = p_piloto_id AND e.nombre = p_estado_nombre
        ORDER BY p.fecha_creacion ASC;
        
    ELSIF p_piloto_id IS NOT NULL THEN
        -- Filtrar solo por piloto
        RETURN QUERY
        SELECT p.id, c.nombre, c.telefono, u.direccion, e.nombre, p.total, p.fecha_creacion,
               pil.nombre, rec.nombre
        FROM pedido p
        JOIN cliente c ON c.id = p.cliente_id
        JOIN ubicacion u ON u.id = p.ubicacion_id
        JOIN estado e ON e.id = p.estado_id
        LEFT JOIN usuario pil ON pil.id = p.piloto_id
        JOIN usuario rec ON rec.id = p.receptor_id
        WHERE p.piloto_id = p_piloto_id
        ORDER BY p.fecha_creacion ASC;
        
    ELSIF p_estado_nombre IS NOT NULL THEN
        -- Filtrar solo por estado
        RETURN QUERY
        SELECT p.id, c.nombre, c.telefono, u.direccion, e.nombre, p.total, p.fecha_creacion,
               pil.nombre, rec.nombre
        FROM pedido p
        JOIN cliente c ON c.id = p.cliente_id
        JOIN ubicacion u ON u.id = p.ubicacion_id
        JOIN estado e ON e.id = p.estado_id
        LEFT JOIN usuario pil ON pil.id = p.piloto_id
        JOIN usuario rec ON rec.id = p.receptor_id
        WHERE e.nombre = p_estado_nombre
        ORDER BY p.fecha_creacion ASC;
        
    ELSE
        -- Todos los pedidos
        RETURN QUERY
        SELECT p.id, c.nombre, c.telefono, u.direccion, e.nombre, p.total, p.fecha_creacion,
               pil.nombre, rec.nombre
        FROM pedido p
        JOIN cliente c ON c.id = p.cliente_id
        JOIN ubicacion u ON u.id = p.ubicacion_id
        JOIN estado e ON e.id = p.estado_id
        LEFT JOIN usuario pil ON pil.id = p.piloto_id
        JOIN usuario rec ON rec.id = p.receptor_id
        ORDER BY p.fecha_creacion DESC;
    END IF;
END;
$$;


ALTER FUNCTION public.sp_listar_pedidos(p_piloto_id integer, p_estado_nombre character varying) OWNER TO postgres;

--
-- TOC entry 274 (class 1255 OID 16921)
-- Name: sp_listar_productos(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sp_listar_productos() RETURNS TABLE(id integer, nombre character varying, descripcion text, precio numeric, activo boolean, stock_actual integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT p.id, p.nombre, p.descripcion, p.precio, p.activo, COALESCE(s.cantidad, 0) AS stock_actual
    FROM producto p
    LEFT JOIN stock s ON s.producto_id = p.id
    WHERE p.activo = true
    ORDER BY p.id ASC;
END;
$$;


ALTER FUNCTION public.sp_listar_productos() OWNER TO postgres;

--
-- TOC entry 259 (class 1255 OID 16912)
-- Name: sp_listar_ubicaciones(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sp_listar_ubicaciones(p_cliente_id integer DEFAULT NULL::integer) RETURNS TABLE(id integer, cliente_id integer, cliente_nombre character varying, direccion text, referencia text, lat numeric, lng numeric, predeterminada boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF p_cliente_id IS NULL THEN
        RETURN QUERY
        SELECT u.id, u.cliente_id, c.nombre, u.direccion, u.referencia, u.lat, u.lng, u.predeterminada
        FROM ubicacion u
        JOIN cliente c ON c.id = u.cliente_id
        WHERE c.activo = true
        ORDER BY u.cliente_id, u.predeterminada DESC;
    ELSE
        RETURN QUERY
        SELECT u.id, u.cliente_id, c.nombre, u.direccion, u.referencia, u.lat, u.lng, u.predeterminada
        FROM ubicacion u
        JOIN cliente c ON c.id = u.cliente_id
        WHERE u.cliente_id = p_cliente_id AND c.activo = true
        ORDER BY u.predeterminada DESC;
    END IF;
END;
$$;


ALTER FUNCTION public.sp_listar_ubicaciones(p_cliente_id integer) OWNER TO postgres;

--
-- TOC entry 277 (class 1255 OID 16924)
-- Name: sp_listar_usuarios(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sp_listar_usuarios() RETURNS TABLE(usuario_id integer, usuario_nombre character varying, usuario_telefono character varying, usuario_email character varying, usuario_rol_id integer, rol_nombre character varying, fecha_creacion timestamp without time zone, activo boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT u.id, u.nombre, u.telefono, u.email, 
           u.rol_id, r.nombre, u.fecha_creacion, u.activo
    FROM usuario u
    JOIN rol r ON r.id = u.rol_id
    WHERE u.activo = true
    ORDER BY u.id ASC;
END;
$$;


ALTER FUNCTION public.sp_listar_usuarios() OWNER TO postgres;

--
-- TOC entry 258 (class 1255 OID 16897)
-- Name: sp_login_usuario(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sp_login_usuario(p_telefono character varying, p_contrasena_plana character varying) RETURNS TABLE(id integer, nombre character varying, telefono character varying, email character varying, rol_id integer, rol_nombre character varying, contrasena_hash character varying, es_valido boolean, mensaje character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_usuario RECORD;
BEGIN
    -- Buscar usuario por teléfono
    SELECT u.id, u.nombre, u.telefono, u.email, u.rol_id, u.contrasena_hash, r.nombre as rol_nombre
    INTO v_usuario
    FROM usuario u
    JOIN rol r ON r.id = u.rol_id
    WHERE u.telefono = p_telefono AND u.activo = true;
    
    IF v_usuario.id IS NULL THEN
        RETURN QUERY SELECT NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, 
                     NULL::INT, NULL::VARCHAR, NULL::VARCHAR, FALSE::BOOLEAN, 
                     'Usuario no encontrado'::VARCHAR;
        RETURN;
    END IF;
    
    -- Retornar datos (la validación de contraseña se hará en Node.js con bcrypt)
    RETURN QUERY SELECT 
        v_usuario.id, v_usuario.nombre, v_usuario.telefono, v_usuario.email,
        v_usuario.rol_id, v_usuario.rol_nombre, v_usuario.contrasena_hash,
        TRUE::BOOLEAN, 'Usuario encontrado'::VARCHAR;
        
END;
$$;


ALTER FUNCTION public.sp_login_usuario(p_telefono character varying, p_contrasena_plana character varying) OWNER TO postgres;

--
-- TOC entry 262 (class 1255 OID 16908)
-- Name: sp_obtener_cliente(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sp_obtener_cliente(p_id integer) RETURNS TABLE(id integer, nombre character varying, telefono character varying, email character varying, fecha_registro timestamp without time zone, activo boolean, existe boolean)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_existe BOOLEAN;
BEGIN
    SELECT EXISTS(SELECT 1 FROM cliente WHERE id = p_id) INTO v_existe;
    
    IF v_existe THEN
        RETURN QUERY
        SELECT c.id, c.nombre, c.telefono, c.email, c.fecha_registro, c.activo, TRUE::BOOLEAN
        FROM cliente c
        WHERE c.id = p_id;
    ELSE
        RETURN QUERY SELECT NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, 
                     NULL::TIMESTAMP, NULL::BOOLEAN, FALSE::BOOLEAN;
    END IF;
END;
$$;


ALTER FUNCTION public.sp_obtener_cliente(p_id integer) OWNER TO postgres;

--
-- TOC entry 276 (class 1255 OID 16923)
-- Name: sp_obtener_usuario(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sp_obtener_usuario(p_id integer) RETURNS TABLE(usuario_id integer, usuario_nombre character varying, usuario_telefono character varying, usuario_email character varying, usuario_rol_id integer, rol_nombre character varying, fecha_creacion timestamp without time zone, activo boolean, existe boolean)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_existe BOOLEAN;
BEGIN
    SELECT EXISTS(SELECT 1 FROM usuario WHERE id = p_id) INTO v_existe;
    
    IF v_existe THEN
        RETURN QUERY
        SELECT u.id, u.nombre, u.telefono, u.email, 
               u.rol_id, r.nombre, u.fecha_creacion, u.activo,
               TRUE::BOOLEAN
        FROM usuario u
        JOIN rol r ON r.id = u.rol_id
        WHERE u.id = p_id;
    ELSE
        RETURN QUERY SELECT NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, 
                     NULL::INT, NULL::VARCHAR, NULL::TIMESTAMP, NULL::BOOLEAN, FALSE::BOOLEAN;
    END IF;
END;
$$;


ALTER FUNCTION public.sp_obtener_usuario(p_id integer) OWNER TO postgres;

--
-- TOC entry 270 (class 1255 OID 16919)
-- Name: sp_reportar_entrega(integer, boolean, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sp_reportar_entrega(p_pedido_id integer, p_entregado boolean, p_motivo text DEFAULT NULL::text) RETURNS TABLE(success boolean, mensaje character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_pedido_existe INT;
    v_estado_actual VARCHAR;
BEGIN
    -- Verificar pedido existe
    SELECT COUNT(*), e.nombre INTO v_pedido_existe, v_estado_actual
    FROM pedido p
    JOIN estado e ON e.id = p.estado_id
    WHERE p.id = p_pedido_id
    GROUP BY e.nombre;
    
    IF v_pedido_existe = 0 THEN
        RETURN QUERY SELECT FALSE::BOOLEAN, 'Error: Pedido no encontrado'::VARCHAR;
        RETURN;
    END IF;
    
    IF v_estado_actual != 'En camino' THEN
        RETURN QUERY SELECT FALSE::BOOLEAN, 'Error: El pedido no está en estado "En camino"'::VARCHAR;
        RETURN;
    END IF;
    
    IF p_entregado THEN
        UPDATE pedido 
        SET estado_id = 3, -- 'Entregado'
            fecha_entrega = CURRENT_TIMESTAMP
        WHERE id = p_pedido_id;
        
        RETURN QUERY SELECT TRUE::BOOLEAN, 'Entrega registrada exitosamente'::VARCHAR;
    ELSE
        IF p_motivo IS NULL OR p_motivo = '' THEN
            RETURN QUERY SELECT FALSE::BOOLEAN, 'Error: Debe proporcionar motivo de no entrega'::VARCHAR;
            RETURN;
        END IF;
        
        UPDATE pedido 
        SET estado_id = 4, -- 'No entregado'
            motivo_no_entrega = p_motivo
        WHERE id = p_pedido_id;
        
        RETURN QUERY SELECT TRUE::BOOLEAN, 'No entrega registrada exitosamente'::VARCHAR;
    END IF;
END;
$$;


ALTER FUNCTION public.sp_reportar_entrega(p_pedido_id integer, p_entregado boolean, p_motivo text) OWNER TO postgres;

--
-- TOC entry 272 (class 1255 OID 16915)
-- Name: sp_verificar_stock(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sp_verificar_stock(p_producto_id integer, p_cantidad_deseada integer) RETURNS TABLE(disponible boolean, stock_actual integer, mensaje character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_stock_actual INT;
BEGIN
    SELECT cantidad INTO v_stock_actual FROM stock WHERE producto_id = p_producto_id;
    
    IF v_stock_actual IS NULL THEN
        RETURN QUERY SELECT FALSE::BOOLEAN, NULL::INT,
                     'Error: Producto no tiene registro de stock'::VARCHAR;
        RETURN;
    END IF;
    
    IF v_stock_actual >= p_cantidad_deseada THEN
        RETURN QUERY SELECT TRUE::BOOLEAN, v_stock_actual,
                     'Stock disponible'::VARCHAR;
    ELSE
        RETURN QUERY SELECT FALSE::BOOLEAN, v_stock_actual,
                     'Stock insuficiente. Disponible: ' || v_stock_actual || ', Requerido: ' || p_cantidad_deseada;
    END IF;
END;
$$;


ALTER FUNCTION public.sp_verificar_stock(p_producto_id integer, p_cantidad_deseada integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 224 (class 1259 OID 16676)
-- Name: cliente; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cliente (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    telefono character varying(20) NOT NULL,
    email character varying(100),
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    activo boolean DEFAULT true
);


ALTER TABLE public.cliente OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 16675)
-- Name: cliente_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cliente_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cliente_id_seq OWNER TO postgres;

--
-- TOC entry 5188 (class 0 OID 0)
-- Dependencies: 223
-- Name: cliente_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cliente_id_seq OWNED BY public.cliente.id;


--
-- TOC entry 234 (class 1259 OID 16757)
-- Name: pedido; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pedido (
    id integer NOT NULL,
    cliente_id integer NOT NULL,
    ubicacion_id integer NOT NULL,
    receptor_id integer NOT NULL,
    piloto_id integer,
    estado_id integer DEFAULT 1 NOT NULL,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_asignacion timestamp without time zone,
    fecha_entrega timestamp without time zone,
    motivo_no_entrega text,
    total numeric(10,2) DEFAULT 0,
    CONSTRAINT chk_motivo_no_entrega CHECK (((estado_id <> 4) OR ((estado_id = 4) AND (motivo_no_entrega IS NOT NULL) AND (motivo_no_entrega <> ''::text))))
);


ALTER TABLE public.pedido OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 16690)
-- Name: ubicacion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ubicacion (
    id integer NOT NULL,
    cliente_id integer NOT NULL,
    lat numeric(10,8),
    lng numeric(11,8),
    direccion text NOT NULL,
    referencia text,
    predeterminada boolean DEFAULT false,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.ubicacion OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 16654)
-- Name: usuario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuario (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    telefono character varying(20) NOT NULL,
    email character varying(100),
    rol_id integer NOT NULL,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    activo boolean DEFAULT true,
    contrasena_hash character varying(255) DEFAULT ''::character varying NOT NULL
);


ALTER TABLE public.usuario OWNER TO postgres;

--
-- TOC entry 239 (class 1259 OID 16879)
-- Name: entregas_piloto; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.entregas_piloto AS
 SELECT p.id,
    u.nombre AS piloto,
    c.nombre AS cliente,
    c.telefono,
    ub.direccion,
    p.fecha_asignacion
   FROM (((public.pedido p
     JOIN public.usuario u ON ((u.id = p.piloto_id)))
     JOIN public.cliente c ON ((c.id = p.cliente_id)))
     JOIN public.ubicacion ub ON ((ub.id = p.ubicacion_id)))
  WHERE (p.estado_id = ANY (ARRAY[1, 2]));


ALTER VIEW public.entregas_piloto OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 16709)
-- Name: estado; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.estado (
    id integer NOT NULL,
    nombre character varying(20) NOT NULL,
    CONSTRAINT estado_nombre_check CHECK (((nombre)::text = ANY ((ARRAY['Por entregar'::character varying, 'En camino'::character varying, 'Entregado'::character varying, 'No entregado'::character varying])::text[])))
);


ALTER TABLE public.estado OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 16708)
-- Name: estado_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.estado_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.estado_id_seq OWNER TO postgres;

--
-- TOC entry 5189 (class 0 OID 0)
-- Dependencies: 227
-- Name: estado_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.estado_id_seq OWNED BY public.estado.id;


--
-- TOC entry 237 (class 1259 OID 16821)
-- Name: log_entrega; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.log_entrega (
    id integer NOT NULL,
    pedido_id integer NOT NULL,
    estado_anterior_id integer NOT NULL,
    estado_nuevo_id integer NOT NULL,
    usuario_id integer NOT NULL,
    comentario text,
    fecha_cambio timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.log_entrega OWNER TO postgres;

--
-- TOC entry 236 (class 1259 OID 16820)
-- Name: log_entrega_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.log_entrega_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.log_entrega_id_seq OWNER TO postgres;

--
-- TOC entry 5190 (class 0 OID 0)
-- Dependencies: 236
-- Name: log_entrega_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.log_entrega_id_seq OWNED BY public.log_entrega.id;


--
-- TOC entry 233 (class 1259 OID 16756)
-- Name: pedido_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pedido_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pedido_id_seq OWNER TO postgres;

--
-- TOC entry 5191 (class 0 OID 0)
-- Dependencies: 233
-- Name: pedido_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pedido_id_seq OWNED BY public.pedido.id;


--
-- TOC entry 235 (class 1259 OID 16799)
-- Name: pedido_producto; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pedido_producto (
    pedido_id integer NOT NULL,
    producto_id integer NOT NULL,
    cantidad integer NOT NULL,
    precio_unitario numeric(10,2) NOT NULL,
    subtotal numeric(10,2) NOT NULL,
    CONSTRAINT pedido_producto_cantidad_check CHECK ((cantidad > 0))
);


ALTER TABLE public.pedido_producto OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 16874)
-- Name: pedidos_pendientes; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.pedidos_pendientes AS
 SELECT p.id,
    c.nombre AS cliente,
    c.telefono,
    u.nombre AS receptor,
    p.fecha_creacion
   FROM ((public.pedido p
     JOIN public.cliente c ON ((c.id = p.cliente_id)))
     JOIN public.usuario u ON ((u.id = p.receptor_id)))
  WHERE ((p.piloto_id IS NULL) AND (p.estado_id = 1));


ALTER VIEW public.pedidos_pendientes OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 16721)
-- Name: producto; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.producto (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion text,
    precio numeric(10,2) NOT NULL,
    activo boolean DEFAULT true,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT producto_precio_check CHECK ((precio >= (0)::numeric))
);


ALTER TABLE public.producto OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 16720)
-- Name: producto_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.producto_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.producto_id_seq OWNER TO postgres;

--
-- TOC entry 5192 (class 0 OID 0)
-- Dependencies: 229
-- Name: producto_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.producto_id_seq OWNED BY public.producto.id;


--
-- TOC entry 240 (class 1259 OID 16884)
-- Name: reporte_entregas_diarias; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.reporte_entregas_diarias AS
 SELECT date(fecha_entrega) AS dia,
    count(*) AS total_entregas,
    sum(total) AS monto_total
   FROM public.pedido
  WHERE ((estado_id = 3) AND (fecha_entrega IS NOT NULL))
  GROUP BY (date(fecha_entrega))
  ORDER BY (date(fecha_entrega)) DESC;


ALTER VIEW public.reporte_entregas_diarias OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 16642)
-- Name: rol; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rol (
    id integer NOT NULL,
    nombre character varying(20) NOT NULL,
    CONSTRAINT rol_nombre_check CHECK (((nombre)::text = ANY ((ARRAY['Receptor'::character varying, 'Piloto'::character varying, 'Admin'::character varying])::text[])))
);


ALTER TABLE public.rol OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 16641)
-- Name: rol_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.rol_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.rol_id_seq OWNER TO postgres;

--
-- TOC entry 5193 (class 0 OID 0)
-- Dependencies: 219
-- Name: rol_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.rol_id_seq OWNED BY public.rol.id;


--
-- TOC entry 232 (class 1259 OID 16736)
-- Name: stock; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stock (
    id integer NOT NULL,
    producto_id integer NOT NULL,
    cantidad integer DEFAULT 0 NOT NULL,
    stock_minimo integer DEFAULT 0,
    ultima_actualizacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT stock_cantidad_check CHECK ((cantidad >= 0))
);


ALTER TABLE public.stock OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 16735)
-- Name: stock_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.stock_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.stock_id_seq OWNER TO postgres;

--
-- TOC entry 5194 (class 0 OID 0)
-- Dependencies: 231
-- Name: stock_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stock_id_seq OWNED BY public.stock.id;


--
-- TOC entry 225 (class 1259 OID 16689)
-- Name: ubicacion_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ubicacion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ubicacion_id_seq OWNER TO postgres;

--
-- TOC entry 5195 (class 0 OID 0)
-- Dependencies: 225
-- Name: ubicacion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ubicacion_id_seq OWNED BY public.ubicacion.id;


--
-- TOC entry 221 (class 1259 OID 16653)
-- Name: usuario_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.usuario_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.usuario_id_seq OWNER TO postgres;

--
-- TOC entry 5196 (class 0 OID 0)
-- Dependencies: 221
-- Name: usuario_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.usuario_id_seq OWNED BY public.usuario.id;


--
-- TOC entry 4945 (class 2604 OID 16679)
-- Name: cliente id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cliente ALTER COLUMN id SET DEFAULT nextval('public.cliente_id_seq'::regclass);


--
-- TOC entry 4951 (class 2604 OID 16712)
-- Name: estado id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estado ALTER COLUMN id SET DEFAULT nextval('public.estado_id_seq'::regclass);


--
-- TOC entry 4963 (class 2604 OID 16824)
-- Name: log_entrega id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.log_entrega ALTER COLUMN id SET DEFAULT nextval('public.log_entrega_id_seq'::regclass);


--
-- TOC entry 4959 (class 2604 OID 16760)
-- Name: pedido id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pedido ALTER COLUMN id SET DEFAULT nextval('public.pedido_id_seq'::regclass);


--
-- TOC entry 4952 (class 2604 OID 16724)
-- Name: producto id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.producto ALTER COLUMN id SET DEFAULT nextval('public.producto_id_seq'::regclass);


--
-- TOC entry 4940 (class 2604 OID 16645)
-- Name: rol id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rol ALTER COLUMN id SET DEFAULT nextval('public.rol_id_seq'::regclass);


--
-- TOC entry 4955 (class 2604 OID 16739)
-- Name: stock id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stock ALTER COLUMN id SET DEFAULT nextval('public.stock_id_seq'::regclass);


--
-- TOC entry 4948 (class 2604 OID 16693)
-- Name: ubicacion id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ubicacion ALTER COLUMN id SET DEFAULT nextval('public.ubicacion_id_seq'::regclass);


--
-- TOC entry 4941 (class 2604 OID 16657)
-- Name: usuario id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario ALTER COLUMN id SET DEFAULT nextval('public.usuario_id_seq'::regclass);


--
-- TOC entry 4984 (class 2606 OID 16686)
-- Name: cliente cliente_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cliente
    ADD CONSTRAINT cliente_pkey PRIMARY KEY (id);


--
-- TOC entry 4986 (class 2606 OID 16688)
-- Name: cliente cliente_telefono_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cliente
    ADD CONSTRAINT cliente_telefono_key UNIQUE (telefono);


--
-- TOC entry 4992 (class 2606 OID 16719)
-- Name: estado estado_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estado
    ADD CONSTRAINT estado_nombre_key UNIQUE (nombre);


--
-- TOC entry 4994 (class 2606 OID 16717)
-- Name: estado estado_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estado
    ADD CONSTRAINT estado_pkey PRIMARY KEY (id);


--
-- TOC entry 5015 (class 2606 OID 16834)
-- Name: log_entrega log_entrega_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.log_entrega
    ADD CONSTRAINT log_entrega_pkey PRIMARY KEY (id);


--
-- TOC entry 5008 (class 2606 OID 16773)
-- Name: pedido pedido_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pedido
    ADD CONSTRAINT pedido_pkey PRIMARY KEY (id);


--
-- TOC entry 5011 (class 2606 OID 16809)
-- Name: pedido_producto pedido_producto_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pedido_producto
    ADD CONSTRAINT pedido_producto_pkey PRIMARY KEY (pedido_id, producto_id);


--
-- TOC entry 4996 (class 2606 OID 16734)
-- Name: producto producto_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.producto
    ADD CONSTRAINT producto_pkey PRIMARY KEY (id);


--
-- TOC entry 4972 (class 2606 OID 16652)
-- Name: rol rol_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rol
    ADD CONSTRAINT rol_nombre_key UNIQUE (nombre);


--
-- TOC entry 4974 (class 2606 OID 16650)
-- Name: rol rol_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rol
    ADD CONSTRAINT rol_pkey PRIMARY KEY (id);


--
-- TOC entry 4999 (class 2606 OID 16748)
-- Name: stock stock_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stock
    ADD CONSTRAINT stock_pkey PRIMARY KEY (id);


--
-- TOC entry 5001 (class 2606 OID 16750)
-- Name: stock stock_producto_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stock
    ADD CONSTRAINT stock_producto_id_key UNIQUE (producto_id);


--
-- TOC entry 4990 (class 2606 OID 16702)
-- Name: ubicacion ubicacion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ubicacion
    ADD CONSTRAINT ubicacion_pkey PRIMARY KEY (id);


--
-- TOC entry 4978 (class 2606 OID 16669)
-- Name: usuario usuario_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_email_key UNIQUE (email);


--
-- TOC entry 4980 (class 2606 OID 16665)
-- Name: usuario usuario_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_pkey PRIMARY KEY (id);


--
-- TOC entry 4982 (class 2606 OID 16667)
-- Name: usuario usuario_telefono_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_telefono_key UNIQUE (telefono);


--
-- TOC entry 4987 (class 1259 OID 16857)
-- Name: idx_cliente_telefono; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cliente_telefono ON public.cliente USING btree (telefono);


--
-- TOC entry 5012 (class 1259 OID 16867)
-- Name: idx_log_fecha; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_log_fecha ON public.log_entrega USING btree (fecha_cambio);


--
-- TOC entry 5013 (class 1259 OID 16866)
-- Name: idx_log_pedido; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_log_pedido ON public.log_entrega USING btree (pedido_id);


--
-- TOC entry 5002 (class 1259 OID 16859)
-- Name: idx_pedido_cliente; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pedido_cliente ON public.pedido USING btree (cliente_id);


--
-- TOC entry 5003 (class 1259 OID 16861)
-- Name: idx_pedido_estado; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pedido_estado ON public.pedido USING btree (estado_id);


--
-- TOC entry 5004 (class 1259 OID 16862)
-- Name: idx_pedido_fecha; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pedido_fecha ON public.pedido USING btree (fecha_creacion);


--
-- TOC entry 5005 (class 1259 OID 16860)
-- Name: idx_pedido_piloto; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pedido_piloto ON public.pedido USING btree (piloto_id);


--
-- TOC entry 5006 (class 1259 OID 16863)
-- Name: idx_pedido_piloto_estado; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pedido_piloto_estado ON public.pedido USING btree (piloto_id, estado_id);


--
-- TOC entry 5009 (class 1259 OID 16865)
-- Name: idx_pedido_producto_pedido; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pedido_producto_pedido ON public.pedido_producto USING btree (pedido_id);


--
-- TOC entry 4997 (class 1259 OID 16864)
-- Name: idx_stock_producto; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_stock_producto ON public.stock USING btree (producto_id);


--
-- TOC entry 4988 (class 1259 OID 16858)
-- Name: idx_ubicacion_cliente; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ubicacion_cliente ON public.ubicacion USING btree (cliente_id);


--
-- TOC entry 4975 (class 1259 OID 16855)
-- Name: idx_usuario_rol; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_usuario_rol ON public.usuario USING btree (rol_id);


--
-- TOC entry 4976 (class 1259 OID 16856)
-- Name: idx_usuario_telefono; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_usuario_telefono ON public.usuario USING btree (telefono);


--
-- TOC entry 5031 (class 2620 OID 16869)
-- Name: pedido_producto trigger_actualizar_stock; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_actualizar_stock AFTER INSERT ON public.pedido_producto FOR EACH ROW EXECUTE FUNCTION public.actualizar_stock();


--
-- TOC entry 5032 (class 2620 OID 16873)
-- Name: pedido_producto trigger_actualizar_total; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_actualizar_total AFTER INSERT OR DELETE OR UPDATE ON public.pedido_producto FOR EACH ROW EXECUTE FUNCTION public.actualizar_total_pedido();


--
-- TOC entry 5030 (class 2620 OID 16871)
-- Name: pedido trigger_log_estado; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_log_estado AFTER UPDATE OF estado_id ON public.pedido FOR EACH ROW EXECUTE FUNCTION public.registrar_log_estado();


--
-- TOC entry 5026 (class 2606 OID 16840)
-- Name: log_entrega fk_log_estado_anterior; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.log_entrega
    ADD CONSTRAINT fk_log_estado_anterior FOREIGN KEY (estado_anterior_id) REFERENCES public.estado(id);


--
-- TOC entry 5027 (class 2606 OID 16845)
-- Name: log_entrega fk_log_estado_nuevo; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.log_entrega
    ADD CONSTRAINT fk_log_estado_nuevo FOREIGN KEY (estado_nuevo_id) REFERENCES public.estado(id);


--
-- TOC entry 5028 (class 2606 OID 16835)
-- Name: log_entrega fk_log_pedido; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.log_entrega
    ADD CONSTRAINT fk_log_pedido FOREIGN KEY (pedido_id) REFERENCES public.pedido(id) ON DELETE CASCADE;


--
-- TOC entry 5029 (class 2606 OID 16850)
-- Name: log_entrega fk_log_usuario; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.log_entrega
    ADD CONSTRAINT fk_log_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);


--
-- TOC entry 5019 (class 2606 OID 16774)
-- Name: pedido fk_pedido_cliente; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pedido
    ADD CONSTRAINT fk_pedido_cliente FOREIGN KEY (cliente_id) REFERENCES public.cliente(id);


--
-- TOC entry 5020 (class 2606 OID 16794)
-- Name: pedido fk_pedido_estado; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pedido
    ADD CONSTRAINT fk_pedido_estado FOREIGN KEY (estado_id) REFERENCES public.estado(id);


--
-- TOC entry 5021 (class 2606 OID 16789)
-- Name: pedido fk_pedido_piloto; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pedido
    ADD CONSTRAINT fk_pedido_piloto FOREIGN KEY (piloto_id) REFERENCES public.usuario(id);


--
-- TOC entry 5022 (class 2606 OID 16784)
-- Name: pedido fk_pedido_receptor; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pedido
    ADD CONSTRAINT fk_pedido_receptor FOREIGN KEY (receptor_id) REFERENCES public.usuario(id);


--
-- TOC entry 5023 (class 2606 OID 16779)
-- Name: pedido fk_pedido_ubicacion; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pedido
    ADD CONSTRAINT fk_pedido_ubicacion FOREIGN KEY (ubicacion_id) REFERENCES public.ubicacion(id);


--
-- TOC entry 5024 (class 2606 OID 16810)
-- Name: pedido_producto fk_pp_pedido; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pedido_producto
    ADD CONSTRAINT fk_pp_pedido FOREIGN KEY (pedido_id) REFERENCES public.pedido(id) ON DELETE CASCADE;


--
-- TOC entry 5025 (class 2606 OID 16815)
-- Name: pedido_producto fk_pp_producto; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pedido_producto
    ADD CONSTRAINT fk_pp_producto FOREIGN KEY (producto_id) REFERENCES public.producto(id);


--
-- TOC entry 5018 (class 2606 OID 16751)
-- Name: stock fk_stock_producto; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stock
    ADD CONSTRAINT fk_stock_producto FOREIGN KEY (producto_id) REFERENCES public.producto(id) ON DELETE CASCADE;


--
-- TOC entry 5017 (class 2606 OID 16703)
-- Name: ubicacion fk_ubicacion_cliente; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ubicacion
    ADD CONSTRAINT fk_ubicacion_cliente FOREIGN KEY (cliente_id) REFERENCES public.cliente(id) ON DELETE CASCADE;


--
-- TOC entry 5016 (class 2606 OID 16670)
-- Name: usuario fk_usuario_rol; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT fk_usuario_rol FOREIGN KEY (rol_id) REFERENCES public.rol(id);


-- Completed on 2026-04-24 00:25:44

--
-- PostgreSQL database dump complete
--

\unrestrict sfdPigVbMJQqglariw5cAhs0eHVHcOAAbxF9dYvVirMPJphBamNgxCHaGUCGlsn

