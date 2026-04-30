-- ==============================================================================
-- 1. CREACION DE TABLAS Y ESTRUCTURA (SCHEMA)
-- ==============================================================================

DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

CREATE TABLE rol (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE usuario (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    telefono VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    contrasena_hash VARCHAR(255) NOT NULL,
    rol_id INT REFERENCES rol(id),
    activo BOOLEAN DEFAULT true,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE cliente (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    telefono VARCHAR(20) NOT NULL,
    email VARCHAR(100),
    nit_dpi VARCHAR(20),
    fecha_cumpleanos DATE,
    activo BOOLEAN DEFAULT true,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE ubicacion (
    id SERIAL PRIMARY KEY,
    cliente_id INT REFERENCES cliente(id),
    lat DECIMAL(10, 8),
    lng DECIMAL(11, 8),
    direccion TEXT NOT NULL,
    referencia TEXT,
    predeterminada BOOLEAN DEFAULT false,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE producto (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    precio DECIMAL(10, 2) NOT NULL,
    activo BOOLEAN DEFAULT true,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE stock (
    id SERIAL PRIMARY KEY,
    producto_id INT REFERENCES producto(id),
    cantidad INT DEFAULT 0,
    stock_minimo INT DEFAULT 0,
    ultima_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE estado (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE forma_pago (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE expendio (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE pedido (
    id SERIAL PRIMARY KEY,
    cliente_id INT REFERENCES cliente(id),
    ubicacion_id INT REFERENCES ubicacion(id),
    receptor_id INT REFERENCES usuario(id),
    piloto_id INT REFERENCES usuario(id),
    forma_pago_id INT REFERENCES forma_pago(id),
    expendio_id INT REFERENCES expendio(id),
    estado_id INT REFERENCES estado(id),
    descuento DECIMAL(10,2) DEFAULT 0,
    total DECIMAL(10, 2) DEFAULT 0,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_asignacion TIMESTAMP,
    fecha_entrega TIMESTAMP,
    motivo_no_entrega TEXT
);

CREATE TABLE pedido_producto (
    id SERIAL PRIMARY KEY,
    pedido_id INT REFERENCES pedido(id),
    producto_id INT REFERENCES producto(id),
    cantidad INT NOT NULL,
    precio_unitario DECIMAL(10, 2) NOT NULL,
    subtotal DECIMAL(10, 2) NOT NULL
);

CREATE TABLE log_entrega (
    id SERIAL PRIMARY KEY,
    pedido_id INT REFERENCES pedido(id),
    estado_anterior_id INT REFERENCES estado(id),
    estado_nuevo_id INT REFERENCES estado(id),
    usuario_id INT REFERENCES usuario(id),
    fecha_cambio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    comentario TEXT
);


-- ==============================================================================
-- 2. POBLAMIENTO DE CATÁLOGOS BASE Y ADMIN
-- ==============================================================================

INSERT INTO rol (id, nombre) VALUES (1, 'Admin'), (2, 'Piloto'), (3, 'Receptor');

INSERT INTO estado (id, nombre) VALUES 
(1, 'Asignacion de pedido a repartidor'),
(2, 'Repartidor en camino'),
(3, 'Entregado'),
(4, 'Finalizado cliente satisfecho');

INSERT INTO forma_pago (id, nombre) VALUES 
(1, 'Efectivo'), (2, 'Transferencia'), (3, 'POS Tarjeta'), 
(4, 'Cheque'), (5, 'Donacion'), (6, 'Vale'), (7, 'Otros');

INSERT INTO expendio (id, nombre) VALUES (1, 'Barcenas'), (2, 'San Cristobal');

-- Admin por defecto (Pass: admin123)
INSERT INTO usuario (nombre, telefono, email, rol_id, contrasena_hash) 
VALUES ('Administrador', '00000000', 'admin@entregas.com', 1, '$2b$10$Uo9v/pM3J./Yw2R3tA2lP.E7bH2r0/g7Qh6hG5tT8yI1y5uV7d.eS');


-- ==============================================================================
-- 3. PROCESOS ALMACENADOS (Stored Procedures)
-- ==============================================================================

CREATE OR REPLACE FUNCTION sp_listar_pilotos() 
RETURNS TABLE (id INT, nombre VARCHAR, telefono VARCHAR, email VARCHAR) AS $$
BEGIN
    RETURN QUERY SELECT u.id, u.nombre, u.telefono, u.email FROM usuario u WHERE u.rol_id = 2 AND u.activo = true ORDER BY u.nombre ASC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_crear_usuario(
    p_nombre VARCHAR, p_telefono VARCHAR, p_email VARCHAR, p_rol_id INT, p_contrasena_hash VARCHAR
) RETURNS TABLE (usuario_id INT, usuario_nombre VARCHAR, usuario_telefono VARCHAR, usuario_email VARCHAR, usuario_rol_id INT, rol_nombre VARCHAR, mensaje TEXT) AS $$
DECLARE
    v_rol_nombre VARCHAR; v_id INT;
BEGIN
    SELECT r.nombre INTO v_rol_nombre FROM rol r WHERE r.id = p_rol_id;
    INSERT INTO usuario (nombre, telefono, email, rol_id, contrasena_hash) VALUES (p_nombre, p_telefono, p_email, p_rol_id, p_contrasena_hash) RETURNING usuario.id INTO v_id;
    RETURN QUERY SELECT v_id, p_nombre, p_telefono, p_email, p_rol_id, v_rol_nombre, 'Usuario creado exitosamente'::TEXT;
EXCEPTION WHEN unique_violation THEN
    RETURN QUERY SELECT NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::INT, NULL::VARCHAR, 'Error: El telefono o email ya existe'::TEXT;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_crear_cliente(
    p_nombre VARCHAR, p_telefono VARCHAR, p_email VARCHAR, p_nit_dpi VARCHAR, p_fecha_cumpleanos DATE
) RETURNS TABLE (id INT, nombre VARCHAR, telefono VARCHAR, email VARCHAR, fecha_registro TIMESTAMP, activo BOOLEAN) AS $$
BEGIN
    RETURN QUERY INSERT INTO cliente (nombre, telefono, email, nit_dpi, fecha_cumpleanos) VALUES (p_nombre, p_telefono, p_email, p_nit_dpi, p_fecha_cumpleanos) RETURNING cliente.id, cliente.nombre, cliente.telefono, cliente.email, cliente.fecha_registro, cliente.activo;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_crear_ubicacion(
    p_cliente_id INT, p_lat DECIMAL, p_lng DECIMAL, p_direccion TEXT, p_referencia TEXT, p_predeterminada BOOLEAN
) RETURNS TABLE (id INT, cliente_id INT, lat DECIMAL, lng DECIMAL, direccion TEXT, referencia TEXT, predeterminada BOOLEAN, fecha_creacion TIMESTAMP) AS $$
BEGIN
    IF p_predeterminada THEN UPDATE ubicacion SET predeterminada = false WHERE ubicacion.cliente_id = p_cliente_id; END IF;
    RETURN QUERY INSERT INTO ubicacion (cliente_id, lat, lng, direccion, referencia, predeterminada) VALUES (p_cliente_id, p_lat, p_lng, p_direccion, p_referencia, COALESCE(p_predeterminada, false)) RETURNING ubicacion.id, ubicacion.cliente_id, ubicacion.lat, ubicacion.lng, ubicacion.direccion, ubicacion.referencia, ubicacion.predeterminada, ubicacion.fecha_creacion;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_crear_producto(
    p_nombre VARCHAR, p_descripcion TEXT, p_precio DECIMAL, p_stock_inicial INT, p_stock_minimo INT
) RETURNS TABLE (id INT, nombre VARCHAR, descripcion TEXT, precio DECIMAL, activo BOOLEAN, fecha_creacion TIMESTAMP) AS $$
DECLARE v_producto_id INT;
BEGIN
    INSERT INTO producto (nombre, descripcion, precio) VALUES (p_nombre, p_descripcion, p_precio) RETURNING producto.id INTO v_producto_id;
    INSERT INTO stock (producto_id, cantidad, stock_minimo) VALUES (v_producto_id, COALESCE(p_stock_inicial, 0), COALESCE(p_stock_minimo, 0));
    RETURN QUERY SELECT p.id, p.nombre, p.descripcion, p.precio, p.activo, p.fecha_creacion FROM producto p WHERE p.id = v_producto_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_crear_pedido(
    p_cliente_id INT, p_ubicacion_id INT, p_receptor_id INT, p_forma_pago_id INT, p_expendio_id INT, p_descuento DECIMAL
) RETURNS TABLE (id INT, fecha_creacion TIMESTAMP, estado_id INT) AS $$
BEGIN
    RETURN QUERY INSERT INTO pedido (cliente_id, ubicacion_id, receptor_id, forma_pago_id, expendio_id, descuento, estado_id) VALUES (p_cliente_id, p_ubicacion_id, p_receptor_id, p_forma_pago_id, p_expendio_id, COALESCE(p_descuento, 0), 1) RETURNING pedido.id, pedido.fecha_creacion, pedido.estado_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_agregar_producto_pedido(
    p_pedido_id INT, p_producto_id INT, p_cantidad INT
) RETURNS VOID AS $$
DECLARE v_precio DECIMAL;
BEGIN
    SELECT precio INTO v_precio FROM producto WHERE id = p_producto_id;
    INSERT INTO pedido_producto (pedido_id, producto_id, cantidad, precio_unitario, subtotal) VALUES (p_pedido_id, p_producto_id, p_cantidad, v_precio, (v_precio * p_cantidad));
    UPDATE pedido SET total = total + (v_precio * p_cantidad) WHERE id = p_pedido_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_asignar_piloto_pedido(p_pedido_id INT, p_piloto_id INT) RETURNS TABLE (id INT, piloto_id INT, estado_id INT, fecha_asignacion TIMESTAMP) AS $$
BEGIN
    RETURN QUERY UPDATE pedido SET piloto_id = p_piloto_id, fecha_asignacion = CURRENT_TIMESTAMP, estado_id = 2 WHERE pedido.id = p_pedido_id RETURNING pedido.id, pedido.piloto_id, pedido.estado_id, pedido.fecha_asignacion;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_cambiar_estado_pedido(p_pedido_id INT, p_estado_id INT, p_motivo TEXT) RETURNS TABLE (id INT, estado_id INT, fecha_entrega TIMESTAMP, motivo_no_entrega TEXT) AS $$
BEGIN
    RETURN QUERY UPDATE pedido SET estado_id = p_estado_id, fecha_entrega = CASE WHEN p_estado_id = 3 THEN CURRENT_TIMESTAMP ELSE pedido.fecha_entrega END, motivo_no_entrega = CASE WHEN p_estado_id = 4 THEN p_motivo ELSE pedido.motivo_no_entrega END WHERE pedido.id = p_pedido_id RETURNING pedido.id, pedido.estado_id, pedido.fecha_entrega, pedido.motivo_no_entrega;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_reporte_cuadre_cierre(p_fecha DATE, p_expendio_id INT) RETURNS TABLE (forma_de_pago VARCHAR, cantidad_transacciones INT, total_recaudado DECIMAL) AS $$
BEGIN
    RETURN QUERY SELECT fp.nombre::VARCHAR, COUNT(p.id)::INT, SUM(p.total - COALESCE(p.descuento, 0))::DECIMAL FROM pedido p JOIN forma_pago fp ON p.forma_pago_id = fp.id WHERE DATE(p.fecha_creacion) = p_fecha AND (p_expendio_id IS NULL OR p.expendio_id = p_expendio_id) AND p.estado_id IN (3, 4) GROUP BY fp.nombre ORDER BY total_recaudado DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_obtener_historial_pedido(p_pedido_id INT) RETURNS TABLE (id INT, estado_anterior VARCHAR, estado_nuevo VARCHAR, responsable VARCHAR, rol VARCHAR, fecha_cambio TIMESTAMP, comentario TEXT) AS $$
BEGIN
    RETURN QUERY SELECT l.id, ea.nombre::VARCHAR, en.nombre::VARCHAR, u.nombre::VARCHAR, r.nombre::VARCHAR, l.fecha_cambio, l.comentario FROM log_entrega l JOIN estado ea ON l.estado_anterior_id = ea.id JOIN estado en ON l.estado_nuevo_id = en.id JOIN usuario u ON l.usuario_id = u.id JOIN rol r ON u.rol_id = r.id WHERE l.pedido_id = p_pedido_id ORDER BY l.fecha_cambio DESC;
END;
$$ LANGUAGE plpgsql;


-- ==============================================================================
-- 4. TRIGGER (Para el Log de Entregas)
-- ==============================================================================

CREATE OR REPLACE FUNCTION registrar_log_estado() RETURNS TRIGGER AS $$
BEGIN
    IF OLD.estado_id != NEW.estado_id THEN
        INSERT INTO log_entrega (pedido_id, estado_anterior_id, estado_nuevo_id, usuario_id) VALUES (NEW.id, OLD.estado_id, NEW.estado_id, COALESCE(NEW.piloto_id, NEW.receptor_id));
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_log_estado AFTER UPDATE ON pedido FOR EACH ROW EXECUTE FUNCTION registrar_log_estado();


-- ==============================================================================
-- 5. DATOS DE PRUEBA Y NEGOCIO DE GAS
-- ==============================================================================

-- Productos
INSERT INTO producto (nombre, descripcion, precio) VALUES 
('Cilindro 25 Lbs Lleno', 'Gas propano de 25 libras', 120.00),
('Cilindro 35 Lbs Lleno', 'Gas propano de 35 libras', 168.00),
('Cilindro 100 Lbs Lleno', 'Gas propano de 100 libras', 480.00),
('Cilindro 25 Lbs Vacío', 'Envase vacío de 25 libras', 0.00),
('Cilindro 35 Lbs Vacío', 'Envase vacío de 35 libras', 0.00),
('Manguera Alta Presión', 'Manguera por metro', 15.00),
('Regulador de Gas', 'Regulador estandar', 45.00),
('Abrazadera', 'Abrazadera de metal', 5.00);

-- Stock
INSERT INTO stock (producto_id, cantidad, stock_minimo) SELECT id, 100, 10 FROM producto;

-- Pilotos
INSERT INTO usuario (nombre, telefono, email, rol_id, contrasena_hash) VALUES 
('Mario Repartidor', '44445555', 'mario@gas.com', 2, 'dummy'),
('Luis Motorista', '66667777', 'luis@gas.com', 2, 'dummy');

-- Clientes
INSERT INTO cliente (nombre, telefono, email, nit_dpi, fecha_cumpleanos) VALUES 
('Doña Carmen', '55511122', 'carmen@email.com', '1234567-8', '1980-05-15'),
('Comedor El Buen Sabor', '55599988', 'comedor@email.com', '9876543-2', '1995-10-20'),
('Familia Perez', '55533344', 'perez@email.com', 'CF', '1990-01-01');

-- Ubicaciones
INSERT INTO ubicacion (cliente_id, direccion, referencia, predeterminada) VALUES 
(1, 'Manzana 4 Lote 12, San Cristobal', 'Porton blanco', true),
(2, 'Mercado de Barcenas, Local 4', 'A la par de la carnicería', true),
(3, 'Residenciales Los Pinos, Casa 8', 'Frente al parque', true);

-- Simulación de Pedidos (usando Admin como receptor y Mario como piloto)
-- Pedido 1: Efectivo, San Cristobal (Ayer) - Entregado
INSERT INTO pedido (cliente_id, ubicacion_id, receptor_id, piloto_id, forma_pago_id, expendio_id, estado_id, total, fecha_creacion) VALUES (1, 1, 1, 2, 1, 2, 3, 168.00, CURRENT_DATE - INTERVAL '1 day');
INSERT INTO pedido_producto (pedido_id, producto_id, cantidad, precio_unitario, subtotal) VALUES (1, 2, 1, 168.00, 168.00);

-- Pedido 2: Tarjeta POS, Barcenas (Hoy) - Finalizado
INSERT INTO pedido (cliente_id, ubicacion_id, receptor_id, piloto_id, forma_pago_id, expendio_id, estado_id, descuento, total, fecha_creacion) VALUES (2, 2, 1, 2, 3, 1, 4, 10.00, 480.00, CURRENT_DATE);
INSERT INTO pedido_producto (pedido_id, producto_id, cantidad, precio_unitario, subtotal) VALUES (2, 3, 1, 480.00, 480.00);

-- Pedido 3: Transferencia, San Cristobal (Hoy) - Entregado
INSERT INTO pedido (cliente_id, ubicacion_id, receptor_id, piloto_id, forma_pago_id, expendio_id, estado_id, total, fecha_creacion) VALUES (3, 3, 1, 2, 2, 2, 3, 180.00, CURRENT_DATE);
INSERT INTO pedido_producto (pedido_id, producto_id, cantidad, precio_unitario, subtotal) VALUES (3, 1, 1, 120.00, 120.00);
INSERT INTO pedido_producto (pedido_id, producto_id, cantidad, precio_unitario, subtotal) VALUES (3, 6, 1, 15.00, 15.00);
INSERT INTO pedido_producto (pedido_id, producto_id, cantidad, precio_unitario, subtotal) VALUES (3, 7, 1, 45.00, 45.00);