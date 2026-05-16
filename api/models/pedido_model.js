const pool = require('../db/connection');

async function crear(pedidoData) {
    // Agregamos forma_pago_id y expendio_id
    const { cliente_id, ubicacion_id, receptor_id, productos, forma_pago_id, expendio_id } = pedidoData;
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        
        // Creamos el pedido con tu SP original
        const resPedido = await client.query(`SELECT * FROM sp_crear_pedido($1, $2, $3)`, [cliente_id, ubicacion_id, receptor_id]);
        const pedidoId = resPedido.rows[0].id;

        // Actualizamos los nuevos datos contables
        if (forma_pago_id || expendio_id) {
            await client.query(
                `UPDATE pedido SET forma_pago_id = $1, expendio_id = $2 WHERE id = $3`,
                [forma_pago_id || null, expendio_id || null, pedidoId]
            );
        }

        // Insertamos los productos
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
    const query = `
        SELECT 
            p.id, 
            c.nombre AS cliente, 
            u.direccion, 
            u.url_mapa,
            fp.nombre AS forma_pago, 
            ex.nombre AS expendio, 
            p.total, 
            est.nombre AS estado, 
            p.piloto_id, 
            p.estado_id,
            p.fecha_creacion AS fecha 
        FROM pedido p
        JOIN cliente c ON p.cliente_id = c.id
        JOIN ubicacion u ON p.ubicacion_id = u.id
        LEFT JOIN forma_pago fp ON p.forma_pago_id = fp.id
        LEFT JOIN expendio ex ON p.expendio_id = ex.id
        JOIN estado est ON p.estado_id = est.id
        ORDER BY p.id DESC;
    `;
    const result = await pool.query(query);
    return result.rows;
}

async function obtenerDetalle(id) {
    try {
        // Intento 1: Nombre de tabla estándar (pedido_producto)
        const query = `
            SELECT 
                pr.nombre AS producto, 
                pp.cantidad, 
                pr.precio, 
                (pp.cantidad * pr.precio) AS subtotal
            FROM pedido_producto pp
            JOIN producto pr ON pp.producto_id = pr.id
            WHERE pp.pedido_id = $1;
        `;
        const result = await pool.query(query, [id]);
        return result.rows;
    } catch (error) {
        // Intento 2: Si el sistema usaba detalle_pedido
        const queryFallback = `
            SELECT 
                pr.nombre AS producto, 
                dp.cantidad, 
                pr.precio, 
                (dp.cantidad * pr.precio) AS subtotal
            FROM detalle_pedido dp
            JOIN producto pr ON dp.producto_id = pr.id
            WHERE dp.pedido_id = $1;
        `;
        const resultFallback = await pool.query(queryFallback, [id]);
        return resultFallback.rows;
    }
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