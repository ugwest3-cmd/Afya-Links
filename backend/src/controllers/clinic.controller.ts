import { Response } from 'express';
import { AuthRequest } from '../middlewares/authMiddleware';
import { supabase } from '../config/supabase';

// ... (keep the existing getPriceOffers and createOrder)

export const getPriceOffers = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { drug_names, pharmacy_ids } = req.body;

        if (!Array.isArray(drug_names) || !Array.isArray(pharmacy_ids)) {
            res.status(400).json({ success: false, message: 'drug_names and pharmacy_ids must be arrays' });
            return;
        }

        const { data: activeLists, error: listError } = await supabase
            .from('price_lists')
            .select('id, pharmacy_id, valid_until')
            .in('pharmacy_id', pharmacy_ids)
            .gt('valid_until', new Date().toISOString());

        if (listError) throw listError;

        if (!activeLists || activeLists.length === 0) {
            res.status(404).json({ success: false, message: 'No active price lists found for selected pharmacies' });
            return;
        }

        const priceListIds = activeLists.map(list => list.id);

        const { data: priceItems, error: itemsError } = await supabase
            .from('price_items')
            .select('id, price_list_id, sku, drug_name, price, stock_qty, brand, strength, pack_size')
            .in('price_list_id', priceListIds)
            .in('drug_name', drug_names);

        if (itemsError) throw itemsError;

        const offersByPharmacy: Record<string, any[]> = {};

        activeLists.forEach(list => {
            offersByPharmacy[list.pharmacy_id] = priceItems
                .filter(item => item.price_list_id === list.id)
                .map(item => ({
                    ...item,
                    valid_until: list.valid_until
                }));
        });

        res.status(200).json({ success: true, data: offersByPharmacy });

    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

export const createOrder = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const clinicId = req.user?.id;
        const { pharmacy_id, items, delivery_address } = req.body;

        if (!pharmacy_id || !items || !Array.isArray(items) || items.length === 0) {
            res.status(400).json({ success: false, message: 'pharmacy_id and items array are required' });
            return;
        }

        const subtotal = items.reduce((sum, item) => sum + (item.price_agreed * item.quantity), 0);

        // Exact Ledger Logic based on Pesapal Escrow Spec
        const pharmacy_commission = subtotal * 0.08; // 8% Pharmacy Commission
        const pharmacy_net = subtotal - pharmacy_commission;

        const delivery_fee = 10000; // Estimated baseline fee
        const driver_commission = delivery_fee * 0.15; // 15% Driver Commission
        const driver_net = delivery_fee - driver_commission;

        const total_platform_revenue = pharmacy_commission + driver_commission;
        const total_payable = subtotal + delivery_fee;

        const { data: order, error: orderError } = await supabase
            .from('orders')
            .insert([{
                clinic_id: clinicId,
                pharmacy_id,
                status: 'AWAITING_PAYMENT',
                payment_status: 'AWAITING_PAYMENT',
                subtotal,
                delivery_fee,
                platform_commission: pharmacy_commission, // legacy mapping
                delivery_commission: driver_commission,   // legacy mapping
                pharmacy_commission,
                driver_commission,
                pharmacy_net,
                driver_net,
                total_platform_revenue,
                total_payable,
                delivery_address
            }])
            .select()
            .single();

        if (orderError || !order) throw orderError || new Error('Failed to create order');

        const orderItemsToInsert = items.map(item => ({
            order_id: order.id,
            drug_name: item.drug_name,
            quantity: item.quantity,
            price_agreed: item.price_agreed
        }));

        const { error: itemsError } = await supabase
            .from('order_items')
            .insert(orderItemsToInsert);

        if (itemsError) throw itemsError;

        // Notify pharmacy of new incoming order (non-blocking)
        Promise.resolve(supabase.from('notifications').insert([{
            user_id: pharmacy_id,
            title: '🛒 New Order Received',
            body: `A new order (#${order.id.slice(0, 8).toUpperCase()}) has been placed and is awaiting payment. It will appear in your inbox once payment clears.`,
            type: 'NEW_ORDER',
            is_read: false
        }])).catch(console.error);

        res.status(201).json({ success: true, message: 'Order created successfully', order_id: order.id });

    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};


// In-memory OTP store for Delivery Confirmation MVP
const deliveryOtpStore = new Map<string, { otp: string, expiresAt: number }>();

export const requestDeliveryOtp = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const clinicId = req.user?.id;
        const orderId = req.params.id as string;

        const { data: order, error } = await supabase
            .from('orders')
            .select('id, status, clinic:users!orders_clinic_id_fkey(phone)')
            .eq('id', orderId)
            .eq('clinic_id', clinicId)
            .single();

        if (error || !order) {
            res.status(404).json({ success: false, message: 'Order not found' });
            return;
        }

        // Generate OTP
        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        const expiresAt = Date.now() + 10 * 60 * 1000; // 10 mins expiry

        deliveryOtpStore.set(orderId, { otp, expiresAt });

        const clinicPhone = Array.isArray(order.clinic) ? order.clinic[0]?.phone : (order.clinic as any)?.phone;

        console.log(`[MVP DEV] 🚀 Delivery OTP for Order ${orderId} is: ${otp}`);

        if (clinicPhone) {
            const { sendSMS } = await import('../utils/sms');
            await sendSMS([clinicPhone], `Your AfyaLinks Delivery Code for Order ${orderId.substring(0, 6)} is: ${otp}. Valid for 10 minutes.`);
        }

        res.status(200).json({ success: true, message: 'Delivery OTP sent successfully' });
    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

export const confirmDelivery = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const clinicId = req.user?.id;
        const orderId = req.params.id as string;
        const { otp } = req.body;

        if (!otp) {
            res.status(400).json({ success: false, message: 'OTP is required for delivery confirmation' });
            return;
        }

        // Verify OTP
        const record = deliveryOtpStore.get(orderId);
        if (!record || Date.now() > record.expiresAt) {
            res.status(400).json({ success: false, message: 'OTP expired or not requested' });
            return;
        }
        if (record.otp !== otp) {
            res.status(400).json({ success: false, message: 'Invalid OTP' });
            return;
        }

        // Fetch order to verify
        const { data: order, error: orderError } = await supabase
            .from('orders')
            .select('id, status')
            .eq('id', orderId)
            .eq('clinic_id', clinicId)
            .single();

        if (orderError || !order) {
            res.status(404).json({ success: false, message: 'Order not found' });
            return;
        }

        if (order.status === 'COMPLETED' || order.status === 'DELIVERED') {
            res.status(400).json({ success: false, message: 'Order is already completed' });
            return;
        }

        // Atomic Status Update
        const { error: updateError } = await supabase
            .from('orders')
            .update({
                status: 'COMPLETED',
                payout_status: 'INITIATED'
            })
            .eq('id', orderId);

        if (updateError) throw updateError;

        // Clear OTP
        deliveryOtpStore.delete(orderId);

        // Update deliveries dropoff_time
        try {
            await supabase
                .from('deliveries')
                .update({ dropoff_time: new Date() })
                .eq('order_id', orderId);
        } catch (e) {
            console.error('Failed to update dropoff time:', e);
        }

        res.status(200).json({
            success: true,
            message: 'Delivery confirmed and escrow funds released successfully'
        });

    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

export const getDashboardStatsClinic = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const clinicId = req.user?.id;

        const { data: orders, error } = await supabase
            .from('orders')
            .select('status')
            .eq('clinic_id', clinicId);

        if (error) throw error;

        const stats = {
            pending: orders.filter(o => o.status === 'PENDING').length,
            in_transit: orders.filter(o => ['ACCEPTED', 'PARTIAL', 'READY_FOR_PICKUP', 'ASSIGNED', 'IN_TRANSIT'].includes(o.status)).length,
            delivered: orders.filter(o => o.status === 'DELIVERED').length,
            rejected: orders.filter(o => o.status === 'REJECTED').length,
        };

        res.status(200).json({ success: true, stats });
    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

export const getMyOrders = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const clinicId = req.user?.id;
        const { limit = 20 } = req.query;

        const { data: orders, error } = await supabase
            .from('orders')
            .select(`
                *,
                pharmacy:users!orders_pharmacy_id_fkey(name),
                items:order_items(*)
            `)
            .eq('clinic_id', clinicId)
            .order('created_at', { ascending: false })
            .limit(Number(limit));

        if (error) throw error;

        res.status(200).json({ success: true, orders });
    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

