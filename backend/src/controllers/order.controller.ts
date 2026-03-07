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
            .select(`
                *,
                order_items (
                    id,
                    product_id,
                    quantity,
                    price_at_time,
                    products (
                        name,
                        description
                    )
                )
            `)
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
 * Get Available Deliveries (for Drivers)
 * GET /orders/available
 */
export const getAvailableDeliveries = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const userId = req.user?.id;

        // Fetch driver profile region
        const { data: profile } = await supabase
            .from('driver_profiles')
            .select('region, is_online')
            .eq('user_id', userId)
            .single();

        if (!profile || !profile.is_online) {
            res.status(200).json({ success: true, available_deliveries: [] });
            return;
        }

        // Fetch READY_FOR_PICKUP orders without a driver_id
        // Filter by region mostly done on client side or via a complex join. 
        // We'll perform a generic fetch and filter in Node for this MVP.
        const { data: pendingOrders, error } = await supabase
            .from('orders')
            .select(`
                id,
                order_code,
                delivery_address,
                subtotal,
                delivery_fee,
                pharmacy:users!orders_pharmacy_id_fkey(
                    pharmacy_profiles(business_name, address, region)
                ),
                clinic:users!orders_clinic_id_fkey(
                    clinic_profiles(business_name, address)
                )
            `)
            .eq('status', 'READY_FOR_PICKUP')
            .is('driver_id', null)
            .order('created_at', { ascending: true });

        if (error) throw error;

        // Filtering by region
        const region = profile.region?.toLowerCase();
        const available = (pendingOrders || []).filter(order => {
            const pharmData = Array.isArray(order.pharmacy) ? order.pharmacy[0] : order.pharmacy;
            const pharmProfiles = (pharmData as any)?.pharmacy_profiles;
            const pharmAddress = Array.isArray(pharmProfiles) ? pharmProfiles[0]?.address : pharmProfiles?.address;

            if (!region) return true; // if driver has no region, see all (or none, depending on policy)
            if (!pharmAddress) return false;
            return pharmAddress.toLowerCase().includes(region);
        });

        // Flatten the response
        const formattedAvailable = available.map(o => ({
            id: o.id,
            order_code: o.order_code,
            delivery_fee: o.delivery_fee,
            delivery_address: o.delivery_address,
            pharmacy: Array.isArray(o.pharmacy) ? o.pharmacy[0]?.pharmacy_profiles : (o.pharmacy as any)?.pharmacy_profiles,
            clinic: Array.isArray(o.clinic) ? o.clinic[0]?.clinic_profiles : (o.clinic as any)?.clinic_profiles,
        }));

        res.status(200).json({ success: true, available_deliveries: formattedAvailable });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};

/**
 * Driver accepts the delivery order
 * POST /orders/:id/accept
 */
export const acceptDelivery = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { id } = req.params;
        const driverId = req.user?.id;

        // Check if order is still available
        const { data: order, error: orderError } = await supabase
            .from('orders')
            .select('id, status, driver_id, order_code, pharmacy_id, clinic_id')
            .eq('id', id)
            .single();

        if (orderError || !order) {
            res.status(404).json({ success: false, message: 'Order not found' });
            return;
        }

        if (order.status !== 'READY_FOR_PICKUP' || order.driver_id) {
            res.status(400).json({ success: false, message: 'Job is no longer available.' });
            return;
        }

        // Assign driver
        const pickupQr = `QR-PICKUP-${order.order_code}`;
        const deliveryQr = `QR-DELIVER-${order.order_code}`;

        const { error: updateError } = await supabase
            .from('orders')
            .update({
                status: 'ASSIGNED',
                driver_id: driverId,
                pickup_qr: pickupQr,
                delivery_qr: deliveryQr,
                driver_assigned_at: new Date().toISOString()
            })
            .eq('id', id)
            .is('driver_id', null); // Concurrency check

        if (updateError) {
            res.status(409).json({ success: false, message: 'Job was taken by another driver.' });
            return;
        }

        // Insert into deliveries track table
        await supabase.from('deliveries').insert({
            order_id: id,
            driver_id: driverId
        });

        // Notify Pharmacy & Clinic
        const { data: driverInfo } = await supabase.from('users').select('name, phone').eq('id', driverId).single();
        const driverName = driverInfo?.name || 'AfyaLinks Driver';
        const driverPhone = driverInfo?.phone || '';

        sendNotification({
            userId: order.pharmacy_id,
            title: '🛵 Driver Assigned',
            body: `Driver ${driverName} (${driverPhone}) is on their way for pickup.`,
            type: 'DRIVER_ASSIGNED'
        });

        sendNotification({
            userId: order.clinic_id,
            title: '🛵 Driver Assigned',
            body: `Driver ${driverName} (${driverPhone}) will pick up your order shortly.`,
            type: 'DRIVER_ASSIGNED'
        });

        res.status(200).json({ success: true, message: 'Delivery job accepted successfully.' });
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
        const { order_code } = req.body;
        const driverId = req.user?.id;

        if (!order_code) {
            res.status(400).json({ success: false, message: 'Pickup code (order code) is required' });
            return;
        }

        const { data: order, error: orderError } = await supabase
            .from('orders')
            .select('id, driver_id, clinic_id, order_code')
            .eq('id', id)
            .single();

        if (orderError || !order || order.driver_id !== driverId) {
            res.status(403).json({ success: false, message: 'Not authorized or order not found' });
            return;
        }

        // Verify order_code provided by pharmacist to driver
        if (order.order_code !== order_code.trim().toUpperCase()) {
            res.status(400).json({ success: false, message: 'Invalid pickup code' });
            return;
        }

        // Generate a 6-digit delivery OTP for the clinic to give to the driver
        const deliveryOtp = Math.floor(100000 + Math.random() * 900000).toString();

        // Update Order and Delivery
        await supabase.from('orders').update({
            status: 'IN_TRANSIT',
            delivery_otp: deliveryOtp
        }).eq('id', id);

        await supabase.from('deliveries').update({ pickup_time: new Date().toISOString() }).eq('order_id', id).eq('driver_id', driverId);

        // Notify Clinic about pickup and provide OTP
        sendNotification({
            userId: order.clinic_id,
            title: '🚚 Order in Transit',
            body: `Driver has picked up your order and is on the way. Use Delivery Code: ${deliveryOtp} to confirm receipt.`,
            type: 'ORDER_IN_TRANSIT'
        });

        res.status(200).json({ success: true, message: 'Pickup confirmed', delivery_otp: deliveryOtp });
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
        const { otp } = req.body;
        const driverId = req.user?.id;

        if (!otp) {
            res.status(400).json({ success: false, message: 'Clinic delivery code is required' });
            return;
        }

        const { data: order, error: orderError } = await supabase
            .from('orders')
            .select('id, driver_id, clinic_id, pharmacy_id, order_code, delivery_otp, delivery_fee, delivery_commission')
            .eq('id', id)
            .single();

        if (orderError || !order || order.driver_id !== driverId) {
            res.status(403).json({ success: false, message: 'Not authorized or order not found' });
            return;
        }

        // Verify OTP provided by clinic to driver
        if (order.delivery_otp !== otp.trim()) {
            res.status(400).json({ success: false, message: 'Invalid delivery code' });
            return;
        }

        // Driver Earnings = Delivery Fee - Platform Commission on the delivery fee
        const driverEarnings = (order.delivery_fee || 0) - (order.delivery_commission || 0);

        // Update Order and Delivery
        await supabase.from('orders').update({ status: 'DELIVERED', delivered_at: new Date().toISOString() }).eq('id', id);
        await supabase.from('deliveries').update({
            dropoff_time: new Date().toISOString(),
            driver_fee_collected: driverEarnings
        }).eq('order_id', id).eq('driver_id', driverId);

        // Update Driver Wallet
        if (driverEarnings > 0) {
            const { data: profile } = await supabase
                .from('driver_profiles')
                .select('wallet_balance')
                .eq('user_id', driverId)
                .single();

            const currentBal = profile?.wallet_balance || 0;
            await supabase.from('driver_profiles')
                .update({ wallet_balance: currentBal + driverEarnings })
                .eq('user_id', driverId);
        }

        // Notify Clinic & Pharmacy
        sendNotification({
            userId: order.clinic_id,
            title: '📦 Order Delivered',
            body: `Your order #${order.order_code} has been delivered. Thank you for using Afya Links!`,
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
