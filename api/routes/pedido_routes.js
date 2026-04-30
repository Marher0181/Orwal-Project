const express = require('express');
const router = express.Router();
const pedidoController = require('../controllers/pedido_controller');
const auth = require('../middlewares/auth');

router.post('/', auth.verificarToken, auth.verificarRol(['Admin', 'Receptor']), pedidoController.crearPedido);
router.get('/', auth.verificarToken, pedidoController.listarPedidos);
router.get('/:id/detalle', auth.verificarToken, pedidoController.obtenerDetallePedido);

router.put('/:id/asignar-piloto', auth.verificarToken, auth.verificarRol(['Admin']), pedidoController.asignarPilotoPedido);
router.put('/:id/estado', auth.verificarToken, auth.verificarRol(['Admin', 'Piloto']), pedidoController.cambiarEstadoPedido);
router.get('/:id/historial', auth.verificarToken, pedidoController.obtenerHistorialPedido);
module.exports = router;