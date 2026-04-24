const express = require('express');
const cors = require('cors');
require('dotenv').config();

const userRoutes = require('./routes/user_routes');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Rutas
app.use('/api/usuarios', userRoutes);

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
    console.log(`\nPÚBLICOS:`);
    console.log(`   POST   /api/usuarios/login (teléfono o email + contraseña)`);
    console.log(`   GET    /api/usuarios/roles`);
    console.log(`\nPROTEGIDOS (requieren token):`);
    console.log(`   GET    /api/usuarios/perfil (cualquier usuario autenticado)`);
    console.log(`   GET    /api/usuarios (solo Admin)`);
    console.log(`   POST   /api/usuarios (solo Admin)`);
    console.log(`   GET    /api/usuarios/:id (Admin o mismo usuario)`);
    console.log(`   PUT    /api/usuarios/:id (Admin o mismo usuario)`);
    console.log(`   DELETE /api/usuarios/:id (solo Admin)`);
});