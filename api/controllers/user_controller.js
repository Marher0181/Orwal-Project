const userModel = require('../models/user_model');
const jwt = require('jsonwebtoken');

// Crear usuario (solo Admin puede acceder - la protección va en la ruta)
async function crearUsuario(req, res) {
    try {
        const { nombre, telefono, email, rol_id, contrasena } = req.body;
        
        if (!nombre || !telefono || !rol_id || !contrasena) {
            return res.status(400).json({
                success: false,
                error: 'Faltan campos: nombre, telefono, rol_id, contrasena'
            });
        }
        
        if (contrasena.length < 6) {
            return res.status(400).json({
                success: false,
                error: 'La contraseña debe tener al menos 6 caracteres'
            });
        }
        
        const usuario = await userModel.crear(req.body);
        res.status(201).json({ success: true, data: usuario });
        
    } catch (error) {
        if (error.code === '23505') {
            return res.status(400).json({ success: false, error: 'El teléfono o email ya existe' });
        }
        res.status(500).json({ success: false, error: error.message });
    }
}

// Listar usuarios (solo Admin)
async function listarUsuarios(req, res) {
    try {
        const usuarios = await userModel.listar();
        res.status(200).json({ success: true, data: usuarios });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

// Obtener usuario por ID (Admin o el mismo usuario)
async function obtenerUsuario(req, res) {
    try {
        const id = parseInt(req.params.id);
        if (isNaN(id)) {
            return res.status(400).json({ success: false, error: 'ID inválido' });
        }
        
        const usuario = await userModel.obtenerPorId(id);
        if (!usuario) {
            return res.status(404).json({ success: false, error: 'Usuario no encontrado' });
        }
        
        res.status(200).json({ success: true, data: usuario });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

// Buscar por teléfono (solo Admin)
async function buscarPorTelefono(req, res) {
    try {
        const { telefono } = req.params;
        const usuario = await userModel.obtenerPorTelefono(telefono);
        res.status(200).json({ success: true, data: usuario || null });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}
// api/controllers/user_controller.js - función actualizarUsuario

async function actualizarUsuario(req, res) {
    try {
        const id = parseInt(req.params.id);
        if (isNaN(id)) {
            return res.status(400).json({ success: false, error: 'ID inválido' });
        }
        
        const usuario = await userModel.actualizar(id, req.body);
        if (!usuario) {
            return res.status(404).json({ success: false, error: 'Usuario no encontrado' });
        }
        
        res.status(200).json({ success: true, data: usuario });
    } catch (error) {
        if (error.code === '23505') {
            return res.status(400).json({ success: false, error: 'El teléfono o email ya existe' });
        }
        res.status(500).json({ success: false, error: error.message });
    }
}
// Eliminar usuario (borrado lógico) - solo Admin
async function eliminarUsuario(req, res) {
    try {
        const id = parseInt(req.params.id);
        if (isNaN(id)) {
            return res.status(400).json({ success: false, error: 'ID inválido' });
        }
        
        const usuario = await userModel.eliminar(id);
        if (!usuario) {
            return res.status(404).json({ success: false, error: 'Usuario no encontrado o ya eliminado' });
        }
        
        res.status(200).json({ success: true, message: 'Usuario eliminado correctamente', data: usuario });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

// Eliminar usuario permanentemente - solo Admin
async function eliminarUsuarioPermanente(req, res) {
    try {
        const id = parseInt(req.params.id);
        if (isNaN(id)) {
            return res.status(400).json({ success: false, error: 'ID inválido' });
        }
        
        const usuario = await userModel.eliminarPermanente(id);
        if (!usuario) {
            return res.status(404).json({ success: false, error: 'Usuario no encontrado' });
        }
        
        res.status(200).json({ success: true, message: 'Usuario eliminado permanentemente', data: usuario });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

// Obtener roles (público)
async function obtenerRoles(req, res) {
    try {
        const roles = await userModel.obtenerRoles();
        res.status(200).json({ success: true, data: roles });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

// LOGIN - genera JWT 🆕
async function loginUsuario(req, res) {
    try {
        const { identificador, contrasena } = req.body;
        
        if (!identificador || !contrasena) {
            return res.status(400).json({
                success: false,
                error: 'Faltan campos: identificador (teléfono o email) y contrasena'
            });
        }
        
        const result = await userModel.login(identificador, contrasena);
        
        if (!result.success) {
            return res.status(401).json({ success: false, error: result.error });
        }
        
        // Generar JWT
        const payload = {
            id: result.data.id,
            nombre: result.data.nombre,
            telefono: result.data.telefono,
            email: result.data.email,
            rol_id: result.data.rol_id,
            rol_nombre: result.data.rol_nombre
        };
        
        const token = jwt.sign(payload, process.env.JWT_SECRET, {
            expiresIn: process.env.JWT_EXPIRES_IN || '8h'
        });
        
        res.status(200).json({
            success: true,
            data: {
                usuario: payload,
                token: token,
                expiresIn: process.env.JWT_EXPIRES_IN || '8h'
            },
            message: 'Login exitoso'
        });
        
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

// Obtener perfil propio (usando el token) 🆕
async function obtenerMiPerfil(req, res) {
    try {
        const usuario = await userModel.obtenerPorId(req.usuario.id);
        if (!usuario) {
            return res.status(404).json({ success: false, error: 'Usuario no encontrado' });
        }
        res.status(200).json({ success: true, data: usuario });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

module.exports = {
    crearUsuario,
    listarUsuarios,
    obtenerUsuario,
    buscarPorTelefono,
    actualizarUsuario,
    eliminarUsuario,
    eliminarUsuarioPermanente,
    obtenerRoles,
    loginUsuario,
    obtenerMiPerfil,
};