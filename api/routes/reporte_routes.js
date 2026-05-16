const express = require('express');
const router = express.Router();
const reporteController = require('../controllers/reporte_controller');
const auth = require('../middlewares/auth');

// Ruta protegida, solo Admin puede ver reportes financieros (ajusta los roles si es necesario)
router.get('/consolidado', auth.verificarToken, auth.verificarRol(['Admin']), reporteController.obtenerConsolidado);

module.exports = router;