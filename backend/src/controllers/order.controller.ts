import { Response } from 'express';
import { AuthRequest } from '../middlewares/authMiddleware';
import { supabase } from '../config/supabase';
import { sendNotification } from '../services/notification.service';

/**
 * Get Order Details with Profiles
 * GET /orders/:id
 */
export const getOrderById = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { id } = req.params;
        const userId = req.user?.id;

        // Fetch Order
        const { data: order, error } = await supabase
            .from('orders')
            .select('*')
            .eq('id', id)
            .single();

        if (error || !order) {
            res.status(404).json({ success: false, message: 'Order not found' });
            return;
        }

        // Authorization: Only Pharmacy, Clinic, Driver or Admin
        const isAuthorized =
            userId === order.pharmacy_id ||
            userId === order.clinic_id ||
            userId === order.driver_id ||
            req.user?.role === 'ADMIN';

        if (!isAuthorized) {
            res.status(403).json({ success: false, message: 'Not authorized to view this order' });
            return;
        }

        // Fetch Profiles
        const { data: pharmacy } = await supabase.from('pharmacy_profiles').select('business_name, address, contact_phone').eq('user_id', order.pharmacy_id).single();
        const { data: clinic } = await supabase.from('clinic_profiles').select('business_name, address, contact_phone').eq('user_id', order.clinic_id).single();

        res.status(200).json({
            success: true,
            order: {
                ...order,
                pharmacy: pharmacy ? { ...pharmacy, phone: pharmacy.contact_phone } : null,
                clinic: clinic ? { ...clinic, phone: clinic.contact_phone } : null
            }
        });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};

/**
 * Confirm Pickup
 * POST /orders/:id/pickup
 */
export const confirmPickup = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { id } = req.params;
        const driverId = req.user?.id;

        const { data: order, error: orderError } = await supabase
            .from('orders')
            .select('id, driver_id, clinic_id, order_code')
            .eq('id', id)
            .single();

        if (orderError || !order || order.driver_id !== driverId) {
            res.status(403).json({ success: false, message: 'Not authorized or order not found' });
            return;
        }

        // Update Order and Delivery
        await supabase.from('orders').update({ status: 'IN_TRANSIT' }).eq('id', id);
        await supabase.from('deliveries').update({ pickup_time: new Date().toISOString() }).eq('order_id', id).eq('driver_id', driverId);

        // Notify Clinic
        sendNotification({
            userId: order.clinic_id,
            title: '🚚 Order in Transit',
            body: `Driver has picked up your order #${order.order_code} and is on the way.`,
            type: 'ORDER_IN_TRANSIT'
        });

        res.status(200).json({ success: true, message: 'Pickup confirmed' });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};

/**
 * Confirm Delivery
 * POST /orders/:id/deliver
 */
export const confirmDelivery = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { id } = req.params;
        const driverId = req.user?.id;

        const { data: order, error: orderError } = await supabase
            .from('orders')
            .select('id, driver_id, clinic_id, pharmacy_id, order_code')
            .eq('id', id)
            .single();

        if (orderError || !order || order.driver_id !== driverId) {
            res.status(403).json({ success: false, message: 'Not authorized or order not found' });
            return;
        }

        // Update Order and Delivery
        await supabase.from('orders').update({ status: 'DELIVERED' }).eq('id', id);
        await supabase.from('deliveries').update({ dropoff_time: new Date().toISOString() }).eq('order_id', id).eq('driver_id', driverId);

        // Notify Clinic & Pharmacy
        sendNotification({
            userId: order.clinic_id,
            title: '📦 Order Delivered',
            body: `Your order #${order.order_code} has been delivered. Please confirm receipt in the app.`,
            type: 'ORDER_DELIVERED'
        });

        sendNotification({
            userId: order.pharmacy_id,
            title: '📦 Delivery Complete',
            body: `Order #${order.order_code} has been delivered to the clinic.`,
            type: 'ORDER_DELIVERED'
        });

        res.status(200).json({ success: true, message: 'Delivery confirmed' });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};
