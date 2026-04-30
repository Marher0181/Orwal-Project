const pedidoModel = require('../models/pedido_model');

async function crearPedido(req, res) {
    try {
        const { cliente_id, ubicacion_id, productos } = req.body;
        if (!cliente_id || !ubicacion_id || !productos || productos.length === 0) {
            return res.status(400).json({ success: false, error: 'Datos incompletos' });
        }
        const pedido = await pedidoModel.crear({ ...req.body, receptor_id: req.usuario.id });
        res.status(201).json({ success: true, data: pedido });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

async function listarPedidos(req, res) {
    try {
        const pedidos = await pedidoModel.listar();
        res.status(200).json({ success: true, data: pedidos });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

async function obtenerDetallePedido(req, res) {
    try {
        const detalle = await pedidoModel.obtenerDetalle(req.params.id);
        res.status(200).json({ success: true, data: detalle });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

async function asignarPilotoPedido(req, res) {
    try {
        const id = parseInt(req.params.id);
        const { piloto_id } = req.body;
        if (!piloto_id) return res.status(400).json({ success: false, error: 'Falta piloto_id' });

        const pedido = await pedidoModel.asignarPiloto(id, piloto_id);
        if (!pedido) return res.status(404).json({ success: false, error: 'Pedido no encontrado' });

        res.status(200).json({ success: true, data: pedido });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

async function cambiarEstadoPedido(req, res) {
    try {
        const id = parseInt(req.params.id);
        const { estado_id, motivo } = req.body;
        
        if (!estado_id) return res.status(400).json({ success: false, error: 'Falta estado_id' });
        if (estado_id === 4 && !motivo) return res.status(400).json({ success: false, error: 'Motivo requerido para estado No entregado' });

        const pedido = await pedidoModel.cambiarEstado(id, estado_id, motivo);
        if (!pedido) return res.status(404).json({ success: false, error: 'Pedido no encontrado' });

        res.status(200).json({ success: true, data: pedido });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}


async function obtenerHistorialPedido(req, res) {
    try {
        const id = parseInt(req.params.id);
        if (isNaN(id)) return res.status(400).json({ success: false, error: 'ID inválido' });

        const historial = await pedidoModel.obtenerHistorial(id);
        res.status(200).json({ success: true, data: historial });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

module.exports = { crearPedido, listarPedidos, obtenerDetallePedido, asignarPilotoPedido, cambiarEstadoPedido, obtenerHistorialPedido };