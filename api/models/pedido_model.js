const pool = require('../db/connection');

async function crear(pedidoData) {
    const { cliente_id, ubicacion_id, receptor_id, productos } = pedidoData;
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        const resPedido = await client.query(`SELECT * FROM sp_crear_pedido($1, $2, $3)`, [cliente_id, ubicacion_id, receptor_id]);
        const pedidoId = resPedido.rows[0].id;

        for (const prod of productos) {
            await client.query(`SELECT sp_agregar_producto_pedido($1, $2, $3)`, [pedidoId, prod.producto_id, prod.cantidad]);
        }

        await client.query('COMMIT');
        return resPedido.rows[0];
    } catch (e) {
        await client.query('ROLLBACK');
        throw e;
    } finally {
        client.release();
    }
}

async function listar() {
    const result = await pool.query(`SELECT * FROM sp_listar_pedidos()`);
    return result.rows;
}

async function obtenerDetalle(id) {
    const result = await pool.query(`SELECT * FROM sp_obtener_pedido_detalle($1)`, [id]);
    return result.rows;
}

async function asignarPiloto(id, piloto_id) {
    const query = `SELECT * FROM sp_asignar_piloto_pedido($1, $2)`;
    const result = await pool.query(query, [id, piloto_id]);
    return result.rows[0] || null;
}

async function cambiarEstado(id, estado_id, motivo) {
    const query = `SELECT * FROM sp_cambiar_estado_pedido($1, $2, $3)`;
    const result = await pool.query(query, [id, estado_id, motivo || null]);
    return result.rows[0] || null;
}

async function obtenerHistorial(id) {
    const query = `SELECT * FROM sp_obtener_historial_pedido($1)`;
    const result = await pool.query(query, [id]);
    return result.rows;
}

module.exports = { crear, listar, obtenerDetalle, asignarPiloto, cambiarEstado, obtenerHistorial };