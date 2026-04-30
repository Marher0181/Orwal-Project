const productoModel = require('../models/producto_model');

async function crearProducto(req, res) {
    try {
        const { nombre, precio } = req.body;
        if (!nombre || precio === undefined) {
            return res.status(400).json({ success: false, error: 'Faltan campos obligatorios: nombre, precio' });
        }
        const producto = await productoModel.crear(req.body);
        res.status(201).json({ success: true, data: producto });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

async function listarProductos(req, res) {
    try {
        const productos = await productoModel.listar();
        res.status(200).json({ success: true, data: productos });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

async function obtenerProducto(req, res) {
    try {
        const id = parseInt(req.params.id);
        if (isNaN(id)) return res.status(400).json({ success: false, error: 'ID inválido' });
        const producto = await productoModel.obtenerPorId(id);
        if (!producto) return res.status(404).json({ success: false, error: 'Producto no encontrado' });
        res.status(200).json({ success: true, data: producto });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

async function actualizarProducto(req, res) {
    try {
        const id = parseInt(req.params.id);
        if (isNaN(id)) return res.status(400).json({ success: false, error: 'ID inválido' });
        const producto = await productoModel.actualizar(id, req.body);
        if (!producto) return res.status(404).json({ success: false, error: 'Producto no encontrado' });
        res.status(200).json({ success: true, data: producto });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

async function eliminarProducto(req, res) {
    try {
        const id = parseInt(req.params.id);
        if (isNaN(id)) return res.status(400).json({ success: false, error: 'ID inválido' });
        const producto = await productoModel.eliminar(id);
        if (!producto) return res.status(404).json({ success: false, error: 'Producto no encontrado' });
        res.status(200).json({ success: true, message: 'Producto eliminado correctamente' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

module.exports = { crearProducto, listarProductos, obtenerProducto, actualizarProducto, eliminarProducto };