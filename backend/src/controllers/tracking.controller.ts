import { Response } from 'express';
import { AuthRequest } from '../middlewares/authMiddleware';
import { supabase } from '../config/supabase';

/**
 * 1. Update Driver Location (Delivery App)
 * POST /tracking/update
 */
export const updateDriverLocation = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { latitude, longitude } = req.body;
        const driverId = req.user?.id;

        if (!driverId) {
            res.status(401).json({ success: false, message: 'Unauthorized' });
            return;
        }

        if (latitude === undefined || longitude === undefined) {
            res.status(400).json({ success: false, message: 'Latitude and Longitude are required' });
            return;
        }

        const { error } = await supabase
            .from('driver_locations')
            .upsert({
                driver_id: driverId,
                latitude,
                longitude,
                updated_at: new Date().toISOString()
            }, { onConflict: 'driver_id' });

        if (error) throw error;

        res.status(200).json({ success: true, message: 'Location updated' });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};

/**
 * 2. Get Order Tracking (Clinic App)
 * GET /tracking/order/:orderId
 */
export const getOrderTracking = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { orderId } = req.params;

        // Fetch order to find assigned driver
        const { data: order, error: orderError } = await supabase
            .from('orders')
            .select('driver_id, status')
            .eq('id', orderId)
            .single();

        if (orderError || !order) {
            res.status(404).json({ success: false, message: 'Order not found' });
            return;
        }

        if (!order.driver_id) {
            res.status(404).json({ success: false, message: 'No driver assigned to this order yet' });
            return;
        }

        // Fetch driver's latest location
        const { data: location, error: locError } = await supabase
            .from('driver_locations')
            .select('*')
            .eq('driver_id', order.driver_id)
            .single();

        if (locError) {
            res.status(404).json({ success: false, message: 'No location data available for this driver' });
            return;
        }

        res.status(200).json({
            success: true,
            tracking: {
                order_status: order.status,
                location
            }
        });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};
