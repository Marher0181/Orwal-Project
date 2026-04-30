const express = require('express');
const router = express.Router();
const reporteController = require('../controllers/reporte_controller');
const auth = require('../middlewares/auth');

// Endpoint: GET /api/reportes/cuadre?fecha=2024-05-20&expendio_id=1
router.get('/cuadre', auth.verificarToken, auth.verificarRol(['Admin']), reporteController.generarCuadreCierre);

module.exports = router;