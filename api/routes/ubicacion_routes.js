const express = require('express');
const router = express.Router();
const ubicacionController = require('../controllers/ubicacion_controller');
const auth = require('../middlewares/auth');

router.post('/', auth.verificarToken, auth.verificarRol(['Admin', 'Receptor']), ubicacionController.crearUbicacion);
router.get('/cliente/:cliente_id', auth.verificarToken, ubicacionController.listarUbicacionesCliente);
router.get('/:id', auth.verificarToken, ubicacionController.obtenerUbicacion);
router.put('/:id', auth.verificarToken, auth.verificarRol(['Admin', 'Receptor']), ubicacionController.actualizarUbicacion);
router.delete('/:id', auth.verificarToken, auth.verificarRol(['Admin', 'Receptor']), ubicacionController.eliminarUbicacion);

module.exports = router;