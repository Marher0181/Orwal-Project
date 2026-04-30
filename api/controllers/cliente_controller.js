const clienteModel = require('../models/cliente_model');

async function crearCliente(req, res) {
    try {
        const { nombre, telefono } = req.body;
        
        if (!nombre || !telefono) {
            return res.status(400).json({
                success: false,
                error: 'Faltan campos obligatorios: nombre, telefono'
            });
        }
        
        const cliente = await clienteModel.crear(req.body);
        res.status(201).json({ success: true, data: cliente });
        
    } catch (error) {
        if (error.code === '23505') {
            return res.status(400).json({ success: false, error: 'El teléfono ya está registrado' });
        }
        res.status(500).json({ success: false, error: error.message });
    }
}

async function listarClientes(req, res) {
    try {
        const clientes = await clienteModel.listar();
        res.status(200).json({ success: true, data: clientes });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

async function obtenerCliente(req, res) {
    try {
        const id = parseInt(req.params.id);
        if (isNaN(id)) {
            return res.status(400).json({ success: false, error: 'ID inválido' });
        }
        
        const cliente = await clienteModel.obtenerPorId(id);
        if (!cliente) {
            return res.status(404).json({ success: false, error: 'Cliente no encontrado' });
        }
        
        res.status(200).json({ success: true, data: cliente });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

async function actualizarCliente(req, res) {
    try {
        const id = parseInt(req.params.id);
        if (isNaN(id)) {
            return res.status(400).json({ success: false, error: 'ID inválido' });
        }
        
        const cliente = await clienteModel.actualizar(id, req.body);
        if (!cliente) {
            return res.status(404).json({ success: false, error: 'Cliente no encontrado' });
        }
        
        res.status(200).json({ success: true, data: cliente });
    } catch (error) {
        if (error.code === '23505') {
            return res.status(400).json({ success: false, error: 'El teléfono ya está registrado por otro cliente' });
        }
        res.status(500).json({ success: false, error: error.message });
    }
}

async function eliminarCliente(req, res) {
    try {
        const id = parseInt(req.params.id);
        if (isNaN(id)) {
            return res.status(400).json({ success: false, error: 'ID inválido' });
        }
        
        const cliente = await clienteModel.eliminar(id);
        if (!cliente) {
            return res.status(404).json({ success: false, error: 'Cliente no encontrado' });
        }
        
        res.status(200).json({ success: true, message: 'Cliente desactivado correctamente', data: cliente });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

module.exports = {
    crearCliente,
    listarClientes,
    obtenerCliente,
    actualizarCliente,
    eliminarCliente
};