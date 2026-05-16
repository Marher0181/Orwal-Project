const reporteModel = require('../models/reporte_model');

async function obtenerConsolidado(req, res) {
    try {
        const { fecha_inicio, fecha_fin } = req.query;
        const reporte = await reporteModel.obtenerReporteConsolidado(fecha_inicio, fecha_fin);
        
        res.status(200).json({
            success: true,
            data: reporte,
            message: 'Reporte generado con éxito'
        });
    } catch (error) {
        console.error('Error al generar reporte:', error);
        res.status(500).json({
            success: false,
            message: 'Error interno al generar el reporte',
            error: error.message
        });
    }
}

module.exports = { obtenerConsolidado };