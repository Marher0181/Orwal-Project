// models/combo_model.js
const pool = require('../db/connection');

// 1. CREAR combo (usa sp_crear_combo)
async function crear(comboData) {
    const { nombre, descripcion, productos, creado_por } = comboData;
    
    const query = `SELECT * FROM sp_crear_combo($1, $2, $3::jsonb, $4)`;
    const values = [nombre, descripcion || null, JSON.stringify(productos), creado_por || 1];
    
    const result = await pool.query(query, values);
    const row = result.rows[0];
    
    if (row.mensaje && row.mensaje.startsWith('Error:')) {
        const error = new Error(row.mensaje);
        error.code = 'SP_ERROR';
        throw error;
    }
    
    return {
        id: row.combo_id,
        nombre: row.combo_nombre,
        mensaje: row.mensaje
    };
}

// 2. LISTAR combos (usa sp_listar_combos)
async function listar(soloActivos = true) {
    const query = `SELECT * FROM sp_listar_combos($1)`;
    const result = await pool.query(query, [soloActivos]);
    
    return result.rows.map(row => ({
        id: row.combo_id,
        nombre: row.combo_nombre,
        descripcion: row.combo_descripcion,
        activo: row.combo_activo,
        productos_count: row.productos_count,
        precio_total: parseFloat(row.precio_total),
        max_combos_vendibles: row.max_combos_vendibles,
        fecha_creacion: row.fecha_creacion
    }));
}

// 3. VERIFICAR stock de un combo (usa sp_verificar_stock_combo)
async function verificarStock(id, cantidad = 1) {
    const query = `SELECT * FROM sp_verificar_stock_combo($1)`;
    const result = await pool.query(query, [id]);
    
    if (result.rows.length === 0) {
        return null;
    }
    
    const productos = result.rows.map(row => ({
        producto_id: row.id_producto,
        producto_nombre: row.nombre_producto,
        cantidad_requerida: row.cantidad_necesaria * cantidad,
        stock_actual: row.stock_actual,
        suficiente: row.stock_actual >= (row.cantidad_necesaria * cantidad),
        combos_posibles: Math.floor(row.stock_actual / row.cantidad_necesaria)
    }));
    
    const esVendible = productos.every(p => p.suficiente);
    
    return {
        combo_id: id,
        vendible: esVendible,
        productos: productos
    };
}

// 4. OBTENER combo por ID (combina info de combo + sp_verificar_stock_combo)
async function obtenerPorId(id) {
    // Primero obtener info básica del combo desde tabla combo
    const infoQuery = `SELECT id, nombre, descripcion, activo, fecha_creacion FROM combo WHERE id = $1`;
    const infoResult = await pool.query(infoQuery, [id]);
    
    if (infoResult.rows.length === 0) {
        return null;
    }
    
    const comboInfo = infoResult.rows[0];
    
    // Luego obtener stock y productos del combo
    const stockQuery = `SELECT * FROM sp_verificar_stock_combo($1)`;
    const stockResult = await pool.query(stockQuery, [id]);
    
    return {
        id: comboInfo.id,
        nombre: comboInfo.nombre,
        descripcion: comboInfo.descripcion,
        activo: comboInfo.activo,
        fecha_creacion: comboInfo.fecha_creacion,
        productos: stockResult.rows.map(row => ({
            producto_id: row.id_producto,
            producto_nombre: row.nombre_producto,
            cantidad_requerida: row.cantidad_necesaria,
            stock_actual: row.stock_actual,
            suficiente: row.suficiente,
            combos_posibles: row.max_combos_posibles
        }))
    };
}

// 5. ACTUALIZAR combo (datos basicos) - NO HAY SP, usamos UPDATE directo
async function actualizar(id, comboData) {
    const { nombre, descripcion, activo } = comboData;
    
    const query = `
        UPDATE combo 
        SET nombre = COALESCE($1, nombre),
            descripcion = COALESCE($2, descripcion),
            activo = COALESCE($3, activo),
            fecha_modificacion = NOW()
        WHERE id = $4
        RETURNING id, nombre, descripcion, activo, fecha_creacion, fecha_modificacion
    `;
    const values = [nombre || null, descripcion || null, activo !== undefined ? activo : null, id];
    
    const result = await pool.query(query, values);
    
    if (result.rows.length === 0) {
        return null;
    }
    
    return result.rows[0];
}

// 6. ACTUALIZAR productos de un combo - NO HAY SP, usamos transaccion directa
async function actualizarProductos(id, productos) {
    const client = await pool.connect();
    
    try {
        await client.query('BEGIN');
        
        await client.query('DELETE FROM combo_producto WHERE combo_id = $1', [id]);
        
        for (const prod of productos) {
            await client.query(
                'INSERT INTO combo_producto (combo_id, producto_id, cantidad) VALUES ($1, $2, $3)',
                [id, prod.producto_id, prod.cantidad]
            );
        }
        
        await client.query('COMMIT');
        return { success: true, message: 'Productos actualizados correctamente' };
        
    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        client.release();
    }
}

// 7. ELIMINAR combo (desactivar) - NO HAY SP, usamos UPDATE directo
async function eliminar(id) {
    const query = `
        UPDATE combo 
        SET activo = false, 
            fecha_modificacion = NOW() 
        WHERE id = $1 AND activo = true
        RETURNING id, nombre
    `;
    const result = await pool.query(query, [id]);
    
    if (result.rows.length === 0) {
        return null;
    }
    
    return { id: result.rows[0].id, nombre: result.rows[0].nombre, message: 'Combo desactivado correctamente' };
}

// 8. ACTIVAR combo - NO HAY SP, usamos UPDATE directo
async function activar(id) {
    const query = `
        UPDATE combo 
        SET activo = true, 
            fecha_modificacion = NOW() 
        WHERE id = $1
        RETURNING id, nombre
    `;
    const result = await pool.query(query, [id]);
    
    if (result.rows.length === 0) {
        return null;
    }
    
    return { id: result.rows[0].id, nombre: result.rows[0].nombre, message: 'Combo activado correctamente' };
}

// 9. ELIMINAR combo permanentemente - NO HAY SP, usamos DELETE directo
async function eliminarPermanente(id) {
    const query = `DELETE FROM combo WHERE id = $1 RETURNING id, nombre`;
    const result = await pool.query(query, [id]);
    return result.rows[0] || null;
}

// 10. OBTENER todos los productos - NO HAY SP, consulta directa
async function obtenerProductos() {
    const query = `SELECT id, nombre, precio, (SELECT cantidad FROM stock WHERE producto_id = producto.id) as stock FROM producto WHERE activo = true ORDER BY nombre`;
    const result = await pool.query(query);
    return result.rows;
}

module.exports = {
    crear,
    listar,
    obtenerPorId,
    actualizar,
    actualizarProductos,
    eliminar,
    activar,
    eliminarPermanente,
    obtenerProductos,
    verificarStock
};