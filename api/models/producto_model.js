const pool = require('../db/connection');

async function crear(productoData) {
    const { nombre, descripcion, precio, stock_inicial, stock_minimo } = productoData;
    const query = `SELECT * FROM sp_crear_producto($1, $2, $3, $4, $5)`;
    const values = [nombre, descripcion || null, precio, stock_inicial || 0, stock_minimo || 0];
    const result = await pool.query(query, values);
    return result.rows[0];
}

async function listar() {
    const query = `SELECT * FROM sp_listar_productos()`;
    const result = await pool.query(query);
    return result.rows;
}

async function obtenerPorId(id) {
    const query = `SELECT * FROM sp_obtener_producto($1)`;
    const result = await pool.query(query, [id]);
    return result.rows[0] || null;
}

async function actualizar(id, productoData) {
    const { nombre, descripcion, precio, activo, stock_adicional, stock_minimo } = productoData;
    const query = `SELECT * FROM sp_actualizar_producto($1, $2, $3, $4, $5, $6, $7)`;
    const values = [id, nombre || null, descripcion || null, precio || null, activo !== undefined ? activo : null, stock_adicional || null, stock_minimo || null];
    const result = await pool.query(query, values);
    return result.rows[0] || null;
}

async function eliminar(id) {
    const query = `SELECT * FROM sp_eliminar_producto($1)`;
    const result = await pool.query(query, [id]);
    return result.rows[0] || null;
}

module.exports = { crear, listar, obtenerPorId, actualizar, eliminar };