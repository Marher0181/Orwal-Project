const pool = require('../db/connection');

async function crear(ubicacionData) {
    const { cliente_id, lat, lng, direccion, referencia, predeterminada, url_mapa } = ubicacionData;
    
    // Ejecuta tu SP original
    const query = `SELECT * FROM sp_crear_ubicacion($1, $2, $3, $4, $5, $6)`;
    const values = [cliente_id, lat || null, lng || null, direccion, referencia || null, predeterminada || false];
    const result = await pool.query(query, values);
    const nuevaUbicacion = result.rows[0];

    // Magia nueva: Si viene un link de waze, lo actualizamos inmediatamente
    if (url_mapa) {
        await pool.query(`UPDATE ubicacion SET url_mapa = $1 WHERE id = $2`, [url_mapa, nuevaUbicacion.id]);
        nuevaUbicacion.url_mapa = url_mapa;
    }

    return nuevaUbicacion;
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
    const { lat, lng, direccion, referencia, predeterminada, url_mapa } = ubicacionData;
    const query = `SELECT * FROM sp_actualizar_ubicacion($1, $2, $3, $4, $5, $6)`;
    const values = [id, lat || null, lng || null, direccion || null, referencia || null, predeterminada !== undefined ? predeterminada : null];
    const result = await pool.query(query, values);
    const ubiActualizada = result.rows[0] || null;

    if (ubiActualizada && url_mapa !== undefined) {
        await pool.query(`UPDATE ubicacion SET url_mapa = $1 WHERE id = $2`, [url_mapa, id]);
        ubiActualizada.url_mapa = url_mapa;
    }

    return ubiActualizada;
}

async function eliminar(id) {
    const query = `SELECT * FROM sp_eliminar_ubicacion($1)`;
    const result = await pool.query(query, [id]);
    return result.rows[0] || null;
}

module.exports = { crear, listarPorCliente, obtenerPorId, actualizar, eliminar };