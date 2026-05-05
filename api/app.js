const express = require('express');
const cors = require('cors');
require('dotenv').config();

const userRoutes = require('./routes/user_routes');
const clienteRoutes = require('./routes/cliente_routes');
const productoRoutes = require('./routes/producto_routes');
const ubicacionRoutes = require('./routes/ubicacion_routes');
const pedidoRoutes = require('./routes/pedido_routes');
const reporteRoutes = require('./routes/reporte_routes')

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Rutas
app.use('/api/usuarios', userRoutes);
app.use('/api/clientes', clienteRoutes);
app.use('/api/productos', productoRoutes);
app.use('/api/ubicaciones', ubicacionRoutes);
app.use('/api/pedidos', pedidoRoutes);
app.use('/api/reportes', reporteRoutes);
app.use('/api/combos', comboRoutes);
app.use('/api/pedidos', pedidoRoutes);

// Ruta de prueba pública
app.get('/', (req, res) => {
    res.json({ 
        message: 'API Gestor de Entregas funcionando',
        version: '1.0.0',
        endpoints: {
            auth: 'POST /api/usuarios/login',
            usuarios: 'GET/POST/PUT/DELETE /api/usuarios'
        }
    });
});

app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ success: false, error: 'Error interno del servidor' });
});

app.listen(PORT, () => {
    console.log(`Servidor corriendo en http://localhost:${PORT}`);
    console.log(`Endpoints disponibles:`);
    console.log(``);
    console.log(`USUARIOS:`);
    console.log(`\nPUBLICOS:`);
    console.log(`   POST   /api/usuarios/login (telefono o email + contrasena)`);
    console.log(`   GET    /api/usuarios/roles`);
    console.log(`\nPROTEGIDOS (requieren token):`);
    console.log(`   GET    /api/usuarios/perfil (cualquier usuario autenticado)`);
    console.log(`   GET    /api/usuarios (solo Admin)`);
    console.log(`   POST   /api/usuarios (solo Admin)`);
    console.log(`   GET    /api/usuarios/telefono/:telefono (solo Admin)`);
    console.log(`   GET    /api/usuarios/:id (Admin o mismo usuario)`);
    console.log(`   PUT    /api/usuarios/:id (Admin o mismo usuario)`);
    console.log(`   DELETE /api/usuarios/:id (solo Admin - desactiva)`);
    console.log(`   DELETE /api/usuarios/:id/permanente (solo Admin - elimina fisicamente)`);
    console.log(``);
    console.log(`COMBOS:`);
    console.log(`\nPROTEGIDOS (requieren token):`);
    console.log(`   GET    /api/combos (Admin o Receptor - lista combos)`);
    console.log(`   GET    /api/combos/productos (Admin o Receptor - lista productos disponibles)`);
    console.log(`   GET    /api/combos/:id (Admin o Receptor - obtiene combo por ID)`);
    console.log(`   GET    /api/combos/:id/verificar-stock?cantidad=1 (Admin o Receptor - verifica stock)`);
    console.log(`   POST   /api/combos (solo Admin - crea combo)`);
    console.log(`   PUT    /api/combos/:id (solo Admin - actualiza datos basicos)`);
    console.log(`   PUT    /api/combos/:id/productos (solo Admin - actualiza composicion)`);
    console.log(`   PATCH  /api/combos/:id/activar (solo Admin - reactiva combo)`);
    console.log(`   DELETE /api/combos/:id (solo Admin - desactiva combo)`);
    console.log(`   DELETE /api/combos/:id/permanente (solo Admin - elimina fisicamente)`);
    console.log(``);
    console.log(`PEDIDOS:`);
    console.log(`\nPROTEGIDOS (requieren token):`);
    console.log(`   GET    /api/pedidos (Admin, Receptor o Piloto - lista pedidos con filtros)`);
    console.log(`   GET    /api/pedidos/dashboard (Admin o Receptor - dashboard del dia)`);
    console.log(`   GET    /api/pedidos/reportes/cuadre (Admin o Receptor - reporte de cuadre por fecha)`);
    console.log(`   GET    /api/pedidos/reportes/ventas-combos (Admin o Receptor - top ventas de combos)`);
    console.log(`   GET    /api/pedidos/:id (Admin, Receptor o Piloto - obtiene pedido con detalle)`);
    console.log(`   GET    /api/pedidos/:id/historial (Admin, Receptor o Piloto - historial de cambios)`);
    console.log(`   POST   /api/pedidos (Admin o Receptor - crea pedido con combos y productos)`);
    console.log(`   PUT    /api/pedidos/:id/asignar-piloto (solo Admin - asigna piloto al pedido)`);
    console.log(`   PATCH  /api/pedidos/:id/estado (Admin o Piloto - cambia estado del pedido)`);
    console.log(``);
    console.log(`ESTADOS DE PEDIDO:`);
    console.log(`   1 - Asignacion de pedido a repartidor`);
    console.log(`   2 - Repartidor en camino`);
    console.log(`   3 - Entregado`);
    console.log(`   4 - Finalizado cliente satisfecho (con motivo opcional)`);
    console.log(``);
    console.log(`ROLES DE USUARIO:`);
    console.log(`   1 - Admin (acceso total)`);
    console.log(`   2 - Piloto (puede ver pedidos asignados y cambiar estado)`);
    console.log(`   3 - Receptor (puede crear pedidos y ver reportes)`);
    console.log(``);
    console.log(`FORMAS DE PAGO:`);
    console.log(`   1 - Efectivo`);
    console.log(`   2 - Transferencia`);
    console.log(`   3 - POS Tarjeta`);
    console.log(`   4 - Cheque`);
    console.log(`   5 - Donacion`);
    console.log(`   6 - Vale`);
    console.log(`   7 - Otros`);
    console.log(``);
    console.log(`EXPENDIOS:`);
    console.log(`   1 - Barcenas`);
    console.log(`   2 - San Cristobal`);
    console.log(``);
    console.log(`AUTENTICACION:`);
    console.log(`   Incluir token en Header: Authorization: Bearer <token>`);
    console.log(``);
    console.log(`EJEMPLO DE CREACION DE COMBO:`);
    console.log(`   POST /api/combos`);
    console.log(`   {`);
    console.log(`       "nombre": "Combo Casa 25Lbs",`);
    console.log(`       "descripcion": "Cilindro 25Lbs + Regulador + 2 Abrazaderas",`);
    console.log(`       "productos": [`);
    console.log(`           {"producto_id": 1, "cantidad": 1},`);
    console.log(`           {"producto_id": 7, "cantidad": 1},`);
    console.log(`           {"producto_id": 8, "cantidad": 2}`);
    console.log(`       ]`);
    console.log(`   }`);
    console.log(``);
    console.log(`EJEMPLO DE CREACION DE PEDIDO CON COMBO:`);
    console.log(`   POST /api/pedidos`);
    console.log(`   {`);
    console.log(`       "cliente_id": 1,`);
    console.log(`       "ubicacion_id": 1,`);
    console.log(`       "forma_pago_id": 1,`);
    console.log(`       "expendio_id": 2,`);
    console.log(`       "descuento": 5.00,`);
    console.log(`       "productos": [`);
    console.log(`           {"producto_id": 6, "cantidad": 2}`);
    console.log(`       ],`);
    console.log(`       "combos": [`);
    console.log(`           {"combo_id": 1, "cantidad": 1}`);
    console.log(`       ]`);
    console.log(`   }`);
    console.log(``);
    console.log(`EJEMPLO DE RESPUESTA (Pedido creado):`);
    console.log(`   {`);
    console.log(`       "success": true,`);
    console.log(`       "data": {`);
    console.log(`           "pedido_id": 7,`);
    console.log(`           "total": 175.00,`);
    console.log(`           "mensaje": "Pedido creado exitosamente"`);
    console.log(`       }`);
    console.log(`   }`);
    console.log(``);
    console.log(`Servidor listo para recibir peticiones`);
});