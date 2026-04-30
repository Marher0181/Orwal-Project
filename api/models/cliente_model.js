const pool = require('../db/connection');

async function crear(clienteData) {
    const { nombre, telefono, email } = clienteData;
    const query = `SELECT * FROM sp_crear_cliente($1, $2, $3)`;
    const values = [nombre, telefono, email || null];
    
    const result = await pool.query(query, values);
    return result.rows[0];
}

async function listar() {
    const query = `SELECT * FROM sp_listar_clientes()`;
    const result = await pool.query(query);
    return result.rows;
}

async function obtenerPorId(id) {
    const query = `SELECT * FROM sp_obtener_cliente($1)`;
    const result = await pool.query(query, [id]);
    return result.rows[0] || null;
}

async function actualizar(id, clienteData) {
    const { nombre, telefono, email, activo } = clienteData;
    const query = `SELECT * FROM sp_actualizar_cliente($1, $2, $3, $4, $5)`;
    const values = [id, nombre || null, telefono || null, email || null, activo !== undefined ? activo : null];
    
    const result = await pool.query(query, values);
    return result.rows[0] || null;
}

async function eliminar(id) {
    const query = `SELECT * FROM sp_eliminar_cliente($1)`;
    const result = await pool.query(query, [id]);
    return result.rows[0] || null;
}

module.exports = {
    crear,
    listar,
    obtenerPorId,
    actualizar,
    eliminar
};