const express = require('express');
const router = express.Router();
const userController = require('../controllers/user_controller');
const auth = require('../middlewares/auth');

router.post('/login', userController.loginUsuario);
router.get('/roles', userController.obtenerRoles);

router.get('/perfil', auth.verificarToken, userController.obtenerMiPerfil);

router.post('/', auth.verificarToken, auth.verificarRol(['Admin']), userController.crearUsuario);
router.get('/', auth.verificarToken, auth.verificarRol(['Admin']), userController.listarUsuarios);
router.get('/telefono/:telefono', auth.verificarToken, auth.verificarRol(['Admin']), userController.buscarPorTelefono);
router.delete('/:id/permanente', auth.verificarToken, auth.verificarRol(['Admin']), userController.eliminarUsuarioPermanente);
router.delete('/:id', auth.verificarToken, auth.verificarRol(['Admin']), userController.eliminarUsuario);

router.get('/:id', auth.verificarToken, auth.verificarMismoUsuarioOAdmin, userController.obtenerUsuario);

router.put('/:id', auth.verificarToken, auth.verificarMismoUsuarioOAdmin, userController.actualizarUsuario);
router.get('/pilotos/activos', auth.verificarToken, auth.verificarRol(['Admin']), userController.obtenerPilotos);

module.exports = router;