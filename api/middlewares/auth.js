const jwt = require('jsonwebtoken');

// Verificar token JWT
function verificarToken(req, res, next) {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ 
            success: false, 
            error: 'Acceso denegado. Token no proporcionado' 
        });
    }
    
    const token = authHeader.split(' ')[1];
    
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.usuario = decoded; // { id, nombre, telefono, rol_id, rol_nombre }
        next();
    } catch (error) {
        if (error.name === 'TokenExpiredError') {
            return res.status(401).json({ success: false, error: 'Token expirado' });
        }
        return res.status(403).json({ success: false, error: 'Token inválido' });
    }
}

// Verificar que el usuario tenga rol específico
function verificarRol(rolesPermitidos = []) {
    return (req, res, next) => {
        if (!req.usuario) {
            return res.status(401).json({ success: false, error: 'No autenticado' });
        }
        
        const rolUsuario = req.usuario.rol_nombre;
        
        if (!rolesPermitidos.includes(rolUsuario)) {
            return res.status(403).json({ 
                success: false, 
                error: `Acceso denegado. Se requiere rol: ${rolesPermitidos.join(' o ')}` 
            });
        }
        
        next();
    };
}

// Verificar que sea el mismo usuario o Admin
function verificarMismoUsuarioOAdmin(req, res, next) {
    const idParam = parseInt(req.params.id);
    const usuarioId = req.usuario.id;
    const rolUsuario = req.usuario.rol_nombre;
    
    if (rolUsuario === 'Admin' || idParam === usuarioId) {
        next();
    } else {
        res.status(403).json({ 
            success: false, 
            error: 'No tienes permiso para acceder a este recurso' 
        });
    }
}

module.exports = {
    verificarToken,
    verificarRol,
    verificarMismoUsuarioOAdmin,
};