const pool = require('../db/connection');

async function obtenerStock() {
    const query = `
        SELECT 
            i.id,
            a.nombre AS almacen,
            p.nombre AS producto,
            i.cantidad
        FROM inventario i
        JOIN almacen a ON i.almacen_id = a.id
        JOIN producto p ON i.producto_id = p.id
        ORDER BY a.nombre, p.nombre;
    `;
    const result = await pool.query(query);
    return result.rows;
}

async function obtenerAlmacenes() {
    const result = await pool.query('SELECT * FROM almacen ORDER BY id');
    return result.rows;
}

async function registrarMovimiento(data) {
    const { almacen_id, producto_id, usuario_id, tipo_movimiento, cantidad, motivo } = data;
    const client = await pool.connect();
    
    try {
        await client.query('BEGIN');

        await client.query(
            `INSERT INTO movimiento_inventario (almacen_id, producto_id, usuario_id, tipo_movimiento, cantidad, motivo) 
             VALUES ($1, $2, $3, $4, $5, $6)`,
            [almacen_id, producto_id, usuario_id, tipo_movimiento, cantidad, motivo]
        );

        const factor = (tipo_movimiento === 'INGRESO' || tipo_movimiento === 'AJUSTE') ? cantidad : -cantidad;

        const updateQuery = `
            INSERT INTO inventario (almacen_id, producto_id, cantidad)
            VALUES ($1, $2, $3)
            ON CONFLICT (almacen_id, producto_id) 
            DO UPDATE SET cantidad = inventario.cantidad + EXCLUDED.cantidad;
        `;
        await client.query(updateQuery, [almacen_id, producto_id, factor]);

        await client.query('COMMIT');
        return true;
    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        client.release();
    }
}

module.exports = { obtenerStock, obtenerAlmacenes, registrarMovimiento };