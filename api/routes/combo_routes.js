const express = require('express');
const router = express.Router();
const comboController = require('../controllers/combo_controller');
const auth = require('../middlewares/auth');

// Rutas públicas o con autenticación según necesidad

// Obtener productos (para selectores) - accesible para receptores y admin
router.get('/productos', 
    auth.verificarToken, 
    auth.verificarRol(['Admin', 'Receptor']), 
    comboController.obtenerProductos
);

// Verificar stock de un combo
router.get('/:id/verificar-stock', 
    auth.verificarToken, 
    auth.verificarRol(['Admin', 'Receptor']), 
    comboController.verificarStockCombo
);

// Listar combos
router.get('/', 
    auth.verificarToken, 
    auth.verificarRol(['Admin', 'Receptor']), 
    comboController.listarCombos
);

// Obtener combo por ID
router.get('/:id', 
    auth.verificarToken, 
    auth.verificarRol(['Admin', 'Receptor']), 
    comboController.obtenerCombo
);

// Crear combo (solo Admin)
router.post('/', 
    auth.verificarToken, 
    auth.verificarRol(['Admin']), 
    comboController.crearCombo
);

// Actualizar combo (solo Admin)
router.put('/:id', 
    auth.verificarToken, 
    auth.verificarRol(['Admin']), 
    comboController.actualizarCombo
);

// Actualizar productos de un combo (solo Admin)
router.put('/:id/productos', 
    auth.verificarToken, 
    auth.verificarRol(['Admin']), 
    comboController.actualizarProductosCombo
);

// Activar combo (solo Admin)
router.patch('/:id/activar', 
    auth.verificarToken, 
    auth.verificarRol(['Admin']), 
    comboController.activarCombo
);

// Eliminar combo (desactivar - solo Admin)
router.delete('/:id', 
    auth.verificarToken, 
    auth.verificarRol(['Admin']), 
    comboController.eliminarCombo
);

// Eliminar combo permanentemente (solo Admin - con cuidado)
router.delete('/:id/permanente', 
    auth.verificarToken, 
    auth.verificarRol(['Admin']), 
    comboController.eliminarComboPermanente
);

module.exports = router;