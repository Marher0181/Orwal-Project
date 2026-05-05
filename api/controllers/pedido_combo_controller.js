const pedidoComboModel = require('../models/pedido_combo_model');
const comboModel = require('../models/combo_model');

// 1. Crear pedido con combos
async function crearPedido(req, res) {
    try {
        const { 
            cliente_id, ubicacion_id, forma_pago_id, expendio_id, 
            descuento, productos, combos 
        } = req.body;
        
        const receptor_id = req.usuario.id; // del token
        
        // Validaciones
        if (!cliente_id || !ubicacion_id || !forma_pago_id || !expendio_id) {
            return res.status(400).json({
                success: false,
                error: 'Faltan campos: cliente_id, ubicacion_id, forma_pago_id, expendio_id'
            });
        }
        
        // Si hay combos, verificar stock antes de crear
        if (combos && combos.length > 0) {
            for (const combo of combos) {
                const stockInfo = await comboModel.verificarStock(combo.combo_id, combo.cantidad);
                if (!stockInfo.vendible) {
                    const productoFaltante = stockInfo.productos.find(p => !p.suficiente);
                    return res.status(400).json({
                        success: false,
                        error: `Stock insuficiente para el combo. Producto: ${productoFaltante?.producto_nombre}`
                    });
                }
            }
        }
        
        const pedido = await pedidoComboModel.crearPedidoConCombos({
            cliente_id,
            ubicacion_id,
            receptor_id,
            forma_pago_id,
            expendio_id,
            descuento,
            productos: productos || [],
            combos: combos || []
        });
        
        res.status(201).json({ success: true, data: pedido });
        
    } catch (error) {
        console.error('Error al crear pedido:', error);
        res.status(500).json({ success: false, error: error.message });
    }
}

// 2. Obtener pedido con detalle
async function obtenerPedido(req, res) {
    try {
        const id = parseInt(req.params.id);
        
        if (isNaN(id)) {
            return res.status(400).json({ success: false, error: 'ID inválido' });
        }
        
        const pedido = await pedidoComboModel.obtenerPedidoConDetalle(id);
        
        if (!pedido) {
            return res.status(404).json({ success: false, error: 'Pedido no encontrado' });
        }
        
        res.status(200).json({ success: true, data: pedido });
        
    } catch (error) {
        console.error('Error al obtener pedido:', error);
        res.status(500).json({ success: false, error: error.message });
    }
}

// 3. Listar pedidos
async function listarPedidos(req, res) {
    try {
        const { 
            cliente_id, estado_id, expendio_id, 
            fecha_desde, fecha_hasta, limite, offset 
        } = req.query;
        
        const pedidos = await pedidoComboModel.listarPedidos({
            cliente_id: cliente_id ? parseInt(cliente_id) : null,
            estado_id: estado_id ? parseInt(estado_id) : null,
            expendio_id: expendio_id ? parseInt(expendio_id) : null,
            fecha_desde,
            fecha_hasta,
            limite: limite ? parseInt(limite) : 50,
            offset: offset ? parseInt(offset) : 0
        });
        
        res.status(200).json({ success: true, data: pedidos });
        
    } catch (error) {
        console.error('Error al listar pedidos:', error);
        res.status(500).json({ success: false, error: error.message });
    }
}

// 4. Asignar piloto
async function asignarPiloto(req, res) {
    try {
        const id = parseInt(req.params.id);
        const { piloto_id } = req.body;
        
        if (isNaN(id) || !piloto_id) {
            return res.status(400).json({ success: false, error: 'ID de pedido y piloto requeridos' });
        }
        
        const pedido = await pedidoComboModel.asignarPiloto(id, piloto_id);
        
        if (!pedido) {
            return res.status(404).json({ success: false, error: 'Pedido no encontrado' });
        }
        
        res.status(200).json({ success: true, data: pedido, message: 'Piloto asignado correctamente' });
        
    } catch (error) {
        console.error('Error al asignar piloto:', error);
        res.status(500).json({ success: false, error: error.message });
    }
}

// 5. Cambiar estado del pedido
async function cambiarEstado(req, res) {
    try {
        const id = parseInt(req.params.id);
        const { estado_id, motivo } = req.body;
        
        if (isNaN(id) || !estado_id) {
            return res.status(400).json({ success: false, error: 'ID de pedido y estado_id requeridos' });
        }
        
        const pedido = await pedidoComboModel.cambiarEstado(id, estado_id, motivo);
        
        if (!pedido) {
            return res.status(404).json({ success: false, error: 'Pedido no encontrado' });
        }
        
        let mensaje = 'Estado actualizado correctamente';
        if (estado_id === 3) mensaje = 'Pedido marcado como entregado';
        if (estado_id === 4) mensaje = 'Pedido finalizado con cliente satisfecho';
        
        res.status(200).json({ success: true, data: pedido, message: mensaje });
        
    } catch (error) {
        console.error('Error al cambiar estado:', error);
        res.status(500).json({ success: false, error: error.message });
    }
}

// 6. Obtener historial del pedido
async function obtenerHistorial(req, res) {
    try {
        const id = parseInt(req.params.id);
        
        if (isNaN(id)) {
            return res.status(400).json({ success: false, error: 'ID inválido' });
        }
        
        const historial = await pedidoComboModel.obtenerHistorial(id);
        res.status(200).json({ success: true, data: historial });
        
    } catch (error) {
        console.error('Error al obtener historial:', error);
        res.status(500).json({ success: false, error: error.message });
    }
}

// 7. Reporte de cuadre
async function reporteCuadre(req, res) {
    try {
        const { fecha, expendio_id } = req.query;
        
        if (!fecha) {
            return res.status(400).json({ success: false, error: 'Fecha requerida (YYYY-MM-DD)' });
        }
        
        const reporte = await pedidoComboModel.reporteCuadre(fecha, expendio_id ? parseInt(expendio_id) : null);
        res.status(200).json({ success: true, data: reporte });
        
    } catch (error) {
        console.error('Error al generar reporte:', error);
        res.status(500).json({ success: false, error: error.message });
    }
}

// 8. Reporte de ventas de combos
async function reporteVentasCombos(req, res) {
    try {
        const { fecha_desde, fecha_hasta, expendio_id } = req.query;
        
        if (!fecha_desde || !fecha_hasta) {
            return res.status(400).json({ success: false, error: 'fecha_desde y fecha_hasta requeridas' });
        }
        
        const reporte = await pedidoComboModel.reporteVentasCombos(
            fecha_desde, 
            fecha_hasta, 
            expendio_id ? parseInt(expendio_id) : null
        );
        
        res.status(200).json({ success: true, data: reporte });
        
    } catch (error) {
        console.error('Error al generar reporte de combos:', error);
        res.status(500).json({ success: false, error: error.message });
    }
}

// 9. Dashboard para el home
async function dashboard(req, res) {
    try {
        const hoy = new Date().toISOString().split('T')[0];
        
        // Pedidos de hoy
        const pedidosHoy = await pedidoComboModel.listarPedidos({
            fecha_desde: hoy,
            fecha_hasta: hoy,
            limite: 10
        });
        
        // Reporte de cuadre de hoy
        const cuadreHoy = await pedidoComboModel.reporteCuadre(hoy);
        
        // Top combos vendidos este mes
        const inicioMes = new Date().getFullYear() + '-' + String(new Date().getMonth() + 1).padStart(2, '0') + '-01';
        const topCombos = await pedidoComboModel.reporteVentasCombos(inicioMes, hoy);
        
        res.status(200).json({
            success: true,
            data: {
                pedidos_hoy: pedidosHoy,
                cuadre_hoy: cuadreHoy,
                top_combos: topCombos.slice(0, 5),
                total_pedidos_hoy: pedidosHoy.length
            }
        });
        
    } catch (error) {
        console.error('Error al obtener dashboard:', error);
        res.status(500).json({ success: false, error: error.message });
    }
}

module.exports = {
    crearPedido,
    obtenerPedido,
    listarPedidos,
    asignarPiloto,
    cambiarEstado,
    obtenerHistorial,
    reporteCuadre,
    reporteVentasCombos,
    dashboard
};