const inventarioModel = require('../models/inventario_model');

async function getStock(req, res) {
    try {
        const stock = await inventarioModel.obtenerStock();
        res.status(200).json({ success: true, data: stock });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

async function getAlmacenes(req, res) {
    try {
        const almacenes = await inventarioModel.obtenerAlmacenes();
        res.status(200).json({ success: true, data: almacenes });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

async function crearMovimiento(req, res) {
    try {
        const usuario_id = req.user.id; 
        const { almacen_id, producto_id, tipo_movimiento, cantidad, motivo } = req.body;
        
        await inventarioModel.registrarMovimiento({
            almacen_id, producto_id, usuario_id, tipo_movimiento, cantidad, motivo
        });

        res.status(201).json({ success: true, message: "Movimiento registrado con éxito" });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

module.exports = { getStock, getAlmacenes, crearMovimiento };