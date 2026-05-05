const comboModel = require('../models/combo_model');

// Crear combo
async function crearCombo(req, res) {
    try {
        const { nombre, descripcion, productos } = req.body;
        const creado_por = req.usuario.id; // del token
        
        if (!nombre || !productos || !productos.length) {
            return res.status(400).json({
                success: false,
                error: 'Faltan campos: nombre y productos son requeridos'
            });
        }
        
        // Validar que cada producto tenga id y cantidad
        for (const prod of productos) {
            if (!prod.producto_id || !prod.cantidad || prod.cantidad <= 0) {
                return res.status(400).json({
                    success: false,
                    error: 'Cada producto debe tener producto_id y cantidad > 0'
                });
            }
        }
        
        const combo = await comboModel.crear({ nombre, descripcion, productos, creado_por });
        res.status(201).json({ success: true, data: combo });
        
    } catch (error) {
        console.error('Error al crear combo:', error);
        res.status(500).json({ success: false, error: error.message });
    }
}

// Listar combos
async function listarCombos(req, res) {
    try {
        const { incluir_inactivos } = req.query;
        const soloActivos = incluir_inactivos !== 'true';
        
        const combos = await comboModel.listar(soloActivos);
        res.status(200).json({ success: true, data: combos });
        
    } catch (error) {
        console.error('Error al listar combos:', error);
        res.status(500).json({ success: false, error: error.message });
    }
}

// Obtener combo por ID
async function obtenerCombo(req, res) {
    try {
        const id = parseInt(req.params.id);
        
        if (isNaN(id)) {
            return res.status(400).json({ success: false, error: 'ID inválido' });
        }
        
        const combo = await comboModel.obtenerPorId(id);
        
        if (!combo) {
            return res.status(404).json({ success: false, error: 'Combo no encontrado' });
        }
        
        res.status(200).json({ success: true, data: combo });
        
    } catch (error) {
        console.error('Error al obtener combo:', error);
        res.status(500).json({ success: false, error: error.message });
    }
}

// Actualizar combo (datos básicos)
async function actualizarCombo(req, res) {
    try {
        const id = parseInt(req.params.id);
        
        if (isNaN(id)) {
            return res.status(400).json({ success: false, error: 'ID inválido' });
        }
        
        const { nombre, descripcion, activo } = req.body;
        
        const combo = await comboModel.actualizar(id, { nombre, descripcion, activo });
        
        if (!combo) {
            return res.status(404).json({ success: false, error: 'Combo no encontrado' });
        }
        
        res.status(200).json({ success: true, data: combo, message: 'Combo actualizado correctamente' });
        
    } catch (error) {
        console.error('Error al actualizar combo:', error);
        res.status(500).json({ success: false, error: error.message });
    }
}

// Actualizar productos de un combo
async function actualizarProductosCombo(req, res) {
    try {
        const id = parseInt(req.params.id);
        
        if (isNaN(id)) {
            return res.status(400).json({ success: false, error: 'ID inválido' });
        }
        
        const { productos } = req.body;
        
        if (!productos || !productos.length) {
            return res.status(400).json({ success: false, error: 'Productos requeridos' });
        }
        
        // Validar productos
        for (const prod of productos) {
            if (!prod.producto_id || !prod.cantidad || prod.cantidad <= 0) {
                return res.status(400).json({
                    success: false,
                    error: 'Cada producto debe tener producto_id y cantidad > 0'
                });
            }
        }
        
        const result = await comboModel.actualizarProductos(id, productos);
        res.status(200).json({ success: true, data: result });
        
    } catch (error) {
        console.error('Error al actualizar productos del combo:', error);
        res.status(500).json({ success: false, error: error.message });
    }
}

// Eliminar combo (desactivar)
async function eliminarCombo(req, res) {
    try {
        const id = parseInt(req.params.id);
        
        if (isNaN(id)) {
            return res.status(400).json({ success: false, error: 'ID inválido' });
        }
        
        const combo = await comboModel.eliminar(id);
        
        if (!combo) {
            return res.status(404).json({ success: false, error: 'Combo no encontrado o ya está inactivo' });
        }
        
        res.status(200).json({ success: true, message: combo.message, data: combo });
        
    } catch (error) {
        console.error('Error al eliminar combo:', error);
        res.status(500).json({ success: false, error: error.message });
    }
}

// Activar combo
async function activarCombo(req, res) {
    try {
        const id = parseInt(req.params.id);
        
        if (isNaN(id)) {
            return res.status(400).json({ success: false, error: 'ID inválido' });
        }
        
        const combo = await comboModel.activar(id);
        
        if (!combo) {
            return res.status(404).json({ success: false, error: 'Combo no encontrado' });
        }
        
        res.status(200).json({ success: true, message: combo.message, data: combo });
        
    } catch (error) {
        console.error('Error al activar combo:', error);
        res.status(500).json({ success: false, error: error.message });
    }
}

// Eliminar combo permanentemente
async function eliminarComboPermanente(req, res) {
    try {
        const id = parseInt(req.params.id);
        
        if (isNaN(id)) {
            return res.status(400).json({ success: false, error: 'ID inválido' });
        }
        
        const combo = await comboModel.eliminarPermanente(id);
        
        if (!combo) {
            return res.status(404).json({ success: false, error: 'Combo no encontrado' });
        }
        
        res.status(200).json({ success: true, message: 'Combo eliminado permanentemente', data: combo });
        
    } catch (error) {
        console.error('Error al eliminar combo permanentemente:', error);
        res.status(500).json({ success: false, error: error.message });
    }
}

// Obtener todos los productos (para selector en frontend)
async function obtenerProductos(req, res) {
    try {
        const productos = await comboModel.obtenerProductos();
        res.status(200).json({ success: true, data: productos });
        
    } catch (error) {
        console.error('Error al obtener productos:', error);
        res.status(500).json({ success: false, error: error.message });
    }
}

// Verificar stock de un combo
async function verificarStockCombo(req, res) {
    try {
        const id = parseInt(req.params.id);
        const cantidad = parseInt(req.query.cantidad) || 1;
        
        if (isNaN(id)) {
            return res.status(400).json({ success: false, error: 'ID inválido' });
        }
        
        const stockInfo = await comboModel.verificarStock(id, cantidad);
        res.status(200).json({ success: true, data: stockInfo });
        
    } catch (error) {
        console.error('Error al verificar stock:', error);
        res.status(500).json({ success: false, error: error.message });
    }
}

module.exports = {
    crearCombo,
    listarCombos,
    obtenerCombo,
    actualizarCombo,
    actualizarProductosCombo,
    eliminarCombo,
    activarCombo,
    eliminarComboPermanente,
    obtenerProductos,
    verificarStockCombo
};