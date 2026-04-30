const express = require('express');
const router = express.Router();
const productoController = require('../controllers/producto_controller');
const auth = require('../middlewares/auth');

router.post('/', auth.verificarToken, auth.verificarRol(['Admin']), productoController.crearProducto);
router.get('/', auth.verificarToken, productoController.listarProductos);
router.get('/:id', auth.verificarToken, productoController.obtenerProducto);
router.put('/:id', auth.verificarToken, auth.verificarRol(['Admin']), productoController.actualizarProducto);
router.delete('/:id', auth.verificarToken, auth.verificarRol(['Admin']), productoController.eliminarProducto);

module.exports = router;