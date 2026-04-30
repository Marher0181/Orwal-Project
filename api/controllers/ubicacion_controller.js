const ubicacionModel = require('../models/ubicacion_model');

async function crearUbicacion(req, res) {
    try {
        const { cliente_id, direccion } = req.body;
        if (!cliente_id || !direccion) {
            return res.status(400).json({ success: false, error: 'Faltan campos: cliente_id, direccion' });
        }
        const ubicacion = await ubicacionModel.crear(req.body);
        res.status(201).json({ success: true, data: ubicacion });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

async function listarUbicacionesCliente(req, res) {
    try {
        const cliente_id = parseInt(req.params.cliente_id);
        const ubicaciones = await ubicacionModel.listarPorCliente(cliente_id);
        res.status(200).json({ success: true, data: ubicaciones });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

async function obtenerUbicacion(req, res) {
    try {
        const id = parseInt(req.params.id);
        const ubicacion = await ubicacionModel.obtenerPorId(id);
        if (!ubicacion) return res.status(404).json({ success: false, error: 'Ubicacion no encontrada' });
        res.status(200).json({ success: true, data: ubicacion });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

async function actualizarUbicacion(req, res) {
    try {
        const id = parseInt(req.params.id);
        const ubicacion = await ubicacionModel.actualizar(id, req.body);
        if (!ubicacion) return res.status(404).json({ success: false, error: 'Ubicacion no encontrada' });
        res.status(200).json({ success: true, data: ubicacion });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

async function eliminarUbicacion(req, res) {
    try {
        const id = parseInt(req.params.id);
        const result = await ubicacionModel.eliminar(id);
        if (!result) return res.status(404).json({ success: false, error: 'Ubicacion no encontrada' });
        res.status(200).json({ success: true, message: 'Ubicacion eliminada' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

module.exports = { crearUbicacion, listarUbicacionesCliente, obtenerUbicacion, actualizarUbicacion, eliminarUbicacion };