// models/pedido_combo_model.js
const pool = require('../db/connection');

// 1. CREAR pedido con combos (usa sp_crear_pedido_con_combos)
async function crearPedidoConCombos(pedidoData) {
    const { 
        cliente_id, ubicacion_id, receptor_id, forma_pago_id, 
        expendio_id, descuento, productos, combos 
    } = pedidoData;
    
    const query = `SELECT * FROM sp_crear_pedido_con_combos($1, $2, $3, $4, $5, $6, $7::jsonb, $8::jsonb)`;
    const values = [
        cliente_id, 
        ubicacion_id, 
        receptor_id, 
        forma_pago_id, 
        expendio_id,
        descuento || 0,
        JSON.stringify(productos || []),
        JSON.stringify(combos || [])
    ];
    
    const result = await pool.query(query, values);
    const row = result.rows[0];
    
    if (row.mensaje && row.mensaje.startsWith('Error:')) {
        const error = new Error(row.mensaje);
        error.code = 'SP_ERROR';
        throw error;
    }
    
    return {
        pedido_id: row.pedido_id,
        total: parseFloat(row.total),
        mensaje: row.mensaje
    };
}

// 2. ASIGNAR piloto a pedido (usa sp_asignar_piloto_pedido)
async function asignarPiloto(pedido_id, piloto_id) {
    const query = `SELECT * FROM sp_asignar_piloto_pedido($1, $2)`;
    const result = await pool.query(query, [pedido_id, piloto_id]);
    return result.rows[0];
}

// 3. CAMBIAR estado del pedido (usa sp_cambiar_estado_pedido)
async function cambiarEstado(pedido_id, estado_id, motivo = null) {
    const query = `SELECT * FROM sp_cambiar_estado_pedido($1, $2, $3)`;
    const result = await pool.query(query, [pedido_id, estado_id, motivo]);
    return result.rows[0];
}

// 4. OBTENER historial de cambios (usa sp_obtener_historial_pedido)
async function obtenerHistorial(pedido_id) {
    const query = `SELECT * FROM sp_obtener_historial_pedido($1)`;
    const result = await pool.query(query, [pedido_id]);
    return result.rows;
}

// 5. REPORTE de cuadre (usa sp_reporte_cuadre_cierre)
async function reporteCuadre(fecha, expendio_id = null) {
    const query = `SELECT * FROM sp_reporte_cuadre_cierre($1, $2)`;
    const result = await pool.query(query, [fecha, expendio_id]);
    return result.rows;
}

// 6. REPORTE de ventas de combos (usa sp_reporte_ventas_combos)
async function reporteVentasCombos(fecha_desde, fecha_hasta, expendio_id = null) {
    const query = `SELECT * FROM sp_reporte_ventas_combos($1, $2, $3)`;
    const result = await pool.query(query, [fecha_desde, fecha_hasta, expendio_id]);
    return result.rows;
}

// 7. OBTENER pedido con detalle (NO HAY SP, consulta directa)
async function obtenerPedidoConDetalle(id) {
    const pedidoQuery = `
        SELECT 
            p.id, p.cliente_id, p.ubicacion_id, p.receptor_id, p.piloto_id,
            p.forma_pago_id, p.expendio_id, p.estado_id, p.descuento, p.total,
            p.fecha_creacion, p.fecha_asignacion, p.fecha_entrega, p.motivo_no_entrega,
            c.nombre as cliente_nombre, c.telefono as cliente_telefono,
            u.nombre as receptor_nombre,
            e.nombre as estado_nombre,
            fp.nombre as forma_pago_nombre,
            ex.nombre as expendio_nombre
        FROM pedido p
        JOIN cliente c ON p.cliente_id = c.id
        LEFT JOIN usuario u ON p.receptor_id = u.id
        LEFT JOIN estado e ON p.estado_id = e.id
        LEFT JOIN forma_pago fp ON p.forma_pago_id = fp.id
        LEFT JOIN expendio ex ON p.expendio_id = ex.id
        WHERE p.id = $1
    `;
    
    const pedidoResult = await pool.query(pedidoQuery, [id]);
    
    if (pedidoResult.rows.length === 0) {
        return null;
    }
    
    const pedido = pedidoResult.rows[0];
    
    // Productos sueltos del pedido
    const productosQuery = `
        SELECT 
            pp.id, pp.producto_id, pp.cantidad, pp.precio_unitario, pp.subtotal,
            p.nombre as producto_nombre
        FROM pedido_producto pp
        JOIN producto p ON pp.producto_id = p.id
        WHERE pp.pedido_id = $1
    `;
    
    const productosResult = await pool.query(productosQuery, [id]);
    pedido.productos = productosResult.rows;
    
    // Combos del pedido
    const combosQuery = `
        SELECT DISTINCT
            ms.combo_id,
            c.nombre as combo_nombre,
            SUM(ABS(ms.cantidad) / cp.cantidad) as cantidad_combos,
            (SELECT SUM(p.precio * cp2.cantidad) 
             FROM combo_producto cp2 
             JOIN producto p ON cp2.producto_id = p.id 
             WHERE cp2.combo_id = ms.combo_id) as precio_unitario
        FROM movimiento_stock ms
        JOIN combo c ON ms.combo_id = c.id
        JOIN combo_producto cp ON ms.combo_id = cp.combo_id AND ms.producto_id = cp.producto_id
        WHERE ms.pedido_id = $1 AND ms.tipo_movimiento = 'VENTA_COMBO'
        GROUP BY ms.combo_id, c.nombre
    `;
    
    const combosResult = await pool.query(combosQuery, [id]);
    pedido.combos = combosResult.rows;
    
    return pedido;
}

// 8. LISTAR pedidos con filtros (NO HAY SP, consulta directa)
async function listarPedidos(filtros = {}) {
    let query = `
        SELECT 
            p.id, p.cliente_id, p.total, p.descuento, p.fecha_creacion,
            c.nombre as cliente_nombre,
            e.nombre as estado_nombre,
            fp.nombre as forma_pago_nombre,
            ex.nombre as expendio_nombre,
            (SELECT COUNT(*) FROM pedido_producto WHERE pedido_id = p.id) as total_productos,
            (SELECT COUNT(DISTINCT combo_id) FROM movimiento_stock WHERE pedido_id = p.id AND tipo_movimiento = 'VENTA_COMBO') as total_combos
        FROM pedido p
        JOIN cliente c ON p.cliente_id = c.id
        LEFT JOIN estado e ON p.estado_id = e.id
        LEFT JOIN forma_pago fp ON p.forma_pago_id = fp.id
        LEFT JOIN expendio ex ON p.expendio_id = ex.id
        WHERE 1=1
    `;
    
    const values = [];
    let paramIndex = 1;
    
    if (filtros.cliente_id) {
        query += ` AND p.cliente_id = $${paramIndex++}`;
        values.push(filtros.cliente_id);
    }
    
    if (filtros.estado_id) {
        query += ` AND p.estado_id = $${paramIndex++}`;
        values.push(filtros.estado_id);
    }
    
    if (filtros.expendio_id) {
        query += ` AND p.expendio_id = $${paramIndex++}`;
        values.push(filtros.expendio_id);
    }
    
    if (filtros.fecha_desde) {
        query += ` AND DATE(p.fecha_creacion) >= $${paramIndex++}`;
        values.push(filtros.fecha_desde);
    }
    
    if (filtros.fecha_hasta) {
        query += ` AND DATE(p.fecha_creacion) <= $${paramIndex++}`;
        values.push(filtros.fecha_hasta);
    }
    
    query += ` ORDER BY p.fecha_creacion DESC`;
    
    if (filtros.limite) {
        query += ` LIMIT $${paramIndex++}`;
        values.push(filtros.limite);
    }
    
    if (filtros.offset) {
        query += ` OFFSET $${paramIndex++}`;
        values.push(filtros.offset);
    }
    
    const result = await pool.query(query, values);
    return result.rows;
}

// 9. DASHBOARD (combina datos de varios SPs y consultas)
async function dashboard() {
    const hoy = new Date().toISOString().split('T')[0];
    
    const pedidosHoy = await listarPedidos({
        fecha_desde: hoy,
        fecha_hasta: hoy,
        limite: 10
    });
    
    const cuadreHoy = await reporteCuadre(hoy);
    
    const inicioMes = new Date().getFullYear() + '-' + String(new Date().getMonth() + 1).padStart(2, '0') + '-01';
    const topCombos = await reporteVentasCombos(inicioMes, hoy);
    
    return {
        pedidos_hoy: pedidosHoy,
        cuadre_hoy: cuadreHoy,
        top_combos: topCombos.slice(0, 5),
        total_pedidos_hoy: pedidosHoy.length
    };
}

module.exports = {
    crearPedidoConCombos,
    obtenerPedidoConDetalle,
    listarPedidos,
    asignarPiloto,
    cambiarEstado,
    obtenerHistorial,
    reporteCuadre,
    reporteVentasCombos,
    dashboard
};