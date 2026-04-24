-- ============================================
-- GESTOR DE ENTREGAS
-- Base de datos en PostgreSQL
-- ============================================

-- 1. TABLA ROL (valores fijos)
CREATE TABLE rol (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(20) NOT NULL UNIQUE CHECK (nombre IN ('Receptor', 'Piloto', 'Admin'))
);

-- 2. TABLA USUARIO
CREATE TABLE usuario (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    telefono VARCHAR(20) NOT NULL UNIQUE,
    email VARCHAR(100) UNIQUE,
    rol_id INT NOT NULL,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    activo BOOLEAN DEFAULT TRUE,
    CONSTRAINT fk_usuario_rol FOREIGN KEY (rol_id) REFERENCES rol(id)
);

-- 3. TABLA CLIENTE
CREATE TABLE cliente (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    telefono VARCHAR(20) NOT NULL UNIQUE,
    email VARCHAR(100),
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    activo BOOLEAN DEFAULT TRUE
);

-- 4. TABLA UBICACION
CREATE TABLE ubicacion (
    id SERIAL PRIMARY KEY,
    cliente_id INT NOT NULL,
    lat DECIMAL(10, 8),
    lng DECIMAL(11, 8),
    direccion TEXT NOT NULL,
    referencia TEXT,
    predeterminada BOOLEAN DEFAULT FALSE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ubicacion_cliente FOREIGN KEY (cliente_id) REFERENCES cliente(id) ON DELETE CASCADE
);

-- 5. TABLA ESTADO (valores fijos)
CREATE TABLE estado (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(20) NOT NULL UNIQUE CHECK (nombre IN ('Por entregar', 'En camino', 'Entregado', 'No entregado'))
);

-- 6. TABLA PRODUCTO
CREATE TABLE producto (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    precio DECIMAL(10, 2) NOT NULL CHECK (precio >= 0),
    activo BOOLEAN DEFAULT TRUE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 7. TABLA STOCK
CREATE TABLE stock (
    id SERIAL PRIMARY KEY,
    producto_id INT NOT NULL UNIQUE,
    cantidad INT NOT NULL DEFAULT 0 CHECK (cantidad >= 0),
    stock_minimo INT DEFAULT 0,
    ultima_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_stock_producto FOREIGN KEY (producto_id) REFERENCES producto(id) ON DELETE CASCADE
);

-- 8. TABLA PEDIDO (principal)
CREATE TABLE pedido (
    id SERIAL PRIMARY KEY,
    cliente_id INT NOT NULL,
    ubicacion_id INT NOT NULL,
    receptor_id INT NOT NULL,
    piloto_id INT,
    estado_id INT NOT NULL DEFAULT 1,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_asignacion TIMESTAMP,
    fecha_entrega TIMESTAMP,
    motivo_no_entrega TEXT,
    total DECIMAL(10, 2) DEFAULT 0,
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (cliente_id) REFERENCES cliente(id),
    CONSTRAINT fk_pedido_ubicacion FOREIGN KEY (ubicacion_id) REFERENCES ubicacion(id),
    CONSTRAINT fk_pedido_receptor FOREIGN KEY (receptor_id) REFERENCES usuario(id),
    CONSTRAINT fk_pedido_piloto FOREIGN KEY (piloto_id) REFERENCES usuario(id),
    CONSTRAINT fk_pedido_estado FOREIGN KEY (estado_id) REFERENCES estado(id),
    CONSTRAINT chk_motivo_no_entrega CHECK (
        (estado_id != 4) OR (estado_id = 4 AND motivo_no_entrega IS NOT NULL AND motivo_no_entrega != '')
    )
);

-- 9. TABLA PEDIDO_PRODUCTO (relación muchos a muchos)
CREATE TABLE pedido_producto (
    pedido_id INT NOT NULL,
    producto_id INT NOT NULL,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario DECIMAL(10, 2) NOT NULL,
    subtotal DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (pedido_id, producto_id),
    CONSTRAINT fk_pp_pedido FOREIGN KEY (pedido_id) REFERENCES pedido(id) ON DELETE CASCADE,
    CONSTRAINT fk_pp_producto FOREIGN KEY (producto_id) REFERENCES producto(id)
);

-- 10. TABLA LOG_ENTREGA (historial de cambios de estado)
CREATE TABLE log_entrega (
    id SERIAL PRIMARY KEY,
    pedido_id INT NOT NULL,
    estado_anterior_id INT NOT NULL,
    estado_nuevo_id INT NOT NULL,
    usuario_id INT NOT NULL,
    comentario TEXT,
    fecha_cambio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_log_pedido FOREIGN KEY (pedido_id) REFERENCES pedido(id) ON DELETE CASCADE,
    CONSTRAINT fk_log_estado_anterior FOREIGN KEY (estado_anterior_id) REFERENCES estado(id),
    CONSTRAINT fk_log_estado_nuevo FOREIGN KEY (estado_nuevo_id) REFERENCES estado(id),
    CONSTRAINT fk_log_usuario FOREIGN KEY (usuario_id) REFERENCES usuario(id)
);

-- ============================================
-- ÍNDICES PARA OPTIMIZAR CONSULTAS
-- ============================================

-- Índices para búsquedas frecuentes
CREATE INDEX idx_usuario_rol ON usuario(rol_id);
CREATE INDEX idx_usuario_telefono ON usuario(telefono);
CREATE INDEX idx_cliente_telefono ON cliente(telefono);
CREATE INDEX idx_ubicacion_cliente ON ubicacion(cliente_id);
CREATE INDEX idx_pedido_cliente ON pedido(cliente_id);
CREATE INDEX idx_pedido_piloto ON pedido(piloto_id);
CREATE INDEX idx_pedido_estado ON pedido(estado_id);
CREATE INDEX idx_pedido_fecha ON pedido(fecha_creacion);
CREATE INDEX idx_pedido_piloto_estado ON pedido(piloto_id, estado_id);
CREATE INDEX idx_stock_producto ON stock(producto_id);
CREATE INDEX idx_pedido_producto_pedido ON pedido_producto(pedido_id);
CREATE INDEX idx_log_pedido ON log_entrega(pedido_id);
CREATE INDEX idx_log_fecha ON log_entrega(fecha_cambio);

-- ============================================
-- DATOS INICIALES (SEMILLA)
-- ============================================

-- Insertar roles
INSERT INTO rol (nombre) VALUES ('Receptor'), ('Piloto'), ('Admin');

-- Insertar estados
INSERT INTO estado (nombre) VALUES ('Por entregar'), ('En camino'), ('Entregado'), ('No entregado');

-- Insertar productos de ejemplo
INSERT INTO producto (nombre, descripcion, precio) VALUES
    ('Hamburguesa', 'Hamburguesa completa con papas', 8.99),
    ('Pizza', 'Pizza familiar pepperoni', 15.99),
    ('Gaseosa', 'Gaseosa 2.5 litros', 3.50),
    ('Ensalada', 'Ensalada César', 6.50);

-- Insertar stock inicial
INSERT INTO stock (producto_id, cantidad, stock_minimo) VALUES
    (1, 50, 10),
    (2, 30, 5),
    (3, 100, 20),
    (4, 25, 5);

-- Insertar usuario admin por defecto
INSERT INTO usuario (nombre, telefono, email, rol_id) VALUES
    ('Admin Sistema', '0000000000', 'admin@entregas.com', 3);

-- ============================================
-- FUNCIONES Y TRIGGERS
-- ============================================

-- Función para actualizar stock al crear/actualizar pedido
CREATE OR REPLACE FUNCTION actualizar_stock()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql;

-- Trigger para actualizar stock al agregar producto al pedido
CREATE TRIGGER trigger_actualizar_stock
AFTER INSERT ON pedido_producto
FOR EACH ROW
EXECUTE FUNCTION actualizar_stock();

-- Función para registrar cambios de estado en log
CREATE OR REPLACE FUNCTION registrar_log_estado()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.estado_id != NEW.estado_id THEN
        INSERT INTO log_entrega (pedido_id, estado_anterior_id, estado_nuevo_id, usuario_id)
        VALUES (NEW.id, OLD.estado_id, NEW.estado_id, NEW.piloto_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para log de cambios de estado
CREATE TRIGGER trigger_log_estado
AFTER UPDATE OF estado_id ON pedido
FOR EACH ROW
EXECUTE FUNCTION registrar_log_estado();

-- Función para actualizar total del pedido
CREATE OR REPLACE FUNCTION actualizar_total_pedido()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql;

-- Trigger para actualizar total
CREATE TRIGGER trigger_actualizar_total
AFTER INSERT OR UPDATE OR DELETE ON pedido_producto
FOR EACH ROW
EXECUTE FUNCTION actualizar_total_pedido();

-- ============================================
-- VISTAS ÚTILES
-- ============================================

-- Vista de pedidos pendientes (sin piloto)
CREATE VIEW pedidos_pendientes AS
SELECT 
    p.id,
    c.nombre AS cliente,
    c.telefono,
    u.nombre AS receptor,
    p.fecha_creacion
FROM pedido p
JOIN cliente c ON c.id = p.cliente_id
JOIN usuario u ON u.id = p.receptor_id
WHERE p.piloto_id IS NULL AND p.estado_id = 1;

-- Vista de entregas por piloto (pendientes)
CREATE VIEW entregas_piloto AS
SELECT 
    p.id,
    u.nombre AS piloto,
    c.nombre AS cliente,
    c.telefono,
    ub.direccion,
    p.fecha_asignacion
FROM pedido p
JOIN usuario u ON u.id = p.piloto_id
JOIN cliente c ON c.id = p.cliente_id
JOIN ubicacion ub ON ub.id = p.ubicacion_id
WHERE p.estado_id IN (1, 2);

-- Vista de reporte de entregas diarias
CREATE VIEW reporte_entregas_diarias AS
SELECT 
    DATE(fecha_entrega) AS dia,
    COUNT(*) AS total_entregas,
    SUM(total) AS monto_total
FROM pedido
WHERE estado_id = 3 AND fecha_entrega IS NOT NULL
GROUP BY DATE(fecha_entrega)
ORDER BY dia DESC;

-- ============================================
-- PROCEDIMIENTOS ALMACENADOS
-- ============================================

-- Procedimiento para asignar piloto a pedido
CREATE OR REPLACE PROCEDURE asignar_piloto(
    p_pedido_id INT,
    p_piloto_id INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE pedido
    SET piloto_id = p_piloto_id,
        fecha_asignacion = CURRENT_TIMESTAMP
    WHERE id = p_pedido_id;
END;
$$;

-- Procedimiento para cambiar estado con motivo
CREATE OR REPLACE PROCEDURE cambiar_estado_pedido(
    p_pedido_id INT,
    p_estado_nombre VARCHAR,
    p_motivo TEXT DEFAULT NULL
)
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