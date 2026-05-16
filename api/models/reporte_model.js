const pool = require('../db/connection');

async function obtenerReporteConsolidado(fechaInicio, fechaFin) {
    // Si no mandan fechas, traemos los de hoy por defecto
    let dateFilter = "";
    const values = [];

    if (fechaInicio && fechaFin) {
        dateFilter = "AND p.fecha_creacion::DATE BETWEEN $1 AND $2";
        values.push(fechaInicio, fechaFin);
    }

    const query = `
        SELECT 
            p.id AS no_recibo,
            p.fecha_creacion AS fecha,
            c.nombre AS cliente,
            (SELECT SUM(cantidad) FROM pedido_producto WHERE pedido_id = p.id) AS cantidad_productos,
            p.total,
            fp.nombre AS tipo_pago,
            p.contrasena_credito,
            pt.no_operacion AS ref_transferencia,
            pt.monto AS monto_transferencia,
            b.nombre AS banco_transferencia,
            f.no_factura,
            f.serie,
            f.nit,
            f.nombre_facturacion,
            f.monto_facturado
        FROM pedido p
        JOIN cliente c ON p.cliente_id = c.id
        LEFT JOIN forma_pago fp ON p.forma_pago_id = fp.id
        LEFT JOIN pago_transferencia pt ON pt.pedido_id = p.id
        LEFT JOIN banco b ON pt.banco_id = b.id
        LEFT JOIN factura f ON f.pedido_id = p.id
        WHERE p.estado_id IN (3, 4) -- Solo traemos los Entregados o Finalizados
        ${dateFilter}
        ORDER BY p.id DESC;
    `;

    try {
        const result = await pool.query(query, values);
        return result.rows;
    } catch (error) {
        // Fallback por si la tabla de productos se llama detalle_pedido
        const queryFallback = query.replace('pedido_producto', 'detalle_pedido');
        const result = await pool.query(queryFallback, values);
        return result.rows;
    }
}

module.exports = { obtenerReporteConsolidado };