const bcrypt = require('bcrypt');

async function generarHash() {
    const contrasena = 'admin123'; 
    
    const hash = await bcrypt.hash(contrasena, 10);
    
    console.log('\n📋 CONTRASEÑA:', contrasena);
    console.log('🔑 HASH:', hash);
    console.log('\n📝 Ejecuta este SQL en PostgreSQL:\n');
    console.log(`UPDATE usuario SET contrasena_hash = '${hash}' WHERE email = 'admin123@entregas.com';`);
    console.log(`-- O para crear nuevo admin:\n`);
    console.log(`INSERT INTO usuario (nombre, telefono, email, rol_id, contrasena_hash, activo)
VALUES (
    'Admin Sistema',
    '+56900000000',
    'admin@entregas.com',
    3,
    '${hash}',
    true
);`);
}

generarHash();