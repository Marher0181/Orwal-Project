const pool = require('../db/connection');
const bcrypt = require('bcrypt');

// 1. CREAR usuario
async function crear(usuarioData) {
    const { nombre, telefono, email, rol_id, contrasena } = usuarioData;
    
    const contrasena_hash = await bcrypt.hash(contrasena, 10);
    
    const query = `SELECT * FROM sp_crear_usuario($1, $2, $3, $4, $5)`;
    const values = [nombre, telefono, email || null, rol_id, contrasena_hash];
    
    const result = await pool.query(query, values);
    const row = result.rows[0];
    
    if (row.mensaje && row.mensaje.startsWith('Error:')) {
        const error = new Error(row.mensaje);
        error.code = 'SP_ERROR';
        throw error;
    }
    
    // Mapear los nuevos nombres de columnas
    return {
        id: row.usuario_id,
        nombre: row.usuario_nombre,
        telefono: row.usuario_telefono,
        email: row.usuario_email,
        rol_id: row.usuario_rol_id,
        rol: row.rol_nombre,
        mensaje: row.mensaje
    };
}

// 2. LISTAR usuarios
async function listar() {
    const query = `SELECT * FROM sp_listar_usuarios()`;
    const result = await pool.query(query);
    
    // Mapear nombres de columnas
    return result.rows.map(row => ({
        id: row.usuario_id,
        nombre: row.usuario_nombre,
        telefono: row.usuario_telefono,
        email: row.usuario_email,
        rol_id: row.usuario_rol_id,
        rol: row.rol_nombre,
        fecha_creacion: row.fecha_creacion,
        activo: row.activo
    }));
}

// 3. OBTENER usuario por ID
async function obtenerPorId(id) {
    const query = `SELECT * FROM sp_obtener_usuario($1)`;
    const result = await pool.query(query, [id]);
    
    if (result.rows.length === 0 || !result.rows[0].existe) {
        return null;
    }
    
    const row = result.rows[0];
    return {
        id: row.usuario_id,
        nombre: row.usuario_nombre,
        telefono: row.usuario_telefono,
        email: row.usuario_email,
        rol_id: row.usuario_rol_id,
        rol: row.rol_nombre,
        fecha_creacion: row.fecha_creacion,
        activo: row.activo
    };
}

// 4. ACTUALIZAR usuario

async function actualizar(id, usuarioData) {
    const { nombre, telefono, email, rol_id, activo, contrasena } = usuarioData;
    
    let contrasena_hash = null;
    if (contrasena) {
        contrasena_hash = await bcrypt.hash(contrasena, 10);
    }
    
    const query = `SELECT * FROM sp_actualizar_usuario($1, $2, $3, $4, $5, $6, $7)`;
    const values = [id, nombre || null, telefono || null, email || null, rol_id || null, activo !== undefined ? activo : null, contrasena_hash];
    
    const result = await pool.query(query, values);
    const row = result.rows[0];
    
    if (row.mensaje && row.mensaje.startsWith('Error:')) {
        const error = new Error(row.mensaje);
        error.code = 'SP_ERROR';
        throw error;
    }
    
    return {
        id: row.usuario_id,
        nombre: row.usuario_nombre,
        telefono: row.usuario_telefono,
        email: row.usuario_email,
        rol_id: row.usuario_rol_id,
        rol: row.rol_nombre,
        activo: row.usuario_activo  // ← CAMBIADO: antes era row.activo
    };
}
// 5. ELIMINAR usuario con SP (borrado lógico)
async function eliminar(id) {
    const query = `SELECT * FROM sp_eliminar_usuario($1)`;
    const result = await pool.query(query, [id]);
    
    if (!result.rows[0].success) {
        const error = new Error(result.rows[0].mensaje);
        error.code = 'SP_ERROR';
        throw error;
    }
    
    return { id, mensaje: result.rows[0].mensaje };
}

// 6. LOGIN con SP (acepta teléfono O email) 🆕
async function login(identificador, contrasena) {
    // Determinar si el identificador es teléfono o email
    const esEmail = identificador.includes('@');
    
    let query;
    let values;
    
    if (esEmail) {
        // Buscar por email
        query = `
            SELECT u.id, u.nombre, u.telefono, u.email, u.rol_id, u.contrasena_hash, r.nombre as rol_nombre
            FROM usuario u
            JOIN rol r ON r.id = u.rol_id
            WHERE u.email = $1 AND u.activo = true
        `;
        values = [identificador];
    } else {
        // Buscar por teléfono
        query = `
            SELECT u.id, u.nombre, u.telefono, u.email, u.rol_id, u.contrasena_hash, r.nombre as rol_nombre
            FROM usuario u
            JOIN rol r ON r.id = u.rol_id
            WHERE u.telefono = $1 AND u.activo = true
        `;
        values = [identificador];
    }
    
    const result = await pool.query(query, values);
    
    if (result.rows.length === 0) {
        return { success: false, error: 'Usuario no encontrado' };
    }
    
    const usuario = result.rows[0];
    
    // Verificar contraseña
    const contrasenaValida = await bcrypt.compare(contrasena, usuario.contrasena_hash);
    
    if (!contrasenaValida) {
        return { success: false, error: 'Contraseña incorrecta' };
    }
    
    // No devolver el hash
    delete usuario.contrasena_hash;
    
    return { success: true, data: usuario };
}

// 7. Obtener roles
async function obtenerRoles() {
    const query = `SELECT id, nombre FROM rol ORDER BY id`;
    const result = await pool.query(query);
    return result.rows;
}

// 8. Eliminar permanentemente (solo admin)
async function eliminarPermanente(id) {
    const query = `DELETE FROM usuario WHERE id = $1 RETURNING id, nombre`;
    const result = await pool.query(query, [id]);
    return result.rows[0];
}

module.exports = {
    crear,
    listar,
    obtenerPorId,
    actualizar,
    eliminar,
    eliminarPermanente,
    obtenerRoles,
    login,
};