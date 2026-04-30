const pool = require('./db/connection');
const bcrypt = require('bcrypt');

async function inicializarBaseDeDatos() {
    try {
        console.log('Iniciando configuracion de la base de datos...');

        await pool.query(`ALTER TABLE usuario ADD COLUMN IF NOT EXISTS contrasena_hash VARCHAR(255);`);
        console.log('Columna contrasena_hash verificada.');

        const hash = await bcrypt.hash('admin123', 10);
        const adminQuery = `
            UPDATE usuario 
            SET contrasena_hash = $1 
            WHERE email = 'admin@entregas.com' 
            RETURNING id;
        `;
        const adminResult = await pool.query(adminQuery, [hash]);
        
        if (adminResult.rows.length > 0) {
            console.log('Contrasena del Admin actualizada (Email: admin@entregas.com / Pass: admin123).');
        } else {
            console.log('No se encontro al admin en la tabla. Asegurate de haber corrido el SQL de inicio.');
        }

        const spClientes = `
            CREATE OR REPLACE FUNCTION sp_crear_cliente(
                p_nombre VARCHAR, p_telefono VARCHAR, p_email VARCHAR
            ) RETURNS TABLE (id INT, nombre VARCHAR, telefono VARCHAR, email VARCHAR, fecha_registro TIMESTAMP, activo BOOLEAN) AS $$
            BEGIN
                RETURN QUERY 
                INSERT INTO cliente (nombre, telefono, email) 
                VALUES (p_nombre, p_telefono, p_email) 
                RETURNING cliente.id, cliente.nombre, cliente.telefono, cliente.email, cliente.fecha_registro, cliente.activo;
            END;
            $$ LANGUAGE plpgsql;

            CREATE OR REPLACE FUNCTION sp_listar_clientes() 
            RETURNS TABLE (id INT, nombre VARCHAR, telefono VARCHAR, email VARCHAR, fecha_registro TIMESTAMP, activo BOOLEAN) AS $$
            BEGIN
                RETURN QUERY SELECT c.id, c.nombre, c.telefono, c.email, c.fecha_registro, c.activo FROM cliente c ORDER BY c.id DESC;
            END;
            $$ LANGUAGE plpgsql;

            CREATE OR REPLACE FUNCTION sp_obtener_cliente(p_id INT) 
            RETURNS TABLE (id INT, nombre VARCHAR, telefono VARCHAR, email VARCHAR, fecha_registro TIMESTAMP, activo BOOLEAN) AS $$
            BEGIN
                RETURN QUERY SELECT c.id, c.nombre, c.telefono, c.email, c.fecha_registro, c.activo FROM cliente c WHERE c.id = p_id;
            END;
            $$ LANGUAGE plpgsql;

            CREATE OR REPLACE FUNCTION sp_actualizar_cliente(
                p_id INT, p_nombre VARCHAR, p_telefono VARCHAR, p_email VARCHAR, p_activo BOOLEAN
            ) RETURNS TABLE (id INT, nombre VARCHAR, telefono VARCHAR, email VARCHAR, fecha_registro TIMESTAMP, activo BOOLEAN) AS $$
            BEGIN
                RETURN QUERY 
                UPDATE cliente 
                SET nombre = COALESCE(p_nombre, cliente.nombre),
                    telefono = COALESCE(p_telefono, cliente.telefono),
                    email = COALESCE(p_email, cliente.email),
                    activo = COALESCE(p_activo, cliente.activo)
                WHERE cliente.id = p_id 
                RETURNING cliente.id, cliente.nombre, cliente.telefono, cliente.email, cliente.fecha_registro, cliente.activo;
            END;
            $$ LANGUAGE plpgsql;

            CREATE OR REPLACE FUNCTION sp_eliminar_cliente(p_id INT) 
            RETURNS TABLE (id INT, nombre VARCHAR, telefono VARCHAR, email VARCHAR, fecha_registro TIMESTAMP, activo BOOLEAN) AS $$
            BEGIN
                RETURN QUERY UPDATE cliente SET activo = false WHERE cliente.id = p_id 
                RETURNING cliente.id, cliente.nombre, cliente.telefono, cliente.email, cliente.fecha_registro, cliente.activo;
            END;
            $$ LANGUAGE plpgsql;
        `;
        await pool.query(spClientes);
        console.log('Procesos Almacenados de CLIENTES creados.');

        const spPedidos = `
            CREATE OR REPLACE FUNCTION sp_crear_pedido(
                p_cliente_id INT, p_ubicacion_id INT, p_receptor_id INT
            ) RETURNS TABLE (id INT, cliente_id INT, ubicacion_id INT, receptor_id INT, estado_id INT, fecha_creacion TIMESTAMP) AS $$
            BEGIN
                RETURN QUERY 
                INSERT INTO pedido (cliente_id, ubicacion_id, receptor_id) 
                VALUES (p_cliente_id, p_ubicacion_id, p_receptor_id) 
                RETURNING pedido.id, pedido.cliente_id, pedido.ubicacion_id, pedido.receptor_id, pedido.estado_id, pedido.fecha_creacion;
            END;
            $$ LANGUAGE plpgsql;

            CREATE OR REPLACE FUNCTION sp_asignar_piloto_pedido(
                p_pedido_id INT, p_piloto_id INT
            ) RETURNS TABLE (id INT, piloto_id INT, estado_id INT, fecha_asignacion TIMESTAMP) AS $$
            BEGIN
                RETURN QUERY 
                UPDATE pedido 
                SET piloto_id = p_piloto_id, fecha_asignacion = CURRENT_TIMESTAMP, estado_id = 2 
                WHERE pedido.id = p_pedido_id 
                RETURNING pedido.id, pedido.piloto_id, pedido.estado_id, pedido.fecha_asignacion;
            END;
            $$ LANGUAGE plpgsql;
        `;
        await pool.query(spPedidos);
        console.log('Procesos Almacenados de PEDIDOS creados.');

        console.log('La base de datos esta configurada con Procesos Almacenados.');
        process.exit(0);
    } catch (error) {
        console.error('Error configurando la base de datos:', error);
        process.exit(1);
    }
}

inicializarBaseDeDatos();