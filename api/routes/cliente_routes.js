const express = require('express');
const router = express.Router();
const clienteController = require('../controllers/cliente_controller');
const auth = require('../middlewares/auth');

router.post('/', auth.verificarToken, auth.verificarRol(['Admin', 'Receptor']), clienteController.crearCliente);
router.get('/', auth.verificarToken, auth.verificarRol(['Admin', 'Receptor', 'Piloto']), clienteController.listarClientes);
router.get('/:id', auth.verificarToken, auth.verificarRol(['Admin', 'Receptor', 'Piloto']), clienteController.obtenerCliente);
router.put('/:id', auth.verificarToken, auth.verificarRol(['Admin', 'Receptor']), clienteController.actualizarCliente);
router.delete('/:id', auth.verificarToken, auth.verificarRol(['Admin']), clienteController.eliminarCliente);

module.exports = router;