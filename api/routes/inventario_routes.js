const express = require('express');
const router = express.Router();
const inventarioController = require('../controllers/inventario_controller');
const auth = require('../middlewares/auth');

router.get('/stock', auth.verificarToken, inventarioController.getStock);
router.get('/almacenes', auth.verificarToken, inventarioController.getAlmacenes);
router.post('/movimiento', auth.verificarToken, auth.verificarRol(['Admin']), inventarioController.crearMovimiento);

module.exports = router;