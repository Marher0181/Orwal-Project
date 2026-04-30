const reporteModel = require('../models/reporte_model');

async function generarCuadreCierre(req, res) {
    try {
        const { fecha, expendio_id } = req.query;
        
        if (!fecha) {
            return res.status(400).json({ success: false, error: 'La fecha es obligatoria (YYYY-MM-DD)' });
        }

        const reporte = await reporteModel.obtenerCuadreCierre(fecha, expendio_id);
        
        // Calcular el Gran Total para hacerlo más fácil al frontend
        const gran_total = reporte.reduce((sum, item) => sum + parseFloat(item.total_recaudado), 0);

        res.status(200).json({ 
            success: true, 
            data: {
                fecha,
                expendio_id: expendio_id || 'Todos',
                detalle_pagos: reporte,
                gran_total
            } 
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

module.exports = { generarCuadreCierre };