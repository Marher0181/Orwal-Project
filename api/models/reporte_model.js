const pool = require('../db/connection');

async function obtenerCuadreCierre(fecha, expendio_id) {
    const query = `SELECT * FROM sp_reporte_cuadre_cierre($1, $2)`;
    const values = [fecha, expendio_id || null];
    const result = await pool.query(query, values);
    return result.rows;
}

module.exports = { obtenerCuadreCierre };