const pool = require('../db/connection');

async function crear(ubicacionData) {
    const { cliente_id, lat, lng, direccion, referencia, predeterminada } = ubicacionData;
    const query = `SELECT * FROM sp_crear_ubicacion($1, $2, $3, $4, $5, $6)`;
    const values = [cliente_id, lat || null, lng || null, direccion, referencia || null, predeterminada || false];
    const result = await pool.query(query, values);
    return result.rows[0];
}

async function listarPorCliente(cliente_id) {
    const query = `SELECT * FROM sp_listar_ubicaciones_cliente($1)`;
    const result = await pool.query(query, [cliente_id]);
    return result.rows;
}

async function obtenerPorId(id) {
    const query = `SELECT * FROM sp_obtener_ubicacion($1)`;
    const result = await pool.query(query, [id]);
    return result.rows[0] || null;
}

async function actualizar(id, ubicacionData) {
    const { lat, lng, direccion, referencia, predeterminada } = ubicacionData;
    const query = `SELECT * FROM sp_actualizar_ubicacion($1, $2, $3, $4, $5, $6)`;
    const values = [id, lat || null, lng || null, direccion || null, referencia || null, predeterminada !== undefined ? predeterminada : null];
    const result = await pool.query(query, values);
    return result.rows[0] || null;
}

async function eliminar(id) {
    const query = `SELECT * FROM sp_eliminar_ubicacion($1)`;
    const result = await pool.query(query, [id]);
    return result.rows[0] || null;
}

module.exports = { crear, listarPorCliente, obtenerPorId, actualizar, eliminar };